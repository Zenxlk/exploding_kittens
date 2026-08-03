# Arquitectura técnica

## Principios

- **Game Engine desacoplado**: `lib/game_engine/` es Dart puro. Cero imports de Flutter.
  Se puede testear, serializar y reutilizar en un servidor sin cambios.
- **Estado inmutable**: cada acción produce un nuevo `GameState` via `copyWith`.
  Riverpod detecta cambios automáticamente y la serialización para red es trivial.
- **Feature-first**: cada feature es un módulo autónomo con sus capas de datos,
  dominio y presentación. Las features no se importan entre sí.
- **Eventos desacoplados**: el engine emite `GameEvent` en un stream broadcast.
  La UI lo escucha para animaciones y sonidos sin que el engine sepa nada de Flutter.

---

## Capas y dependencias

```
┌─────────────────────────────────────────────────────┐
│  features/*/presentation  (Flutter widgets)         │
│         ↓                                           │
│  features/*/providers     (Riverpod)                │
│         ↓                                           │
│  features/*/domain/usecases                         │
│         ↓                      ↘                    │
│  game_engine/engine/GameEngine   network/            │
│         ↓                                           │
│  game_engine/rules + deck + turn                    │
│         ↓                                           │
│  game_engine/models  (entidades inmutables)         │
└─────────────────────────────────────────────────────┘
         ↑ todos dependen de ↑
         core/  (constantes, errores, utils)
```

---

## Game Engine

### Flujo de una acción

```
UI → engine.apply(TurnAction)
       │
       ├─ GameRules.validate()      → lanza InvalidActionException si inválida
       │
       └─ ActionProcessor.process()
              │
              ├─ muta GameState (inmutablemente via copyWith)
              ├─ emite GameEvent al bus
              └─ devuelve nuevo GameState
```

### `TurnAction` — sealed class

Exhaustiva: el compilador obliga a manejar todos los casos en `ActionProcessor`.

| Acción | Descripción |
|--------|-------------|
| `DrawCardAction` | Robar la carta de arriba del mazo |
| `PlayCardAction` | Jugar una carta sin objetivo |
| `PlayFavorAction` | Pedirle una carta a otro jugador (él elige cuál con `ChooseCardAction`, ver abajo) |
| `PlayCatPairAction` | Par de gatos → robar carta aleatoria |
| `PlayCatTrioAction` | Trío de gatos → robar una carta concreta de la mano del objetivo (el actor la elige después, a ciegas, con `ChooseCardAction`) |
| `DefuseBombAction` | Usar Defuse + elegir posición de reinserción |
| `NopeAction` | Cancelar (o des-cancelar) la acción pendiente |
| `ChooseCardAction` | Elige una carta concreta para resolver una acción pendiente (`GameState.pendingAction` decide de qué mano sale y quién la recibe). La dispara el objetivo de un Favor (boca arriba, su propia mano) o el actor de un trío de gatos (boca abajo, la mano del objetivo) — diseñada genérica para poder cubrir ambos casos con el mismo mecanismo |

### `GameEvent` — sealed class

El bus emite eventos que la UI consume para animaciones y sonidos sin polling.

```dart
engine.on<BombTriggeredEvent>().listen((_) => showExplosionAnimation());
engine.on<NopedEvent>().listen((e) => playNopeSound());
```

### Turno y fases

```
TurnPhase.playing
    │  (jugador juega carta)
    ▼
TurnPhase.nopeWindow     ← ventana de GameConstants.nopeWindowMs ms
    │  (se cierra o se juega Nope)
    ▼
TurnPhase.resolving      ← se aplica el efecto
    │
    ▼
TurnPhase.playing        ← TurnManager.advance() rota al siguiente jugador
```

`TurnPhase` también declara `drawRequired` y `ended`, pero ningún camino del
motor los asigna hoy — quedaron del diseño inicial sin uso real.

Un Favor o un trío de gatos sin nopear son la excepción a este diagrama: en
vez de resolverse solos al cerrar la ventana de Nope, pasan a
`TurnPhase.awaitingCardChoice` y se quedan ahí (sin volver a `playing`, sin
limpiar `pendingAction`) hasta que alguien manda un `ChooseCardAction` con
la carta elegida — recién ahí vuelve a `playing`. Para el trío elige el
actor (boca abajo, la mano del objetivo) — sigue siendo `turn.currentPlayerId`,
como toda la partida hasta ahora. Favor es la excepción real: elige el
objetivo (boca arriba, su propia mano), que es el único caso hoy donde
quien debe actuar a continuación no es `turn.currentPlayerId`.

Attack chain: `TurnModel.actionsLeft > 1` mantiene al mismo jugador.
Nope chain: `TurnModel.nopeChainCount` impar = acción cancelada.

---

## Lobby local WiFi (Fase 3)

### Componentes

```
LobbyScreen  →  lobbyProvider (LobbyNotifier)  →  LobbyRepository
                                                        │
                                ┌───────────────┬───────┼───────┬───────────────┐
                                ▼               ▼               ▼               ▼
                            WsServer        WsClient      HostBeaconSync  ClientRoomDiscovery
                          (host only)   (todos, incl.       (host only,      (cliente only,
                                         host vía 127.0.0.1)  MdnsAdvertiser)  MdnsDiscoverer)
```

`LobbyRepository` implementa `ILobbyRepository` y es la única clase que conoce
los cuatro colaboradores. El host levanta `WsServer` y además se conecta a su
propio servidor como cliente (`127.0.0.1`), de modo que host y no-host comparten
exactamente el mismo camino de código (`WsClient` + `roomStream`). El manejo
mDNS de host (`HostBeaconSync`) y de cliente (`ClientRoomDiscovery`) está
separado en clases propias — antes vivían como campos sueltos dentro de
`LobbyRepository`.

### Descubrimiento de salas

`MdnsAdvertiser` (host) y `MdnsDiscoverer` (cliente) usan mDNS/DNS-SD real
vía el paquete `nsd` (Bonjour en Apple, NsdManager en Android), registrando
y descubriendo `AppConstants.mdnsServiceType` (`_explkittens._tcp`). La
sala se anuncia con un `Service` cuyo `txt` lleva `hostName`/`playerCount`/
`maxPlayers`; la dirección del host (`Service.addresses`) la resuelve el
propio protocolo mDNS, no un campo autoreportado. `nsd` no permite
actualizar el `txt` de un registro activo: `MdnsAdvertiser.updatePlayerCount`
des-registra y vuelve a registrar con los valores nuevos.

> Migrado en Fase 6 desde un broadcast UDP propio (no mDNS/Bonjour real).
> `nsd` es enteramente nativo, sin implementación en Dart puro para
> ejercitar el registro/descubrimiento desde el entorno de desarrollo; los
> tests mockean `NsdPlatformInterface` para la lógica propia, y el
> registro/descubrimiento real se verificó a mano en dispositivos antes de
> mergear (ver `docs/VERIFICATION_LOG.md`).

### Protocolo WebSocket del lobby

`WsMessage` es una sealed class con todos los mensajes del lobby:

| Dirección | Mensajes |
|-----------|----------|
| Cliente → Servidor | `JoinRoomMessage`, `SetReadyMessage`, `LeaveRoomMessage`, `StartGameMessage`, `ActionMessage` |
| Servidor → Cliente | `RoomStateMessage`, `GameStartingMessage`, `PlayerKickedMessage`, `WsErrorMessage`, `GameStateMessage`, `GameEventMessage`, `ActionRejectedMessage`, `PlayerReconnectedMessage` |
| Ambos | `PingMessage` / `PongMessage` (heartbeat) |

`WsServer` mantiene el `LobbyRoom` autoritativo y retransmite `RoomStateMessage`
tras cada cambio (join, ready, leave). `WsClient` (sobre `web_socket_channel`)
expone ese estado como `roomStream` para que `LobbyRepository` lo reenvíe a la UI.

### Estado en Riverpod

`LobbyNotifier` (`lobbyProvider`) modela el flujo del lobby como una sealed
class `LobbyState`: `LobbyIdle → LobbyConnecting → LobbyInRoom`, con
`LobbyDiscovering` en el camino del cliente y `LobbyError` ante fallos de red.
`LobbyInRoom.canStart`/`isHost`/`isLocalPlayerReady` derivan directamente de
`LobbyRoom`, sin estado duplicado.

---

## Red y reconexión (Fase 5 — completa)

### Diseño cliente–servidor simétrico

`WsServer` y `WsClient` (implementados en Fase 3 para el lobby, ver arriba) son
el mismo transporte que usa el juego en partida: el **host** levanta
`WsServer` en `AppConstants.localGamePort` (8765) y también se conecta como
cliente a sí mismo. Todos los jugadores (incluido el host) usan exactamente el
mismo `WsClient`.

```
Host:    WsServer  ←→  GameEngine (GameNotifier)  ←→  WsClient (host)
Clients:                RemoteGameNotifier  ←→  WsClient (cliente 1..N)
```

Solo el host corre un `GameEngine` real. `gameNetworkBridgeProvider` conecta
ambos lados en el host: reenvía `WsServer.actionMessages` hacia
`GameNotifier.applyAction()` (respondiendo `ActionRejectedMessage` si la
acción es inválida), y retransmite `GameNotifier.rawStates`/`events` como
`GameStateMessage`/`GameEventMessage` por `WsServer.broadcast()`. Cada
no-host corre un `RemoteGameNotifier` que expone exactamente el mismo
`GameSessionState` que `GameNotifier`, pero manda sus acciones por
`ActionMessage` en vez de aplicarlas contra un motor local — así ninguna de
las pantallas de partida necesita saber si están hablando con el host o con
un no-host. Cuando se migre a modo online, solo cambia la URL de conexión
del cliente.

### Serialización

`GameState` (y cada modelo que compone: `CardModel`, `PlayerModel`,
`DeckModel`, `TurnModel`, `GameConfig`, `GameResult`, `TurnAction`,
`GameEvent`) tiene `toJson()`/`fromJson()` propios, mismo estilo manual que
ya usaban los modelos del lobby (sin `freezed`/`json_serializable`, pese a
estar en pubspec). No hay una clase `*Serializer` separada. El `GameState`
completo viaja dentro de `GameStateMessage.stateJson` tras cada acción; los
`GameEvent` individuales viajan en `GameEventMessage` para disparar
animaciones/sonidos en los no-host, que no tienen motor local propio.

### Reconexión

`ReconnectionManager` (en `network/reconnection/`, sin dependencias de
Flutter ni del motor) lleva un `Timer` por jugador desconectado con el
grace period de `GameConstants.reconnectTimeoutSeconds` (60s por defecto).
El puente del host lo conecta a `WsServer.onPlayerDisconnected`/
`onPlayerReconnected`: al desconectarse, marca al jugador
`PlayerStatus.disconnected` de inmediato (visible en `PlayersHudWidget`); si
expira sin volver, llama `GameNotifier.eliminateForDisconnect()`, que
reutiliza el mismo camino de eliminación que una Exploding Kitten sin
Defuse. `WsClient` reconecta solo con back-off exponencial (1s→16s) tras una
caída no solicitada.

---

## Autenticación con Supabase (Fase 7 — lado cliente implementado)

### Objetivo y alcance

El backend hermano `cards_game_service` (mismo autor, repo separado)
implementa identidad de jugador persistente entre partidas vía Supabase
Auth: un `authToken` (JWT) opcional en el mensaje `join_room`, validado
offline contra el JWKS del proyecto. Sin ese token, el servidor trata la
conexión como invitada, igual que en modo 100% local. Esta fase cubrió la
mitad que faltaba del lado del cliente: obtener ese JWT (sign-in anónimo
de Supabase) y mandarlo, más el camino completo para jugar de verdad
contra ese backend por Internet.

Implementado:

- `authToken` de principio a fin: `SupabaseAuthService` obtiene la sesión,
  `JoinRoomMessage.authToken` la transporta, `WsClient` la reenvía en cada
  join y en cada reconexión automática.
- Conexión real a `cards_game_service` por Internet: `OnlineLobbyRepository`
  (nueva implementación de `ILobbyRepository`, sin `WsServer` local ni
  mDNS), `OnlineRoomsClient` (`POST /rooms`), `WsClient.connectToUri`
  (conecta a una URL completa con código de sala en el path, no a un
  host:puerto LAN) y un selector explícito LAN/Online en `LobbyScreen`.
- Soporte `wss://` (TLS): `OnlineConfig.wsUri()` deriva el esquema
  `wss`/`ws` del `https`/`http` de `ONLINE_SERVER_URL`; `WsClient` ya no
  asume `ws://` a secas.
- Vincular la cuenta anónima a un login real con correo/contraseña
  (issue #27): `SupabaseAuthService.signUpAndLinkAnonymous` llama
  `supabase.auth.updateUser()` **mientras la sesión anónima sigue
  activa** — actualiza esa misma identidad (mismo `playerId`, mismo
  historial en `cards_game_service`) en vez de crear una cuenta aparte.
  `signInWithPassword` es el camino inverso: reemplaza la sesión anónima
  por la de una cuenta ya existente, para recuperar su historial. Tres
  pantallas nuevas en `features/auth/presentation/screens/`
  (`AccountScreen`, `SignUpScreen`, `LoginScreen`), accesibles desde
  Ajustes solo si `SupabaseConfig.isConfigured` — la app sigue arrancando
  100% invitada por default, este login es opt-in. Login con Google sigue
  fuera de alcance (issue aparte).

Todo lo de arriba tiene tests automatizados contra dobles (un `WsServer`
propio como backend de prueba, `MockClient`/mocktail para HTTP,
`MockSupabaseClient`/`MockGoTrueClient` para las llamadas a GoTrue) y
además se verificó a mano contra el proceso Go real antes de mergear —
pasos de reproducción en `docs/VERIFICATION_LOG.md`, sección "Fase 7 —
Modo online del lado cliente".

**Explícitamente fuera de alcance** (no confundir con lo de arriba):

- Login con Google/OAuth — issue aparte.
- Sistema de cuentas/nicknames persistentes y ranking global — el backend
  ya expone `GET /players/{id}`, `PATCH /players/{id}/nickname` y
  `GET /leaderboard`, pero el cliente todavía no los consume.

### Diseño: `SupabaseAuthService`

Nueva feature `lib/features/auth/`, mismo patrón de carpetas que el resto
del proyecto (`data`/`domain`/`presentation`), sin `GetIt` ni service
locator — todo vía Riverpod, igual que `SettingsNotifier`
(`features/settings/presentation/providers/settings_providers.dart`).

```dart
// lib/features/auth/domain/auth_session.dart
class AuthSession {
  const AuthSession({
    required this.playerId,   // "sub" del JWT — mismo valor que espera
                               // cards_game_service como playerId
    required this.accessToken,
    required this.isAnonymous,
  });
  final String playerId;
  final String accessToken;
  final bool isAnonymous;
}
```

```dart
// lib/features/auth/data/supabase_auth_service.dart
// Envoltorio fino sobre supabase_flutter — nada propio de más, solo
// traduce su modelo de sesión a AuthSession.
class SupabaseAuthService {
  SupabaseAuthService(this._client);
  final SupabaseClient _client;

  AuthSession? get currentSession { ... } // lee _client.auth.currentSession

  Future<AuthSession> signInAnonymously() async {
    final res = await _client.auth.signInAnonymously();
    return _toSession(res.session!);
  }
}
```

```dart
// lib/features/auth/presentation/providers/auth_providers.dart

// null si no hay Supabase configurado (sin .env) — igual que el backend,
// la ausencia de configuración apaga la feature entera sin ramas
// especiales en el resto del código.
final authServiceProvider = Provider<SupabaseAuthService?>((ref) {
  if (!SupabaseConfig.isConfigured) return null;
  return SupabaseAuthService(Supabase.instance.client);
});

final authSessionProvider =
    AsyncNotifierProvider<AuthSessionNotifier, AuthSession?>(
        AuthSessionNotifier.new);

class AuthSessionNotifier extends AsyncNotifier<AuthSession?> {
  @override
  Future<AuthSession?> build() async {
    final service = ref.watch(authServiceProvider);
    if (service == null) return null; // modo invitado, sin cambios
    return service.currentSession ?? service.signInAnonymously();
  }
}
```

### Cambios en código existente

1. **`JoinRoomMessage`** (`network/websocket/websocket_message.dart`):
   sumar `authToken` opcional al constructor, `toJson()` (solo si no es
   null, mismo patrón que `token` hoy) y `_fromJson()`.
2. **`WsClient`** (`network/websocket/websocket_client.dart`): nuevo
   campo privado `_authToken`, seteado en `_connect()` igual que
   `_playerId`/`_playerName` — así `_attemptReconnect()` lo reenvía solo
   por reutilizar esos mismos campos, sin tocar la lógica de reconexión.
   Nuevo parámetro opcional `authToken` en el factory `connect()`.
3. **`playerIdProvider`** (`features/lobby/presentation/providers/lobby_providers.dart`):
   preferir `authSessionProvider` por sobre el UUID generado:
   ```dart
   final playerIdProvider = FutureProvider<String>((ref) async {
     final session = await ref.watch(authSessionProvider.future);
     if (session != null) return session.playerId;
     // comportamiento actual sin cambios: UUID persistido en SharedPreferences
     ...
   });
   ```
   **Importante:** si el jugador ya tenía un UUID de invitado guardado y
   después se autentica, el `playerId` efectivo cambia — coherente con el
   backend (ahí el `sub` manda), pero implica que el historial ligado al
   UUID de invitado viejo (si algo local lo usa) queda huérfano. No hay
   migración automática planeada para ese caso.
4. **`LobbyRepository`/`LobbyNotifier.createRoom()`/`joinRoom()`**: leer
   `ref.read(authSessionProvider.future)` y pasar
   `session?.accessToken` como `authToken` hasta `WsClient.connect()`.

### Configuración

- `pubspec.yaml`: agregar `supabase_flutter` y `flutter_dotenv` (más
  simple que `--dart-define-from-file` porque no cambia los comandos de
  build/run existentes — a cambio, el `.env` tiene que declararse como
  asset en `pubspec.yaml` y existir en cada máquina que compile).
- `.gitignore` ya contempla `.env`/`.env.*` con excepción de
  `.env.example` — falta crear ese `.env.example`:
  ```
  SUPABASE_URL=
  SUPABASE_ANON_KEY=
  ```
  Mismas credenciales que usa el backend para `SUPABASE_JWKS_URL` (mismo
  proyecto Supabase, ver `cards_game_service/docs/DEPLOYMENT.md`) —
  `SUPABASE_ANON_KEY` es pública por diseño, pensada para clientes.
- `SupabaseConfig.isConfigured` (ambas variables no vacías) decide si
  `main.dart` llama `Supabase.initialize(...)` antes de `runApp` — vacío
  o ausente el `.env` significa modo 100% invitado, igual que hoy.
- Requiere **Anonymous Sign-Ins habilitado** en el proyecto Supabase
  (mismo paso ya documentado en `cards_game_service/docs/DEPLOYMENT.md`,
  sección 3) — sin eso, `signInAnonymously()` falla y el jugador queda en
  modo invitado (fallback, no debería crashear la app).

### Testing

- `test/network/websocket/ws_message_test.dart`: roundtrip de
  `JoinRoomMessage` con/sin `authToken`, mismo patrón que ya existe para
  `token` (incluyendo `containsKey('authToken')` en `false` cuando es
  null).
- `test/features/auth/`: unit tests de `SupabaseAuthService` mockeando
  `SupabaseClient`/`GoTrueClient` con `mocktail` — sin pegarle a un
  proyecto Supabase real, mismo principio que `internal/auth/auth_test.go`
  en el backend (JWKS en memoria, no HTTP real).
- `test/features/lobby/presentation/providers/lobby_providers_test.dart`:
  override de `authSessionProvider` para probar que `playerIdProvider`
  prefiere el `playerId` de la sesión, y que cae al UUID de invitado
  cuando `authServiceProvider` es `null`.
- `test/core/config/online_config_test.dart`: mapeo de esquema
  `https`/`http` → `wss`/`ws` en `OnlineConfig.wsUri()`.
- `test/network/http/online_rooms_client_test.dart`: `OnlineRoomsClient`
  contra `http.testing.MockClient` (respuesta exitosa, error HTTP, sin
  red).
- `test/features/lobby/data/online_lobby_repository_test.dart`:
  `OnlineLobbyRepository` contra un `WsServer` propio como doble del
  backend (habla el mismo protocolo `WsMessage`, ver
  `internal/transport/protocol.go` en `cards_game_service`) +
  `OnlineRoomsClient` mockeado.
- `test/features/lobby/presentation/screens/lobby_screen_test.dart`:
  selector LAN/Online, diálogo de código de sala, botón Online
  deshabilitado sin `OnlineConfig` configurada.

### Implementado en

1. `pubspec.yaml` + config (`.env.example`, `SupabaseConfig`,
   `OnlineConfig`, init en `main.dart`).
2. `lib/features/auth/` — `SupabaseAuthService` + providers.
3. `lib/network/websocket/websocket_message.dart` —
   `JoinRoomMessage.authToken`.
4. `lib/network/websocket/websocket_client.dart` — `authToken` en
   connect/reconexión, y `WsClient.connectToUri` para el modo online.
5. `lib/features/lobby/presentation/providers/lobby_providers.dart` —
   `playerIdProvider` prefiere la sesión autenticada; `LobbyMode` (lan/
   online) explícito en `createRoom()`/`joinRoom()`.
6. `lib/network/http/online_rooms_client.dart` y
   `lib/features/lobby/data/online_lobby_repository.dart` — modo online
   contra `cards_game_service`.
7. `lib/features/lobby/presentation/screens/lobby_screen.dart` — selector
   LAN/Online, código de sala.

---

## Gestión de estado (Riverpod)

Los providers manuales (`Notifier`/`NotifierProvider`, sin `@riverpod`) son
el patrón usado en todo el proyecto — `lobbyProvider`/`LobbyNotifier` lo
estableció en Fase 3 y `gameProvider`/`GameNotifier` lo sigue en Fase 4:

```dart
// Provider principal de partida (Fase 4), lib/features/game/presentation/providers/game_providers.dart
final gameProvider =
    NotifierProvider<GameNotifier, GameSessionState>(GameNotifier.new);

class GameNotifier extends Notifier<GameSessionState> {
  GameNotifier({IGameGateway? gateway})
      : _gateway = gateway ?? LocalGameGateway();

  final IGameGateway _gateway;

  @override
  GameSessionState build() => const GameIdle();

  void startLocalGame(List<PlayerModel> players, GameConfig config) {
    _setFromGameState(_gateway.startGame(players, config));
  }

  String? _apply(TurnAction action) {
    try {
      _setFromGameState(_gateway.apply(action));
      return null;
    } on InvalidActionException catch (e) {
      return e.message; // ver GameRunning.error
    }
  }
}
```

`riverpod_generator` sigue en pubspec por si algún provider futuro lo
necesita, pero hoy ningún provider del proyecto usa codegen.

Los providers de animación y audio escuchan `GameEventBus.instance.stream`
de forma independiente para no bloquear el árbol de widgets.

---

## Expansión futura

### Añadir una carta nueva

1. Añadir valor al enum `CardType` en `card_type.dart`
2. Añadir caso en `CardRules` y en `GameRules`
3. Añadir caso en el `switch` de `ActionProcessor.process()` — el compilador
   obliga a manejarlo al ser `sealed`
4. Añadir asset en `assets/cards/` y registrar en `AssetPaths`
5. Añadir test en `test/game_engine/rules/`

### Añadir una expansión

Crear un `DeckBuilder` especializado que reciba `GameConfig.includeExpansion = true`
y ajuste la composición del mazo. El engine no requiere cambios.

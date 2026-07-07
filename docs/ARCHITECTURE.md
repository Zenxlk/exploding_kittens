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
| `PlayFavorAction` | Pedir carta aleatoria a otro jugador |
| `PlayCatPairAction` | Par de gatos → robar carta aleatoria |
| `PlayCatTrioAction` | Trío de gatos → elegir carta de la mano del objetivo |
| `DefuseBombAction` | Usar Defuse + elegir posición de reinserción |
| `NopeAction` | Cancelar (o des-cancelar) la acción pendiente |

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
TurnPhase.drawRequired   ← jugador debe robar
    │
    ▼
TurnPhase.ended          ← TurnManager.advance() rota al siguiente
```

Attack chain: `TurnModel.actionsLeft > 1` mantiene al mismo jugador.
Nope chain: `TurnModel.nopeChainCount` impar = acción cancelada.

---

## Lobby local WiFi (Fase 3)

### Componentes

```
LobbyScreen  →  lobbyProvider (LobbyNotifier)  →  LobbyRepository
                                                        │
                                        ┌───────────────┼───────────────┐
                                        ▼               ▼               ▼
                                    WsServer        WsClient      MdnsAdvertiser /
                                  (host only)   (todos, incl.      MdnsDiscoverer
                                                 host vía 127.0.0.1)  (host / cliente)
```

`LobbyRepository` implementa `ILobbyRepository` y es la única clase que conoce
los cuatro colaboradores. El host levanta `WsServer` y además se conecta a su
propio servidor como cliente (`127.0.0.1`), de modo que host y no-host comparten
exactamente el mismo camino de código (`WsClient` + `roomStream`).

### Descubrimiento de salas

`MdnsAdvertiser` (host) envía un beacon JSON por UDP broadcast a
`255.255.255.255:AppConstants.discoveryPort` cada pocos segundos.
`MdnsDiscoverer` (cliente) escucha ese puerto y expone
`Stream<List<DiscoveredRoom>>` con las salas vivas.

> No es mDNS/Bonjour real — es un broadcast UDP propio con el mismo propósito.
> Migrar a la librería `nsd` o `multicast_dns` es una mejora pendiente (ver `ROADMAP.md`).

### Protocolo WebSocket del lobby

`WsMessage` es una sealed class con todos los mensajes del lobby:

| Dirección | Mensajes |
|-----------|----------|
| Cliente → Servidor | `JoinRoomMessage`, `SetReadyMessage`, `LeaveRoomMessage`, `StartGameMessage` |
| Servidor → Cliente | `RoomStateMessage`, `GameStartingMessage`, `PlayerKickedMessage`, `WsErrorMessage` |
| Ambos | `PingMessage` / `PongMessage` (heartbeat) |
| Stubs Fase 5 | `GameStateMessage`, `ActionMessage`, `PlayerReconnectedMessage` |

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

## Red (Fase 5 — pendiente sobre transporte ya existente)

### Diseño cliente–servidor simétrico

`WsServer` y `WsClient` (implementados en Fase 3 para el lobby, ver arriba) son
el mismo transporte que usará el juego en partida: el **host** levanta
`WsServer` en `AppConstants.localGamePort` (8765) y también se conecta como
cliente a sí mismo. Todos los jugadores (incluido el host) usan exactamente el
mismo `WsClient`.

```
Host:    WsServer  ←→  GameEngine  ←→  WsClient (host)
Clients:                WsClient (cliente 1..N)
```

Cuando se migre a modo online, solo cambia la URL de conexión del cliente.
`WsMessage` ya reserva los tipos `GameStateMessage` / `ActionMessage` /
`PlayerReconnectedMessage` para esta fase; falta la lógica que los procese.

### Serialización (pendiente)

`GameStateSerializer` convertirá `GameState` ↔ JSON para viajar dentro de
`GameStateMessage.stateJson`. El estado completo se retransmitirá a todos los
clientes tras cada acción para garantizar consistencia. Los eventos
individuales (`GameEvent` ↔ JSON) se usarán para triggers de animación en los
clientes.

### Reconexión (pendiente)

`ReconnectionManager` gestionará el grace period de
`GameConstants.reconnectTimeoutSeconds` segundos. Al reconectar, el servidor
enviará el `GameState` completo (vía `PlayerReconnectedMessage` +
`GameStateMessage`) y el cliente restaurará la UI desde él.

---

## Gestión de estado (Riverpod)

```dart
// Provider principal de partida (Fase 4)
@riverpod
class GameStateNotifier extends _$GameStateNotifier {
  late GameEngine _engine;

  @override
  GameState build() { ... }

  void apply(TurnAction action) {
    state = _engine.apply(action);
  }
}
```

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

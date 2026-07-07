# Changelog

Formato basado en [Keep a Changelog](https://keepachangelog.com/es/1.0.0/).

---

## [Unreleased]

### En progreso
- Fase 4: Pantalla de juego completa

---

## [0.3.0] — 2026-07-06

### Añadido — Fase 3: Lobby local WiFi
- **`LobbyRoom` / `LobbyPlayer` / `LobbyStatus`** — modelos inmutables del dominio del lobby con `toJson`/`fromJson`, `copyWith`, `isFull`, `canStart` (mínimo 2 jugadores, todos los no-host listos) y getter `host`
- **`DiscoveredRoom`** — modelo de sala anunciada en la red local, con `toJson`/`fromJson` e `isFull`
- **`WsMessage`** — sealed class con el protocolo completo del lobby: `JoinRoom`, `SetReady`, `LeaveRoom`, `StartGame` (cliente→servidor), `RoomState`, `GameStarting`, `PlayerKicked`, `WsError` (servidor→cliente), `Ping`/`Pong` (heartbeat) y stubs de Fase 5 (`GameState`, `Action`, `PlayerReconnected`)
- **`WsServer`** — servidor WebSocket que corre en el host (`AppConstants.localGamePort`), gestiona el `LobbyRoom` autoritativo y retransmite `RoomStateMessage` tras cada cambio
- **`WsClient`** (sobre `web_socket_channel`) — cliente WebSocket usado por todos los jugadores (incluido el host, vía loopback `127.0.0.1`), con estado de conexión y heartbeat ping/pong
- **`MdnsAdvertiser`** — anuncia la sala en la red local mediante beacons UDP broadcast periódicos (255.255.255.255 : `AppConstants.discoveryPort`); sincroniza el contador de jugadores en cada cambio de sala
- **`MdnsDiscoverer`** — escucha beacons UDP y expone `Stream<List<DiscoveredRoom>>` con las salas detectadas
- **`ILobbyRepository`** / **`LobbyRepository`** — coordina `WsServer` + `WsClient` + `MdnsAdvertiser` + `MdnsDiscoverer` para exponer `createRoom`, `discoverRooms`, `joinRoom`, `setReady`, `startGame` y `leaveRoom` como una única fachada
- **`LobbyNotifier` / `lobbyProvider`** — `Notifier<LobbyState>` con estados `LobbyIdle`, `LobbyConnecting`, `LobbyDiscovering`, `LobbyInRoom`, `LobbyError`; `playerIdProvider` (UUID de sesión) y `wifiIpProvider`
- **`LobbyScreen`** — UI completa: crear sala, descubrir/unirse a salas en la red, lista de jugadores con estado ready, botón de inicio habilitado solo si `canStart`
- Permisos de red en Android: `INTERNET`, `ACCESS_NETWORK_STATE`, `ACCESS_WIFI_STATE`, `CHANGE_WIFI_MULTICAST_STATE`
- 34 tests nuevos del lobby (modelos, repositorio, providers) — 51 tests totales pasando

### Cambiado
- `WsClient` migrado a `web_socket_channel` (antes stub propio) para mayor compatibilidad multiplataforma

### Notas técnicas
- El descubrimiento de salas usa beacons UDP broadcast propios, no mDNS/Bonjour real; queda pendiente migrar a la librería `nsd` o `multicast_dns` para descubrimiento estándar (ver TODOs en `mdns_advertiser.dart` / `mdns_discoverer.dart`)
- `LobbyRepository` unifica los modos host/cliente en una sola clase; se evaluará separarla en `HostLobbyRepository` / `ClientLobbyRepository` si crece en complejidad

---

## [0.2.0] — 2026-07-05

### Añadido
- **SplashScreen** — animaciones escalonadas con `flutter_animate` (scale elástico, fadeIn, slideY); navega a Home tras `AppConstants.splashDuration`
- **HomeScreen** — menú principal con tema oscuro completo, botones animados y pie de disclaimer
- **SettingsScreen** — nombre de jugador, volumen y toggles de audio/música con persistencia en SharedPreferences (`AsyncNotifier` Riverpod 3)
- `AppSettings` — modelo inmutable con `copyWith` y `Equatable` en capa domain de settings
- `SettingsNotifier` / `settingsProvider` — `AsyncNotifierProvider` con auto-guardado en SharedPreferences
- Pantallas placeholder para Lobby, Game y GameOver (Fases 3 y 4)
- Router completo con las 6 rutas: `/`, `/home`, `/lobby`, `/game`, `/game/over`, `/settings`

### Corregido
- `GameEngine.startGame` — reemplaza destructuring de record inválido por acceso explícito (`result.players`, `result.deck`)
- `ActionProcessor` — elimina import de `exceptions.dart` no utilizado
- `GameRules` — elimina imports de `player_model.dart` y `nope_rules.dart` no utilizados
- `FailureResult<T>` (era `Failure_<T>`) — renombrado a UpperCamelCase válido
- `UnknownFailure` — usa super parameter en lugar de inicializador explícito
- `AssetPaths.card()` — elimina interpolación de llaves innecesaria

### Tecnologías actualizadas
- Riverpod 3.1 / riverpod_generator 4.0
- GoRouter 17.3
- freezed 3.2 / freezed_annotation 3.1
- network_info_plus 8.2 (plugin Kotlin)

---

## [0.1.0] — 2026-07-05

### Añadido
- Estructura de proyecto Flutter con arquitectura feature-first (`com.zenxlk`)
- **`game_engine/`** — motor de juego en Dart puro, sin dependencias de Flutter
  - Modelos inmutables: `CardModel`, `PlayerModel`, `DeckModel`, `TurnModel`, `GameState`
  - `CardType` con todas las cartas de la edición base (incluidas las 5 cartas gato)
  - `DeckBuilder` — construcción y reparto del mazo según número de jugadores (2–5)
  - `DeckManager` — operaciones puras: `drawTop`, `insertAt`, `discard`, `shuffle`, `peekTop`
  - `GameRules` — validación de acciones antes de procesarlas
  - `CardRules` — jugabilidad, pares/tríos de gatos, Nope, Defuse
  - `NopeRules` — cadena Nope/Nope-a-Nope (contador impar = cancelado)
  - `TurnRules` — rotación de turno, Attack chains (`actionsLeft`)
  - `WinCondition` — detección de único superviviente
  - `ActionProcessor` — efectos de todas las cartas: Attack, Skip, Favor, Shuffle, See the Future, Cat Pair, Cat Trio, Defuse, Nope
  - `GameEngine` — fachada pública con `startGame()` y `apply(TurnAction)`
  - `GameEventBus` — `Stream<GameEvent>` broadcast para desacoplar UI y red
- **`core/`** — constantes, errores, extensiones, tema, router y utilidades
- **`features/`** — estructura feature-first con splash y home screen funcionales
- **`network/`** — stubs de WebSocket (cliente, servidor, reconexión) y mensajes tipados
- **`assets/`** — carpetas placeholder para cartas, sonidos, animaciones y fuentes
- **CI** — GitHub Actions: análisis estático, tests y build APK debug
- **GitHub** — `dependabot.yml`, plantillas de issue y PR, `.editorconfig`
- 16 tests unitarios del motor pasando

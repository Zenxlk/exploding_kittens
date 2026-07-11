# Changelog

Formato basado en [Keep a Changelog](https://keepachangelog.com/es/1.0.0/).

---

## [Unreleased]

### En progreso
- Fase 6: mejoras técnicas, bots y expansiones (ver ROADMAP.md)

---

## [0.5.2] — 2026-07-11

### Corregido
- Reportado por el usuario: quedarse solo con cartas de gato sueltas (sin pareja) se sentía como que el juego se congelaba. `CardRules.canPlay` ahora rechaza una carta de gato jugada sola vía `PlayCardAction` (antes pasaba la validación igual, se descartaba sin efecto y el turno no avanzaba — un agujero negro solo evitado por la UI); y el mensaje de la barra de selección ahora indica explícitamente que se puede tocar el mazo para robar y pasar el turno

---

## [0.5.1] — 2026-07-11

### Corregido
- Verificación manual de Fase 5 en 2 emuladores reales (ver `docs/VERIFICATION_LOG.md`): estado real jugado y sincronizado en ambos sentidos, `InsertBombOverlay`/`ExplosionOverlay`/`GameOverScreen` confirmados en el no-host, y el pipeline completo de grace period + eliminación por desconexión probado de punta a punta con una caída real del proceso
- `GameOverScreen` no navegaba al no-host cuando el host iniciaba una revancha — se quedaba varado mostrando "no hay ningún resultado de partida". Ahora escucha `remoteGameProvider` y navega a la partida nueva en cuanto deja de estar en `GameFinished`

### Documentado (sin arreglar, fuera de alcance de esta sesión)
- Recrear una sala sin salir de la anterior en la misma sesión de app dejaba un "servidor fantasma" (el `WsServer` viejo nunca se cerraba) — bug real del ciclo de vida del lobby (Fase 3), no de la sincronización de Fase 5; candidato para una futura sesión

---

## [0.5.0] — 2026-07-09

### Añadido — Fase 5 completa: red y reconexión
- Con las piezas de las versiones 0.4.2 a 0.4.10 (serialización del motor, transporte en `WsServer`/`WsMessage`, `ReconnectionManager`, eliminación por desconexión en el motor, `RemoteGameNotifier`, el puente host↔red, `GameScreen`/`GameOverScreen` sincronizados y la reconexión automática de `WsClient`) se cierra la Fase 5: los dispositivos no-host ya juegan la partida real sincronizada por WebSocket, no solo el host.
- 200 tests totales pasando

**Con esto se cierra la Fase 5 — Red y reconexión.** Decisión de diseño clave: en vez de forzar un `RemoteGameGateway` dentro de la interfaz síncrona `IGameGateway` existente (hubiera obligado a convertir `apply()`/`startGame()` a streams y reescribir los tests ya existentes de `GameNotifier`), se optó por `RemoteGameNotifier` como clase separada que refleja el mismo `GameSessionState` — cero riesgo sobre lo construido en Fase 4. Queda pendiente, documentado en ROADMAP.md, todo lo de Fase 6 (mDNS real, bots, modo online, expansiones, publicación).

---

## [0.4.10] — 2026-07-09

### Añadido — Fase 5: reconexión automática del cliente
- `WsClient` reconecta solo con back-off exponencial (1s→16s) tras una caída no solicitada (`close()` explícito no la dispara); `messages`/`status`/`roomStream` siguen funcionando sin que quien los escucha tenga que volver a suscribirse

### Corregido
- `WsServer.close()` no cerraba los sockets ya conectados (`HttpServer.close(force: true)` no toca las conexiones que ya completaron el upgrade a WebSocket) — se filtraban sin avisar a los clientes del cierre; ahora se cierran explícitamente
- 200 tests totales pasando

---

## [0.4.9] — 2026-07-09

### Añadido — Fase 5: GameScreen/GameOverScreen sincronizados
- `GameScreen`/`GameOverScreen` ya no muestran el placeholder fijo "esperando Fase 5" para los no-host: eligen `gameProvider`/`remoteGameProvider` según `isHost` y despachan a quien corresponda; el host activa `gameNetworkBridgeProvider`, el no-host conecta `RemoteGameNotifier` al `WsClient` que ya abrió el lobby
- `PlayersHudWidget` muestra "Reconectando…" + icono de wifi apagado para `PlayerStatus.disconnected`
- 198 tests totales pasando

---

## [0.4.8] — 2026-07-09

### Añadido — Fase 5: puente host↔red
- `gameNetworkBridgeProvider` — conecta `GameNotifier` (motor real, solo host) con `WsServer` (red): aplica `ActionMessage`s entrantes, contesta `ActionRejectedMessage` solo a quien mandó una acción inválida, y retransmite cada `GameState`/`GameEvent` como `GameStateMessage`/`GameEventMessage`; conecta también `WsServer.onPlayerDisconnected`/`onPlayerReconnected` a un `ReconnectionManager`
- `IGameGateway`/`LocalGameGateway`/`GameNotifier` ganan `markPlayerDisconnected`/`markPlayerReconnected`

### Corregido
- `WsServer._onJoin` disparaba `onPlayerReconnected` para cualquier unión de un `playerId` ya conocido (no solo reconexiones reales tras una caída); `GameNotifier.markPlayerDisconnected`/`markPlayerReconnected` ahora omiten la retransmisión si el motor devolvió el mismo estado (no-op), encontrado por el test de integración del puente
- 196 tests totales pasando

---

## [0.4.7] — 2026-07-09

### Añadido — Fase 5: RemoteGameNotifier
- `RemoteGameNotifier`/`remoteGameProvider` — refleja para un dispositivo no-host el mismo `GameSessionState` que ya produce `GameNotifier`, mandando las acciones locales por `ActionMessage` y reflejando `GameStateMessage`/`GameEventMessage`/`ActionRejectedMessage`; se decidió como clase separada (no una `RemoteGameGateway implements IGameGateway`) para no tener que convertir `apply()`/`startGame()` a streams ni reescribir los tests existentes de `GameNotifier`
- `GameNotifier` gana `applyAction`/`rawStates`/`eliminateForDisconnect` para el puente host↔red (próxima pieza); `IGameGateway` gana `eliminatePlayerForDisconnect`, mismo patrón que `resolveNopeWindow`
- 188 tests totales pasando

---

## [0.4.6] — 2026-07-09

### Añadido — Fase 5: acceso al WsClient/WsServer del lobby
- `ILobbyRepository`/`LobbyRepository`/`LobbyNotifier` exponen ahora `wsClient`/`wsServer` (getters aditivos, sin cambio de comportamiento) para que la partida reutilice la conexión que el lobby ya abrió en vez de crear una segunda

---

## [0.4.5] — 2026-07-09

### Añadido — Fase 5: eliminación por desconexión en el motor
- `GameEngine.markPlayerDisconnected`/`markPlayerReconnected`/`eliminatePlayerForDisconnect` — tres operaciones puras más (ninguna es un `TurnAction`, no pasan por `GameRules.validate`, mismo patrón que `resolveNopeWindow`) para que el `ReconnectionManager` tenga con qué actuar cuando expira el grace period: reutiliza el mismo camino de `eliminationOrder`/`WinCondition` que ya usa la eliminación por bomba
- 170 tests totales pasando

---

## [0.4.4] — 2026-07-09

### Añadido — Fase 5: ReconnectionManager
- `ReconnectionManager` real (antes era solo un comentario `TODO`): un `Timer` de grace period por jugador desconectado, usando `GameConstants.reconnectTimeoutSeconds` (60s) por defecto; `cancelIfPending` lo cancela si reconecta a tiempo
- 162 tests totales pasando

---

## [0.4.3] — 2026-07-09

### Añadido — Fase 5: transporte de mensajes en partida
- `WsMessage`: activados los mensajes de partida (`GameStateMessage`, `ActionMessage`) que antes eran stubs sin usar, y añadidos `GameEventMessage` (para que los no-host, sin motor local, disparen sonidos/animaciones) y `ActionRejectedMessage` (feedback dirigido cuando una acción de un cliente falla `GameRules.validate` en el host)
- `WsServer` ahora enruta `ActionMessage` de verdad (antes caía al `default` y se perdía) por un nuevo stream `actionMessages`, y expone `broadcast()`/`sendToPlayer()` públicos
- `WsServer.markGameStarted()` distingue una desconexión de lobby (comportamiento de siempre) de una desconexión a mitad de partida, que ahora dispara `onPlayerDisconnected` en vez de sacar al jugador de la sala — la capa de juego decide qué hacer (grace period, siguiente pieza de la fase)
- 156 tests totales pasando

---

## [0.4.2] — 2026-07-09

### Añadido — Fase 5: serialización del motor
- `toJson()`/`fromJson()` manuales en todos los modelos puros del motor (`CardModel`, `PlayerModel`, `DeckModel`, `TurnModel`, `GameConfig`, `GameResult`, `GameState`) y en las dos jerarquías selladas (`TurnAction`, `GameEvent`), mismo estilo ya usado por los modelos del lobby — necesario para que el `GameState`/las acciones/los eventos viajen por WebSocket en el resto de la fase
- `TurnAction` ahora extiende `Equatable` (era el único modelo del motor que no lo hacía); sin esto, la igualdad estructural de `GameState` se rompía en cuanto `pendingAction` contenía una instancia no-`const` (p. ej. una reconstruida desde JSON)
- 149 tests totales pasando

---

## [0.4.1] — 2026-07-08

### Corregido
- `SettingsScreen` mostraba la versión hardcodeada `0.1.0` desde el primer release, nunca actualizada en los bumps posteriores — ahora dice `0.4.0`

---

## [0.4.0] — 2026-07-08

### Añadido — Fase 4 completa: flutter_animate + cierre de fase
- **`flutter_animate` en cartas y overlays**: `CardWidget` hace un "pop" de escala (`.animate().scaleXY(...)`) al volverse jugable; los 5 overlays de la mesa (`SeeTheFutureOverlay`, `FavorTargetOverlay`, `NopeWindowOverlay`, `InsertBombOverlay`, `ExplosionOverlay`) ahora tienen un fade-in de entrada — mismo estilo `.animate()` que ya usaban `HomeScreen`/`SplashScreen`
- Ajustados los tests de `game_table_view_test.dart` y `see_the_future_overlay_test.dart` para asentar (`pumpAndSettle`) las animaciones antes de verificar, siguiendo el mismo patrón que `home_screen_test.dart` ya usaba — `flutter_animate` deja un `Timer` corriendo internamente y `flutter_test` falla si queda pendiente al terminar el test
- 118 tests totales pasando

**Con esto se cierra la Fase 4 — Pantalla de juego completa.** Los 4 overlays de interacción (Nope, InsertBomb, Favor/pares, SeeTheFuture), `ExplosionOverlay`, `GameOverScreen` con ranking y revancha, audio (efectos + música) y animaciones están implementados sobre el motor de la Fase 1. Quedan fuera de esta fase, documentados como pendientes: trío de gatos (necesita su propio diseño de UI para elegir carta de la mano rival), música de menú fuera de la pantalla de juego, y por supuesto toda la sincronización real por red (Fase 5).

---

## [0.3.13] — 2026-07-08

### Añadido — Fase 4: tests de providers
- `GameNotifier` — un test por método de intención (`playCard`, `playFavor`, `playCatPair`, `playCatTrio`, `playNope`, `defuse`) que verifica el `TurnAction` concreto construido y sus campos, más un test del nuevo getter `events`. Antes solo se probaba el camino genérico de `_apply` (error/éxito/fin de partida) a través de `drawCard`, sin confirmar que el resto de métodos arman la acción correcta
- 118 tests totales pasando

---

## [0.3.12] — 2026-07-08

### Añadido — Fase 4: audioplayers (efectos y música)
- **`IAudioService`/`AudioService`** (`core/audio/`) — dos reproductores independientes (efectos vs. música en loop) sobre `audioplayers`; los fallos de reproducción se capturan y loguean en vez de propagarse, para que un audio faltante o sin salida de sonido no interrumpa la partida. Expuesto vía `audioServiceProvider`, sustituible por un fake en tests de widgets
- **`GameSoundController`** — se suscribe al `Stream<GameEvent>` del motor (nuevo getter `GameNotifier.events`) mientras dura la partida y reproduce el efecto de cada evento (`soundAssetFor`, función pura testeada aparte): robar, jugar carta (Attack tiene su propio clip), barajar, bomba activada, Defuse, Nope, fin de partida. `PlayerEliminatedEvent` no suena aparte a propósito — se emite junto a `BombTriggeredEvent` en el mismo instante y sonarían duplicados
- `GameScreen` reproduce `music_ingame.mp3` y `GameOverScreen` reproduce `music_gameover.mp3` en loop mientras están montadas, resincronizando volumen/activado cuando cambian los ajustes
- Corrección de `AssetPaths`: los nombres de sonido no coincidían con los archivos reales de `assets/sounds/` (`card_draw.mp3` → `draw_card.mp3`, `explosion.mp3` → `explode.mp3`, etc.); Defuse y "jugador eliminado" reusan `countdown.mp3`/`explode.mp3` porque no tienen clip propio todavía (ver `ATTRIBUTION.md`)
- 4 tests nuevos (`soundAssetFor` + `GameSoundController` con un `IAudioService` fake) — 111 tests totales pasando
- **Fuera de alcance esta vez**: música de menú (`music_menu.mp3`) en Home/Splash/Lobby/Settings — queda anotada en el Roadmap (Fase 6), no es parte de "pantalla de juego completa"

---

## [0.3.11] — 2026-07-08

### Añadido — Fase 4: GameOverScreen
- **`GameOverScreen`** ahora es un `ConsumerWidget` real: muestra el nombre del ganador, turnos jugados y el ranking completo (ganador primero, luego el orden inverso de eliminación real — el último en explotar queda 2º, el primero en explotar queda último), cruzando `GameResult.eliminationOrder` con los nombres de `lobbyProvider`
- Botón **Revancha** solo para el host (mismo límite que `GameScreen`: solo el host corre el `GameEngine` real hasta la Fase 5); re-arranca la partida con `startLocalGame` reusando los jugadores actuales de la sala y el mismo `GameEventBus`
- Ruta `/game/over` deja de depender de un query param `winnerId` — lee el resultado directo de `gameProvider` (`GameFinished`), evitando duplicar estado que ya vive en el provider
- 3 tests nuevos (`GameOverScreen`: sin resultado, ranking + revancha visible para el host, oculto para no-host)

### Corregido — orden de eliminación
- `WinCondition.check` construía `GameResult.eliminationOrder` filtrando `GameState.players`, que sigue el orden de la lista, no el orden real en que los jugadores explotaron — un bug ya detectado durante la planificación de Fase 4 pero sin arreglar hasta que `GameOverScreen` lo necesitó de verdad. `GameState` gana un campo `eliminationOrder` que `ActionProcessor._eliminatePlayer` va llenando en el momento exacto de cada eliminación; `WinCondition` solo lo reexpone
- 1 test nuevo (`ActionProcessor`: el orden de eliminación es cronológico, no el de la lista de jugadores) — 106 tests totales pasando

---

## [0.3.10] — 2026-07-08

### Añadido — Fase 4: ExplosionOverlay
- **`ExplosionOverlay`** — animación de eliminación (jugador robó Exploding Kitten sin Defuse): ícono con escala y rebote (`Curves.elasticOut`) sobre fondo oscuro, se cierra sola después de 1.6s sin necesitar ninguna acción del jugador. Placeholder con Flutter puro; se reemplaza por el Lottie real de `AssetPaths.animExplosion` cuando ese asset exista (`assets/animations/` sigue vacío)
- `GameTableView` detecta la eliminación por diff entre el `GameState` anterior y el nuevo (un jugador que estaba vivo deja de estarlo) — no hay ningún evento ni campo dedicado en `GameState` para esto, mismo enfoque que ya usa el descarte de `SeeTheFutureOverlay`
- 2 tests nuevos (`GameTableView`: overlay aparece al detectar la eliminación; se cierra solo tras la animación, usando `pumpAndSettle`) — 102 tests totales pasando

---

## [0.3.9] — 2026-07-08

### Añadido — Fase 4: InsertBombOverlay
- **`InsertBombOverlay`** — se muestra mientras `TurnModel.phase == TurnPhase.resolving` y `GameState.pendingBomb != null`, solo al jugador que robó la bomba; `Slider` para elegir la posición de reinserción entre 0 (arriba del todo, la próxima carta que se robaría) y `drawPileCount` (abajo del todo) — el motor (`DeckManager.insertAt`) ya clampaba cualquier valor, así que no hace falta validación extra en la UI
- `GameTableView` gana el callback `onDefuseBomb`, conectado en `GameScreen` a `gameProvider.notifier.defuse(...)` (ya existía en el notifier, sin cambios de engine); toma la primera carta Defuse de la mano, garantizada por el invariante del motor (solo se llega a `resolving` si el jugador tiene Defuse)
- Banner de estado actualizado: mientras se resuelve la bomba, los demás jugadores ven "Esperando a que \<jugador\> esconda la bomba…" en vez del texto genérico anterior
- 2 tests nuevos (`GameTableView`: overlay se muestra y confirma con la posición elegida; no se muestra al jugador que no tiene el turno) — 100 tests totales pasando

---

## [0.3.8] — 2026-07-08

### Añadido — Fase 4: NopeWindowOverlay
- **`NopeWindowOverlay`** — se muestra mientras `TurnModel.phase == TurnPhase.nopeWindow`; barra de progreso puramente visual (no hay timestamp de apertura en `GameState`, así que el conteo es client-side y se reinicia cada vez que cambia `nopeChainCount`, igual que el `Timer` real del `GameNotifier`) y botón "¡Nope!" habilitado solo si el jugador local tiene una carta Nope en mano y existe `pendingAction` — misma condición que `CardRules.canNope` en el motor
- `GameTableView` gana el callback `onPlayNope`, conectado en `GameScreen` a `gameProvider.notifier.playNope(...)` (ya existía en el notifier, sin cambios de engine)
- 2 tests nuevos (`GameTableView`: overlay se muestra y juega el Nope de la mano; botón deshabilitado sin Nope en mano) — 98 tests totales pasando

---

## [0.3.7] — 2026-07-07

### Añadido — Fase 4: FavorTargetOverlay
- **`FavorTargetOverlay`** — selector de jugador objetivo, usado por Favor (1 carta) y pares de gato (2 cartas del mismo tipo); ambos solo necesitan un objetivo, no una carta específica de la mano rival
- `GameTableView` pasa de selección de una sola carta a selección múltiple (`Set<String>`), con una clasificación explícita de qué se puede hacer con lo seleccionado: jugar directo (Attack/Skip/Shuffle/SeeTheFuture), elegir objetivo (Favor/par), esperar la pareja (una sola carta de gato), o "se juega en otro momento" (Nope/Defuse sueltos, trío de gatos)
- **Trío de gatos queda diferido a propósito**: el motor requiere que el actor indique `chosenCardId`, una carta concreta de la mano del rival que no puede ver en este diseño (un dispositivo por jugador) — necesita su propio diseño de UI, no se fuerza uno ad-hoc
- 6 tests nuevos (`GameTableView`: hint de par, flujo Favor completo, flujo par de gatos completo, cancelar limpia selección) — 96 tests totales pasando

---

## [0.3.6] — 2026-07-07

### Añadido — Fase 4: primer overlay (See the Future)
- **`SeeTheFutureOverlay`** — muestra las 3 cartas de arriba del mazo (de arriba hacia abajo) con los placeholders de `CardVisuals`, y un botón "Continuar" para cerrarlo
- `GameTableView` deriva su visibilidad de `GameState.seeTheFutureCards` (sin nuevo estado en el provider); el "descartado" es estado local de UI, porque el campo solo se limpia cuando el turno avanza (`TurnManager.advance`), no cuando el jugador ya lo vio — una revelación nueva (null → no-null) vuelve a mostrarlo aunque la anterior ya estuviera cerrada
- 4 tests nuevos (`SeeTheFutureOverlay` + integración en `GameTableView`) — 92 tests totales pasando

---

## [0.3.5] — 2026-07-07

### Añadido — Fase 4: GameScreen conectado
- **`GameTableView`** — composición de mesa (HUD + mazo + descarte + mano + banner de estado); solo muestra y controla la mano del **jugador local** (no la de quien tenga el turno), pensado para que cada dispositivo conectado a la sala sea dueño de un único jugador. Selección de carta por tap y botón "Jugar" para las cartas sin objetivo (Attack, Skip, Shuffle, See the Future); Favor/pares-tríos de gato/Nope/Defuse muestran "se juega en el próximo paso" hasta los overlays de selección de objetivo
- **`GameScreen`** conectado a `gameProvider` y `lobbyProvider`: solo el host arranca hoy el `GameEngine` real (vía `LocalGameGateway`) al entrar a la sala; los no-host ven "Esperando sincronización con el host… (llega en la Fase 5)" — sincronizar el estado real por red es explícitamente Fase 5, no se simula
- Navega a `GameOverScreen` automáticamente cuando el `GameState` llega a `GamePhase.finished`
- 7 tests nuevos (`GameTableView` + `GameScreen` con lobby/gateway fake) — 88 tests totales pasando

### Verificado
- App compilada y lanzada en un dispositivo Android real (`flutter run`): arranca sin errores hasta `HomeScreen`. No fue posible automatizar taps con ADB (el dispositivo no concede `INJECT_EVENTS`), así que el flujo Lobby → GameScreen no se probó de punta a punta en este dispositivo — requiere además un segundo dispositivo real en la misma red para completar el lobby (`GameConstants.minPlayers = 2`)

---

## [0.3.4] — 2026-07-07

### Añadido — Fase 4: widgets de mesa
- **`CardWidget`** — carta individual con flip animado (boca arriba/abajo), glow cuando es jugable, borde de selección; usa el placeholder de `CardVisuals` si `assetPath` es `null`
- **`DeckWidget`** — dorso del mazo con contador de cartas restantes
- **`DiscardPileWidget`** / **`DottedCardSlot`** — última carta descartada boca arriba, o hueco vacío si aún no se descartó nada
- **`PlayersHudWidget`** — avatares de todos los jugadores con nombre y contador de cartas; atenúa a los eliminados y resalta a quien tiene el turno
- **`PlayerHandWidget`** — mano del jugador local en abanico, selección por tap (no drag & drop, necesario igualmente para elegir pares/tríos de gato)
- Todos son widgets "tontos": reciben datos ya resueltos (tipo de carta, ruta de asset, callbacks) y no leen providers — se pueden testear con fixtures sin `ProviderScope`
- 12 tests nuevos de widgets — 81 tests totales pasando

---

## [0.3.3] — 2026-07-07

### Añadido — Fase 4: fundamentos (CardAssetResolver + GameNotifier)
- **`CardVisuals`** — apariencia de respaldo (color, icono, nombre) por `CardType`, usada como placeholder mientras no exista el arte final
- **`CardAssetResolver`** — resuelve la ruta real de una carta desde el `AssetManifest` del bundle si ya existe, o `null` para caer al placeholder; permite ir soltando el arte carta por carta sin tocar ningún widget (hoy con `assets/cards/` vacío, todo resuelve a placeholder)
- **`IGameGateway`** / **`LocalGameGateway`** — fachada entre la UI y "la partida"; hoy envuelve un `GameEngine` local, deja el hueco para un gateway remoto en Fase 5 sin cambiar el Notifier ni los widgets
- **`GameNotifier`** / **`gameProvider`** — `Notifier<GameSessionState>` (`GameIdle` / `GameRunning` / `GameFinished`) con métodos de intención (`drawCard`, `playCard`, `playFavor`, `playCatPair`, `playCatTrio`, `playNope`, `defuse`); captura `InvalidActionException` como error transitorio sin romper la UI; agenda y resuelve la ventana de Nope con un `Timer` interno (`GameConstants.nopeWindowMs`) llamando a `resolveNopeWindow()`
- 7 tests nuevos del `GameNotifier` con un `IGameGateway` fake — 69 tests totales pasando

---

## [0.3.2] — 2026-07-07

### Corregido — prework de engine para Fase 4
- **La ventana de Nope nunca se cerraba** — no existía ninguna vía para resolverla, y los efectos de Favor, Cat Pair/Trío y Shuffle se aplicaban *antes* de abrir la ventana, así que un Nope exitoso no podía cancelar nada. Ahora esos efectos se difieren y `ActionProcessor.resolveNopeWindow()` (expuesto como `GameEngine.resolveNopeWindow()`) los aplica solo si la cadena de Nopes no quedó cancelada (`nopeChainCount` par)
- **Defuse duplicaba o perdía la bomba** — al reinsertar la bomba se buscaba cualquier Exploding Kitten restante en el mazo en vez de la carta realmente robada, duplicándola (o perdiéndola si era la última). Ahora se guarda en `GameState.pendingBomb` y se reinserta exactamente esa carta

### Eliminado
- `TurnManager.closeNopeWindow()` / `requireDraw()` — código muerto sin llamadas, sustituido por `ActionProcessor.resolveNopeWindow()`

### Notas técnicas
- `GameEngine.dispose()` documentado: cierra el `GameEventBus` singleton de por vida de la app; no debe llamarse desde el ciclo de vida de un provider (p. ej. en una revancha)
- 4 tests nuevos de `ActionProcessor` (Defuse, Favor diferido, Nope cancela Favor, Shuffle diferido) — 62 tests totales pasando

---

## [0.3.1] — 2026-07-06

### Añadido
- Tests de widgets para `HomeScreen` (render de título/botones/pie y navegación a crear sala, unirse a sala y ajustes) y `SettingsScreen` (carga de preferencias persistidas, guardado de nombre de jugador, toggle de sonido) — cierra el ítem pendiente de Fase 2, 58 tests totales pasando

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

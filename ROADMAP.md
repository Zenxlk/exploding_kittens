# Roadmap

Trabajo planificado por fases. Cada fase es funcional por sí sola antes de
empezar la siguiente.

---

## Fase 1 — Motor de juego ✅

> Dart puro, sin dependencias de Flutter. Totalmente testeable en aislamiento.

- [x] Modelos inmutables: `CardModel`, `PlayerModel`, `DeckModel`, `TurnModel`, `GameState`
- [x] `CardType` con todas las cartas oficiales (base + gatos)
- [x] `DeckBuilder` — construcción y reparto según número de jugadores
- [x] `DeckManager` — robar, descartar, insertar en posición, peek top N
- [x] `GameRules` — validación de acciones antes de aplicarlas
- [x] `CardRules` — jugabilidad por tipo, par/trío de gatos, Nope, Defuse
- [x] `NopeRules` — cadena Nope/Nope-a-Nope con contador impar/par
- [x] `TurnRules` — rotación de turno, Attack chains
- [x] `WinCondition` — detección de ganador
- [x] `ActionProcessor` — aplicación de efectos: Attack, Skip, Favor, Shuffle, See the Future, Cat Pair/Trio, Defuse, Nope
- [x] `GameEngine` — fachada pública (`startGame` / `apply`)
- [x] `GameEventBus` — stream broadcast de eventos para UI y red
- [x] Tests unitarios: `CardModel`, `DeckManager`, `CardRules`

---

## Fase 2 — UI base y navegación ✅

- [x] Rutas completas en `app_router.dart` (lobby, game, game-over, settings)
- [x] `SplashScreen` — logo animado con Lottie
- [x] `HomeScreen` — menú principal con botones animados
- [x] `SettingsScreen` — volumen, nombre de jugador, preferencias
- [x] Sistema de tema oscuro consolidado
- [x] Fuente personalizada integrada (`ExplodingFont`)
- [x] Tests de widgets para pantallas principales — `HomeScreen` (render + navegación) y `SettingsScreen` (carga de prefs, guardado de nombre, toggle de sonido)

---

## Fase 3 — Lobby local WiFi ✅

- [x] `MdnsDiscoverer` — descubrimiento de salas via beacons UDP broadcast (sustituye al mDNS real previsto; ver nota abajo)
- [x] `WsServer` — servidor WebSocket en el host (`AppConstants.localGamePort`)
- [x] `LobbyRoom` / `LobbyPlayer` con estados vía `LobbyStatus`
- [x] `LobbyRepository` — createRoom / joinRoom / leaveRoom / setReady / startGame (sin UseCases separados; coordinados directamente en el repositorio)
- [x] `LobbyScreen` — creación de sala, descubrimiento y unión, lista de jugadores conectados con estado ready, botón de inicio
- [x] Tests del lobby (modelos, repositorio, providers) — 34 tests nuevos, 51 totales

> Nota: el descubrimiento usa UDP broadcast propio, no mDNS/Bonjour estándar.
> Migrar a `nsd` o `multicast_dns` queda como mejora futura (Fase 6).

---

## Fase 4 — Pantalla de juego completa ✅

- [x] Prework de engine: `ActionProcessor.resolveNopeWindow()` / `GameEngine.resolveNopeWindow()` — difiere y resuelve los efectos de Favor, Cat Pair/Trío y Shuffle según si la cadena de Nope quedó cancelada; fix de la duplicación de bomba en Defuse (`GameState.pendingBomb`)
- [x] `CardAssetResolver` / `CardVisuals` — resuelve el asset real de una carta desde el `AssetManifest` si ya existe, o cae a un placeholder (color + icono + nombre) por `CardType`; permite ir soltando arte final carta por carta sin tocar widgets
- [x] `GameStateProvider` — implementado como `GameNotifier` / `gameProvider` (`Notifier<GameSessionState>`, no `StateNotifier`, siguiendo el patrón ya usado por `lobbyProvider`), con `IGameGateway`/`LocalGameGateway` de por medio para poder enchufar un gateway remoto en Fase 5 sin tocar la UI
- [x] `GameScreen` — conectado a `gameProvider`/`lobbyProvider`; layout adaptativo por reflow (Expanded + scroll interno, sin dos árboles portrait/landscape duplicados); solo el host arranca el `GameEngine` hoy, los no-host ven un placeholder de "esperando Fase 5"
- [x] `PlayerHandWidget` — fan de cartas, selección por tap (se descartó drag & drop: más simple y necesario igual para pares/tríos de gato)
- [x] `CardWidget` — flip animation, glow en cartas jugables
- [x] `DeckWidget` — contador de cartas (sin animación de robo todavía: se hará en Fase de overlays/eventos, diferenciando carta robada por diff de longitud de mano)
- [x] `DiscardPileWidget` — pila de descarte con última carta visible
- [x] `PlayersHudWidget` — avatares de jugadores con contador de cartas
- [x] `NopeWindowOverlay` — temporizador visual (barra de progreso client-side, sin timestamp en `GameState`) y botón reactivo, habilitado solo si el jugador local tiene un Nope en mano y hay una acción pendiente
- [x] `InsertBombOverlay` — slider para elegir en qué posición del mazo reinsertar la Exploding Kitten robada, entre "arriba del todo" y "abajo del todo"; solo se muestra al jugador que la robó
- [x] `SeeTheFutureOverlay` — visualización de top 3 cartas, visibilidad derivada de `GameState.seeTheFutureCards`, descartado como estado local de UI
- [x] `FavorTargetOverlay` — selector de objetivo para Favor y pares de gato; el trío de gatos queda diferido (necesita elegir una carta concreta de la mano rival, que el actor no puede ver — hace falta su propio diseño de UI)
- [x] `ExplosionOverlay` — animación de eliminación (placeholder con Flutter puro, escala con rebote; se reemplazará por el Lottie real de `AssetPaths.animExplosion` cuando exista ese asset); se detecta por diff de `GameState` (un jugador que estaba vivo deja de estarlo), se cierra sola sin acción del jugador
- [x] `GameOverScreen` — ganador, ranking en orden real de eliminación (fix de `WinCondition`/nuevo `GameState.eliminationOrder`: antes seguía el orden de la lista de jugadores, no el cronológico) y botón de revancha, solo para el host (mismo límite que `GameScreen` hoy); revancha re-arranca el mismo `GameEngine`/bus con los jugadores de la sala actual
- [x] Integración de `audioplayers` (efectos y música de fondo) — `IAudioService`/`AudioService` (interfaz + impl, testeable con fake), `GameSoundController` reproduce el efecto de cada `GameEvent` del motor mientras dura la partida, `GameScreen`/`GameOverScreen` reproducen `music_ingame.mp3`/`music_gameover.mp3` en loop. De paso se corrigieron los nombres de archivo en `AssetPaths` (no coincidían con los reales en `assets/sounds/`). **Alcance de esta pasada**: solo pantallas de partida; `music_menu.mp3` para Home/Splash/Lobby/Settings queda pendiente (no es parte de "pantalla de juego completa")
- [x] Integración de `flutter_animate` en cartas y transiciones — `CardWidget` hace un "pop" de escala al volverse jugable, y los 5 overlays (SeeTheFuture/FavorTarget/NopeWindow/InsertBomb/Explosion) tienen fade-in de entrada, mismo estilo `.animate()` que ya usaban Home/Splash
- [x] Tests de providers y casos de uso — `GameNotifier`: un test por método (`playCard`/`playFavor`/`playCatPair`/`playCatTrio`/`playNope`/`defuse`) verificando el `TurnAction` concreto que dispatchea, más el nuevo getter `events`; 118 tests totales pasando

---

## Fase 5 — Red y reconexión ⏳

- [ ] `WebSocketServer` — host recibe acciones, aplica al engine, retransmite estado
- [ ] `WebSocketClient` — clientes envían acciones, reciben `GameState`
- [ ] `GameStateSerializer` — `GameState` ↔ JSON para transmisión
- [ ] `EventSerializer` — `GameEvent` ↔ JSON
- [ ] `ReconnectionManager` — grace period, backoff exponencial, restauración de estado
- [ ] Manejo de `PlayerStatus.disconnected` en UI
- [ ] Tests de serialización y reconexión

---

## Fase 6 — Futuro 🗓

### Mejoras técnicas pendientes
- [ ] Migrar `MdnsAdvertiser` / `MdnsDiscoverer` de UDP broadcast a mDNS/Bonjour real (`nsd` o `multicast_dns`)
- [ ] `WifiManager.MulticastLock` vía platform channel en Android 10+
- [ ] Persistir `playerId` con `shared_preferences` para reconexión tras crash
- [ ] Reproducir `AssetPaths.musicMenu` en Home/Splash/Lobby/Settings (hoy solo `GameScreen`/`GameOverScreen` tienen música vía `AudioService`)

### Bots / modo offline
- [ ] Interfaz `BotStrategy` con implementación básica (aleatoria)
- [ ] Estrategia avanzada de bot (heurística)
- [ ] Partida local contra 1–4 bots sin red

### Modo online
- [ ] Backend de salas (WebSocket server desplegado)
- [ ] Sistema de cuentas / nicknames persistentes
- [ ] Matchmaking por código de sala
- [ ] Ranking global

### Expansiones
- [ ] Imploding Kittens (6 jugadores, cartas nuevas)
- [ ] Streaking Kittens
- [ ] Barking Kittens (2 jugadores cooperativo)

### Publicación
- [ ] Firma y build de release para Android (Google Play)
- [ ] Firma y build de release para iOS (App Store)
- [ ] Assets gráficos originales completos
- [ ] Onboarding / tutorial interactivo

---

## Convención de commits

```
feat(scope):   nueva funcionalidad
fix(scope):    corrección de bug
test(scope):   tests añadidos o corregidos
refactor:      sin cambio de comportamiento externo
chore:         dependencias, configuración
ci:            pipeline y GitHub Actions
docs:          documentación
```

Scopes principales: `core` · `engine` · `features` · `network` · `assets` · `ci`

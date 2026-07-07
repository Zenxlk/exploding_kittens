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

## Fase 2 — UI base y navegación 🔄

- [ ] Rutas completas en `app_router.dart` (lobby, game, game-over, settings)
- [ ] `SplashScreen` — logo animado con Lottie
- [ ] `HomeScreen` — menú principal con botones animados
- [ ] `SettingsScreen` — volumen, nombre de jugador, preferencias
- [ ] Sistema de tema oscuro consolidado
- [ ] Fuente personalizada integrada (`ExplodingFont`)
- [ ] Tests de widgets para pantallas principales

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

## Fase 4 — Pantalla de juego completa ⏳

- [ ] `GameStateProvider` — `StateNotifier<GameState>` conectado al `GameEngine`
- [ ] `GameScreen` — layout adaptativo portrait/landscape
- [ ] `PlayerHandWidget` — fan de cartas con drag & drop
- [ ] `CardWidget` — flip animation, glow en cartas jugables
- [ ] `DeckWidget` — contador de cartas con animación de robo
- [ ] `DiscardPileWidget` — pila de descarte con última carta visible
- [ ] `PlayersHudWidget` — avatares de oponentes con contador de cartas
- [ ] `NopeWindowOverlay` — temporizador visual con botón reactivo
- [ ] `InsertBombOverlay` — selector de posición al usar Defuse
- [ ] `SeeTheFutureOverlay` — visualización de top 3 cartas
- [ ] `FavorTargetOverlay` — selector de objetivo
- [ ] `ExplosionOverlay` — animación Lottie de explosión
- [ ] `GameOverScreen` — resultado, ranking y opción de revancha
- [ ] Integración de `audioplayers` (efectos y música de fondo)
- [ ] Integración de `flutter_animate` en cartas y transiciones
- [ ] Tests de providers y casos de uso

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

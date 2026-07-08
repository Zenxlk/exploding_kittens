# Exploding Kittens — Fan App

> **Proyecto de fans · Sin fines comerciales**
> Este proyecto es una recreación no oficial del juego de cartas *Exploding Kittens*,
> creada con fines educativos y de entretenimiento personal. No está afiliada,
> patrocinada ni respaldada por **Exploding Kittens LLC** ni por **The Oatmeal**.
> Todos los derechos del juego original pertenecen a sus respectivos titulares.
> Ver [`DISCLAIMER.md`](DISCLAIMER.md) para más información.

---

Implementación móvil del juego de cartas *Exploding Kittens* para Android e iOS,
desarrollada en Flutter por **ZenXLK**. Soporta partidas locales por WiFi para
2–5 jugadores y está preparada para multijugador online en el futuro.

## Estado del proyecto

| Fase | Descripción | Estado |
|------|-------------|--------|
| 1 | Motor de juego (reglas oficiales, mazo, turnos) | ✅ Completa |
| 2 | UI base y navegación | ✅ Completa |
| 3 | Lobby y partidas locales por WiFi | ✅ Completa |
| 4 | Pantalla de juego completa con animaciones | ⏳ Pendiente |
| 5 | Red, reconexión y modo online | ⏳ Pendiente |
| 6 | Bots / modo offline | 🗓 Futuro |

## Requisitos

- Flutter `3.44+` / Dart `3.12+`
- Android SDK 21+ / iOS 13+
- Para partidas WiFi: dispositivos en la misma red local

## Instalación y ejecución

```bash
# Clonar el repositorio
git clone https://github.com/Zenxlk/Exploding_Kittens.git
cd Exploding_Kittens

# Instalar dependencias
flutter pub get

# Generar código (freezed / Riverpod)
dart run build_runner build --delete-conflicting-outputs

# Ejecutar en modo debug
flutter run
```

## Tecnologías

- **Flutter + Dart** — UI multiplataforma
- **Riverpod 2** — gestión de estado
- **GoRouter** — navegación declarativa
- **WebSocket** (`web_socket_channel`) — comunicación en red local y futura online
- **UDP broadcast** — descubrimiento de salas en la red local (lobby)
- **Lottie + flutter_animate** — animaciones de cartas
- **audioplayers** — efectos de sonido
- **Hive** — persistencia local

## Documentación

| Archivo | Contenido |
|---------|-----------|
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | Arquitectura técnica y decisiones de diseño |
| [`docs/GAME_RULES.md`](docs/GAME_RULES.md) | Reglas implementadas y pendientes |
| [`docs/VERIFICATION_LOG.md`](docs/VERIFICATION_LOG.md) | Bitácora de verificación manual con capturas, y cómo reproducirla (ej. 2 emuladores en red real) |
| [`ROADMAP.md`](ROADMAP.md) | Trabajo pendiente por fase |
| [`CONTRIBUTING.md`](CONTRIBUTING.md) | Guía de contribución |
| [`CHANGELOG.md`](CHANGELOG.md) | Historial de cambios |
| [`DISCLAIMER.md`](DISCLAIMER.md) | Aviso legal sobre derechos del juego original |

## Contribuir

Ver [`CONTRIBUTING.md`](CONTRIBUTING.md).

## Licencia

Código fuente bajo licencia MIT. Los assets del juego original (arte, nombres,
mecánicas) son propiedad de Exploding Kittens LLC. Ver [`DISCLAIMER.md`](DISCLAIMER.md).

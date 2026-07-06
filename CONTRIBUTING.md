# Contribuir

Gracias por tu interés en colaborar. Estas son las pautas del proyecto.

## Antes de empezar

1. Lee [`DISCLAIMER.md`](DISCLAIMER.md) — es un proyecto de fans, sin fines comerciales.
2. Revisa [`ROADMAP.md`](ROADMAP.md) para entender qué trabajo está planificado.
3. Abre o comenta un issue antes de empezar una tarea grande.

## Flujo de trabajo

```bash
# 1. Fork + clonar
git clone https://github.com/tu-usuario/Exploding_Kittens.git
cd Exploding_Kittens

# 2. Instalar dependencias
flutter pub get
dart run build_runner build --delete-conflicting-outputs

# 3. Crear rama desde main
git checkout -b feat/nombre-descriptivo

# 4. Desarrollar y verificar
flutter analyze
flutter test

# 5. Commit con convención del proyecto
git commit -m "feat(engine): descripción concisa"

# 6. Pull Request usando la plantilla
```

## Convención de commits

```
feat(scope):   nueva funcionalidad
fix(scope):    corrección de bug
test(scope):   tests
refactor:      sin cambio de comportamiento
chore:         dependencias, configuración
ci:            pipeline
docs:          documentación
```

Scopes: `core` · `engine` · `features` · `network` · `assets` · `ci`

## Estándares de código

- Dart 3 — usar `sealed class`, pattern matching y records donde aplique.
- El `game_engine/` es Dart puro: cero imports de Flutter.
- Todo cambio en `game_engine/` debe ir acompañado de tests.
- Ejecutar `dart format .` antes de hacer commit (el CI lo verifica).
- `flutter analyze --fatal-infos` debe pasar sin errores.

## Assets

No contribuyas assets con derechos de autor del juego original.
Solo se aceptan assets de elaboración propia o bajo licencias compatibles
(CC0, CC-BY, MIT). Ver [`DISCLAIMER.md`](DISCLAIMER.md).

## Pull Requests

Usa la plantilla de PR. Asegúrate de marcar:
- La capa afectada (`core`, `engine`, `features`, `network`…)
- Que `flutter test` y `flutter analyze` pasan
- Tests añadidos o actualizados si corresponde

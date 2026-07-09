# Bitácora de verificación manual

Evidencia general de que las features funcionan corriendo de verdad en un
emulador/dispositivo (no solo en tests automatizados), y cómo reproducir esa
verificación. Complementa el `CHANGELOG.md` (que documenta el código) con
capturas y el procedimiento — no es un registro de una máquina o sesión en
particular, sino algo que cualquiera debería poder repetir.

---

## Cómo reproducir: 2 emuladores en red real (host + cliente)

No hace falta ningún truco de red manual: dos emuladores modernos de Android
Studio comparten una red WiFi virtualizada (`netsimd`) y se descubren solos
por el UDP broadcast real de `MdnsAdvertiser`/`MdnsDiscoverer`. Se probó primero
el truco `adb forward tcp:8765 tcp:8765` + IP manual `10.0.2.2` y falló
("Connection closed before full header was received") — no hacía falta,
era una complicación innecesaria.

```bash
# 1. Ver qué dispositivos/emuladores hay disponibles
flutter devices

# 2. Lanzar la app en cada uno, uno detrás de otro (NO en paralelo, para no
#    pisar la caché de build compartida)
flutter run -d <serial-emulador-1> --no-hot   # será el host
flutter run -d <serial-emulador-2> --no-hot   # se unirá a la sala

# 3. Emulador 1 → Home → "Crear sala"
# 4. Emulador 2 → Home → "Unirse a sala" → aparece sola en la lista
#    (descubrimiento UDP real entre emuladores, sin IP manual)
# 5. Emulador 2 → tocar "Ready"
# 6. Emulador 1 (host) → "Start Game" (se habilita solo con 2+ listos)
```

Capturar pantalla de cualquiera de los dos en cualquier momento:

```bash
ADB=/home/user/Android/Sdk/platform-tools/adb
$ADB -s <serial> exec-out screencap -p > captura.png
```

Si un `flutter run` anterior quedó colgado o un dispositivo tiene la app en un
estado raro, limpiar antes de repetir:

```bash
pkill -f "flutter_tools.snapshot run"
adb -s <serial> forward --remove-all
adb -s <serial> shell am force-stop com.zenxlk.exploding_kittens
```

---

## Fase 4, Paso 3 — GameScreen conectado (verificado 2026-07-07)

Verificado con dos emuladores Android (uno como host, otro como cliente) en
red real, sin mocks. Ver comandos arriba para reproducir.

1. Home arranca sin errores.
   ![Home](screenshots/fase4/01_home.png)
2. Lobby del host recién creado, esperando jugadores (1/5).
   ![Lobby host esperando](screenshots/fase4/02_lobby_host_waiting.png)
3. El segundo jugador se une por descubrimiento UDP real; ambos "Ready" (2/5).
   ![Lobby con 2 jugadores listos](screenshots/fase4/03_lobby_joined_2players.png)
4. El host arranca el `GameEngine` real: HUD con ambos jugadores, mazo (35
   cartas), descarte vacío, mano propia con los placeholders de `CardVisuals`
   (colores/iconos por tipo de carta).
   ![GameScreen del host](screenshots/fase4/04_gamescreen_host.png)
5. El jugador no-host ve el placeholder honesto de espera — la sincronización
   real por red es Fase 5, todavía no implementada, y no se simula.
   ![GameScreen del no-host](screenshots/fase4/05_gamescreen_nonhost_waiting.png)
6. Tras tocar el mazo: robó de verdad (mazo 35→34, mano 8→9), el turno avanzó
   y el HUD resalta al siguiente jugador.
   ![Tras robar una carta](screenshots/fase4/06_gamescreen_after_draw.png)

**Confirmado funcionando de punta a punta:** crear/unir sala por red real,
arranque del engine, render de la mesa con datos reales, robar carta,
selección de carta con aviso de "se juega en el próximo paso" para las que
aún no tienen overlay (Favor/pares-tríos/Nope/Defuse), avance de turno.

**Límite conocido y esperado, no un bug:** en cuanto el turno pasa al jugador
no-host, la partida queda parada ahí porque ese dispositivo todavía no puede
actuar — es exactamente el hueco de Fase 5 (sincronización por red), no una
falla de esta sesión de trabajo.

---

## Fase 4 — NopeWindowOverlay (pendiente de verificación manual)

No se corrió en emulador en esta sesión (ver decisión en memoria: las pruebas
manuales en emulador/dispositivo las hace el usuario). Pasos para reproducir
cuando se quiera verificar:

1. Como host, dar el turno a un jugador que tenga en mano `Attack`, `Skip`,
   `Shuffle` o `Favor`/par de gatos (cualquier carta que abra una ventana de
   Nope al jugarse) y jugarla.
2. Confirmar que aparece el overlay "Ventana de Nope" con la barra de
   progreso corriendo (duración `GameConstants.nopeWindowMs`, 3000 ms).
3. Si el jugador local (mismo dispositivo, host) tiene un Nope en mano, el
   botón "¡Nope!" debe estar habilitado; tocarlo debe descartar el Nope y
   reiniciar la barra desde el principio (nueva vuelta de la cadena).
4. Si no hay Nope en mano, el botón debe verse deshabilitado.
5. Dejar que expire el temporizador sin jugar Nope: la ventana debe cerrarse
   sola y aplicar el efecto original de la carta.

Limitación conocida: como hoy solo el host corre el `GameEngine` real (Fase 5
pendiente), probar que *otro* jugador cancele la carta requiere que ese mismo
dispositivo host controle temporalmente la mano de ambos jugadores o esperar
a la sincronización por red — no es un caso cubierto todavía por este flujo
manual de un solo dispositivo.

---

## Fase 4 — InsertBombOverlay (pendiente de verificación manual)

Tampoco se corrió en emulador en esta sesión, mismo motivo que arriba. Pasos:

1. Como host, robar cartas hasta sacar una Exploding Kitten teniendo un
   Defuse en mano (o forzarlo colocando el mazo a mano si se quiere apurar
   la prueba).
2. Confirmar que aparece el overlay "¿Dónde escondes la bomba?" con un
   slider entre "Arriba del todo" y "Abajo del todo".
3. Mover el slider y confirmar con "Esconder bomba": el mazo debe quedar con
   la misma cantidad de cartas de antes de robar (la bomba se reinsertó, no
   desapareció ni se duplicó) y el turno debe avanzar al siguiente jugador.
4. Repetir eligiendo la posición 0 (arriba del todo) y volver a robar de
   inmediato en el siguiente turno propio: debe salir la misma bomba otra
   vez.

Limitación conocida: igual que con `NopeWindowOverlay`, verificar el punto de
vista del jugador no-host (que solo debería ver "Esperando a que \<jugador\>
esconda la bomba…") requiere Fase 5 o controlar ambas manos desde el host.

---

## Fase 4 — ExplosionOverlay (pendiente de verificación manual)

Tampoco se corrió en emulador en esta sesión, mismo motivo que arriba. Pasos:

1. Como host, robar cartas hasta sacar una Exploding Kitten **sin** tener
   Defuse en mano.
2. Confirmar que aparece el overlay "¡BOOM!" con el nombre del jugador
   eliminado, y que se cierra solo (sin tocar nada) después de ~1.6s.
3. Confirmar que el HUD (`PlayersHudWidget`) refleja al jugador como
   eliminado (atenuado) una vez cerrado el overlay, y que el turno pasó al
   siguiente jugador vivo.
4. Si era el único jugador que quedaba vivo aparte del ganador, confirmar
   que tras el overlay se navega a `GameOverScreen`.

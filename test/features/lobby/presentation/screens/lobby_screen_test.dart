import 'package:exploding_kittens/features/lobby/domain/models/lobby_player.dart';
import 'package:exploding_kittens/features/lobby/domain/models/lobby_room.dart';
import 'package:exploding_kittens/features/lobby/presentation/providers/lobby_providers.dart';
import 'package:exploding_kittens/features/lobby/presentation/screens/lobby_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingLobbyNotifier extends LobbyNotifier {
  final calls = <String>[];
  LobbyMode? lastMode;
  String? lastTarget;

  @override
  LobbyState build() => const LobbyIdle();

  @override
  Future<void> createRoom({LobbyMode mode = LobbyMode.lan}) async {
    calls.add('createRoom');
    lastMode = mode;
  }

  @override
  void startDiscovery() {
    calls.add('startDiscovery');
  }

  @override
  Future<void> joinRoom(String target, {LobbyMode mode = LobbyMode.lan}) async {
    calls.add('joinRoom');
    lastTarget = target;
    lastMode = mode;
  }

  @override
  Future<void> leaveRoom() async {
    calls.add('leaveRoom');
  }
}

// A diferencia de _RecordingLobbyNotifier (no-op, solo registra que se
// llamó), esta sí transiciona a LobbyInRoom de verdad al crear la sala —
// hace falta que _InRoomView llegue a montarse para poder probar el
// SnackBar de errorStream (issue #39).
class _InRoomAfterCreateNotifier extends LobbyNotifier {
  _InRoomAfterCreateNotifier(this._room);
  final LobbyRoom _room;

  @override
  LobbyState build() => const LobbyIdle();

  @override
  Future<void> createRoom({LobbyMode mode = LobbyMode.lan}) async {
    state = LobbyInRoom(room: _room, localPlayerId: _room.hostId);
  }

  // Simula lo que LobbyNotifier._subscribeToRoom hace de verdad al recibir
  // un WsErrorMessage por el errorStream del repositorio.
  void emitError(String message) {
    final current = state;
    if (current is LobbyInRoom) {
      state = LobbyInRoom(
        room: current.room,
        localPlayerId: current.localPlayerId,
        error: message,
      );
    }
  }
}

Widget _wrap(Widget child, LobbyNotifier notifier) => ProviderScope(
      overrides: [lobbyProvider.overrideWith(() => notifier)],
      child: MaterialApp(home: child),
    );

void main() {
  tearDown(dotenv.clean);

  group('LobbyScreen — selección de modo (Fase 7)', () {
    testWidgets(
      'host: tocar "Local WiFi" crea la sala en modo LAN (default)',
      (tester) async {
        final notifier = _RecordingLobbyNotifier();
        await tester.pumpWidget(
          _wrap(const LobbyScreen(isHost: true), notifier),
        );

        await tester.tap(find.text('Local WiFi'));
        await tester.pump();

        expect(notifier.calls, ['createRoom']);
        expect(notifier.lastMode, LobbyMode.lan);
      },
    );

    testWidgets(
      'host: el botón Online está deshabilitado sin backend configurado',
      (tester) async {
        final notifier = _RecordingLobbyNotifier();
        await tester.pumpWidget(
          _wrap(const LobbyScreen(isHost: true), notifier),
        );

        final button = tester.widget<OutlinedButton>(
          find.ancestor(
            of: find.text('Online (not available in this build)'),
            matching: find.byType(OutlinedButton),
          ),
        );
        expect(button.onPressed, isNull);
        expect(notifier.calls, isEmpty);
      },
    );

    testWidgets(
      'host: tocar "Online" con backend configurado crea la sala en modo '
      'online',
      (tester) async {
        dotenv.loadFromString(
          envString: 'ONLINE_SERVER_URL=https://example.run.app',
        );
        final notifier = _RecordingLobbyNotifier();
        await tester.pumpWidget(
          _wrap(const LobbyScreen(isHost: true), notifier),
        );

        await tester.tap(find.text('Online'));
        await tester.pump();

        expect(notifier.calls, ['createRoom']);
        expect(notifier.lastMode, LobbyMode.online);
      },
    );

    testWidgets(
      'unirse: tocar "Local WiFi" arranca el descubrimiento mDNS',
      (tester) async {
        final notifier = _RecordingLobbyNotifier();
        await tester.pumpWidget(
          _wrap(const LobbyScreen(isHost: false), notifier),
        );

        await tester.tap(find.text('Local WiFi'));
        await tester.pump();

        expect(notifier.calls, ['startDiscovery']);
      },
    );

    testWidgets(
      'unirse: tocar "Online" pide un código de sala y lo usa para unirse',
      (tester) async {
        dotenv.loadFromString(
          envString: 'ONLINE_SERVER_URL=https://example.run.app',
        );
        final notifier = _RecordingLobbyNotifier();
        await tester.pumpWidget(
          _wrap(const LobbyScreen(isHost: false), notifier),
        );

        await tester.tap(find.text('Online'));
        await tester.pumpAndSettle();

        expect(find.text('Room code'), findsOneWidget);
        expect(notifier.calls, isEmpty);

        await tester.enterText(find.byType(TextField), 'ab12cd');
        await tester.tap(find.text('Connect'));
        await tester.pump();

        expect(notifier.calls, ['joinRoom']);
        expect(notifier.lastTarget, 'AB12CD');
        expect(notifier.lastMode, LobbyMode.online);
      },
    );

    testWidgets(
      'unirse: cancelar el diálogo de código vuelve al selector de modo',
      (tester) async {
        dotenv.loadFromString(
          envString: 'ONLINE_SERVER_URL=https://example.run.app',
        );
        final notifier = _RecordingLobbyNotifier();
        await tester.pumpWidget(
          _wrap(const LobbyScreen(isHost: false), notifier),
        );

        await tester.tap(find.text('Online'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        expect(find.text('Local WiFi'), findsOneWidget);
        expect(notifier.calls, isEmpty);
      },
    );
  });

  group('LobbyScreen — errores del servidor ya en la sala (issue #39)', () {
    testWidgets(
      'un WsErrorMessage llegando ya en la sala muestra un SnackBar en vez '
      'de perderse en silencio',
      (tester) async {
        const room = LobbyRoom(
          id: 'room-1',
          hostId: 'host',
          players: [
            LobbyPlayer(id: 'host', name: 'Ana', isHost: true, isReady: true),
          ],
        );
        final notifier = _InRoomAfterCreateNotifier(room);
        await tester.pumpWidget(
          _wrap(const LobbyScreen(isHost: true), notifier),
        );

        await tester.tap(find.text('Local WiFi'));
        // pumpAndSettle, no pump: _PlayerTile usa flutter_animate (fadeIn/
        // slideX), que deja un Timer corriendo si no se lo deja terminar.
        await tester.pumpAndSettle();

        // "Ana (you)" — el único jugador es el host local. Confirma que ya
        // se llegó a _InRoomView antes de probar el SnackBar.
        expect(find.textContaining('Ana'), findsOneWidget);
        expect(find.text('Faltan jugadores listos'), findsNothing);

        notifier.emitError('Faltan jugadores listos');
        await tester.pump();

        expect(find.text('Faltan jugadores listos'), findsOneWidget);
      },
    );
  });
}

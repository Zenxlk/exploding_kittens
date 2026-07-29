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
}

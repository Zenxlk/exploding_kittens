import 'package:exploding_kittens/core/audio/audio_service.dart';
import 'package:exploding_kittens/core/audio/i_audio_service.dart';
import 'package:exploding_kittens/core/router/route_names.dart';
import 'package:exploding_kittens/features/game/presentation/providers/game_providers.dart';
import 'package:exploding_kittens/features/game/presentation/screens/game_over_screen.dart';
import 'package:exploding_kittens/features/lobby/domain/models/lobby_player.dart';
import 'package:exploding_kittens/features/lobby/domain/models/lobby_room.dart';
import 'package:exploding_kittens/features/lobby/presentation/providers/lobby_providers.dart';
import 'package:exploding_kittens/game_engine/models/game/game_result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeLobbyNotifier extends LobbyNotifier {
  _FakeLobbyNotifier(this._initial, {bool isOnline = false})
      : _isOnline = isOnline;
  final LobbyState _initial;
  final bool _isOnline;
  bool leaveRoomCalled = false;

  @override
  LobbyState build() => _initial;

  @override
  bool get isOnline => _isOnline;

  // No se delega al LobbyNotifier real: solo interesa comprobar que la
  // pantalla lo llama antes de navegar (el fix del "servidor fantasma" —
  // ver docs/VERIFICATION_LOG.md), no ejercitar el repositorio real.
  @override
  Future<void> leaveRoom() async {
    leaveRoomCalled = true;
  }
}

class _FakeAudioService implements IAudioService {
  @override
  Future<void> playEffect(String assetPath, {required double volume}) async {}

  @override
  Future<void> playMusic(
    String assetPath, {
    required bool enabled,
    required double volume,
  }) async {}

  @override
  Future<void> stopMusic() async {}

  @override
  Future<void> pauseMusic() async {}

  @override
  Future<void> resumeMusic() async {}

  @override
  Future<void> dispose() async {}
}

class _FakeGameNotifier extends GameNotifier {
  _FakeGameNotifier(this._initial);
  final GameSessionState _initial;

  @override
  GameSessionState build() => _initial;
}

class _FakeRemoteGameNotifier extends RemoteGameNotifier {
  _FakeRemoteGameNotifier(this._initial);
  final GameSessionState _initial;

  @override
  GameSessionState build() => _initial;
}

const _room = LobbyRoom(
  id: 'room-1',
  hostId: 'host',
  players: [
    LobbyPlayer(id: 'host', name: 'Ana', isHost: true, isReady: true),
    LobbyPlayer(id: 'p2', name: 'Beto', isReady: true),
    LobbyPlayer(id: 'p3', name: 'Caro', isReady: true),
  ],
);

const _result = GameResult(
  winnerId: 'host',
  winnerName: 'Ana',
  totalTurns: 12,
  eliminationOrder: ['p3', 'p2'],
);

// GameOverScreen navega con go_router's context.go (incluido el fix del
// "servidor fantasma": Volver al menú), así que necesita un GoRouter real
// en el árbol, no solo un Navigator.
Widget _wrap({
  required GameSessionState gameState,
  required LobbyState lobbyState,
  required _FakeLobbyNotifier lobbyNotifier,
}) {
  final router = GoRouter(
    initialLocation: RouteNames.gameOver,
    routes: [
      GoRoute(
        path: RouteNames.gameOver,
        builder: (_, __) => const GameOverScreen(),
      ),
      GoRoute(
        path: RouteNames.home,
        builder: (_, __) => const Scaffold(body: Text('home-screen')),
      ),
      GoRoute(
        path: RouteNames.game,
        builder: (_, __) => const Scaffold(body: Text('game-screen')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      lobbyProvider.overrideWith(() => lobbyNotifier),
      gameProvider.overrideWith(() => _FakeGameNotifier(gameState)),
      // El mismo estado en los dos: cada test decide con `localPlayerId` si
      // es host o no, y GameOverScreen ya elige el provider correcto según
      // eso — aquí no hace falta un estado distinto por provider.
      remoteGameProvider.overrideWith(() => _FakeRemoteGameNotifier(gameState)),
      audioServiceProvider.overrideWithValue(_FakeAudioService()),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('GameOverScreen', () {
    testWidgets('sin resultado de partida muestra el mensaje por defecto', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          gameState: const GameIdle(),
          lobbyState: const LobbyIdle(),
          lobbyNotifier: _FakeLobbyNotifier(const LobbyIdle()),
        ),
      );

      expect(
        find.text('No hay ningún resultado de partida'),
        findsOneWidget,
      );
    });

    testWidgets(
      'sin resultado de partida, "Volver al menú" deja la sala antes de '
      'navegar',
      (tester) async {
        final lobbyNotifier = _FakeLobbyNotifier(const LobbyIdle());
        await tester.pumpWidget(
          _wrap(
            gameState: const GameIdle(),
            lobbyState: const LobbyIdle(),
            lobbyNotifier: lobbyNotifier,
          ),
        );

        await tester.tap(find.text('Volver al menú'));
        await tester.pumpAndSettle();

        expect(lobbyNotifier.leaveRoomCalled, isTrue);
        expect(find.text('home-screen'), findsOneWidget);
      },
    );

    testWidgets(
      'el host ve el ranking en orden real de eliminación y el botón de '
      'revancha',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            gameState: const GameFinished(_result),
            lobbyState: const LobbyInRoom(room: _room, localPlayerId: 'host'),
            lobbyNotifier: _FakeLobbyNotifier(
              const LobbyInRoom(room: _room, localPlayerId: 'host'),
            ),
          ),
        );

        // Deja que termine la entrada escalonada (flutter_animate) antes de
        // que el test termine, para no dejar un Timer/AnimationController
        // pendiente.
        await tester.pumpAndSettle();

        expect(find.textContaining('Ana ganó'), findsOneWidget);
        // Ganador primero, luego el orden inverso de eliminación (el
        // último en explotar, Beto, queda 2º; Caro, la primera, última).
        expect(find.text('1. Ana'), findsOneWidget);
        expect(find.text('2. Beto'), findsOneWidget);
        expect(find.text('3. Caro'), findsOneWidget);
        expect(find.widgetWithText(FilledButton, 'Revancha'), findsOneWidget);
      },
    );

    testWidgets(
      'el host en modo online ve el aviso de "no disponible" en vez del '
      'botón de revancha (cards_game_service#10)',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            gameState: const GameFinished(_result),
            lobbyState: const LobbyInRoom(room: _room, localPlayerId: 'host'),
            lobbyNotifier: _FakeLobbyNotifier(
              const LobbyInRoom(room: _room, localPlayerId: 'host'),
              isOnline: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Revancha'), findsNothing);
        expect(
          find.textContaining('Revancha no disponible todavía en modo online'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'un jugador no-host no ve el botón de revancha',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            gameState: const GameFinished(_result),
            lobbyState: const LobbyInRoom(room: _room, localPlayerId: 'p2'),
            lobbyNotifier: _FakeLobbyNotifier(
              const LobbyInRoom(room: _room, localPlayerId: 'p2'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Revancha'), findsNothing);
        expect(
          find.textContaining('Esperando a que el host inicie'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'con resultado de partida, "Volver al menú" deja la sala antes de '
      'navegar',
      (tester) async {
        final lobbyState = const LobbyInRoom(
          room: _room,
          localPlayerId: 'p2',
        );
        final lobbyNotifier = _FakeLobbyNotifier(lobbyState);
        await tester.pumpWidget(
          _wrap(
            gameState: const GameFinished(_result),
            lobbyState: lobbyState,
            lobbyNotifier: lobbyNotifier,
          ),
        );

        await tester.tap(find.text('Volver al menú'));
        await tester.pumpAndSettle();

        expect(lobbyNotifier.leaveRoomCalled, isTrue);
        expect(find.text('home-screen'), findsOneWidget);
      },
    );

    testWidgets(
      'la entrada escalonada anima sin lanzar y termina con el contenido '
      'correcto',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            gameState: const GameFinished(_result),
            lobbyState: const LobbyInRoom(room: _room, localPlayerId: 'host'),
            lobbyNotifier: _FakeLobbyNotifier(
              const LobbyInRoom(room: _room, localPlayerId: 'host'),
            ),
          ),
        );
        // Pump a mitad de la animación (antes de que terminen los delays
        // escalonados de cada fila) para confirmar que no lanza.
        await tester.pump(const Duration(milliseconds: 150));
        await tester.pumpAndSettle();

        expect(find.textContaining('Ana ganó'), findsOneWidget);
        expect(find.text('1. Ana'), findsOneWidget);
        expect(find.text('2. Beto'), findsOneWidget);
        expect(find.text('3. Caro'), findsOneWidget);
        expect(find.widgetWithText(FilledButton, 'Revancha'), findsOneWidget);
      },
    );
  });
}

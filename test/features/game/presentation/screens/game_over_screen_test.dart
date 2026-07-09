import 'package:exploding_kittens/core/audio/audio_service.dart';
import 'package:exploding_kittens/core/audio/i_audio_service.dart';
import 'package:exploding_kittens/features/game/presentation/providers/game_providers.dart';
import 'package:exploding_kittens/features/game/presentation/screens/game_over_screen.dart';
import 'package:exploding_kittens/features/lobby/domain/models/lobby_player.dart';
import 'package:exploding_kittens/features/lobby/domain/models/lobby_room.dart';
import 'package:exploding_kittens/features/lobby/presentation/providers/lobby_providers.dart';
import 'package:exploding_kittens/game_engine/models/game/game_result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeLobbyNotifier extends LobbyNotifier {
  _FakeLobbyNotifier(this._initial);
  final LobbyState _initial;

  @override
  LobbyState build() => _initial;
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
  Future<void> dispose() async {}
}

class _FakeGameNotifier extends GameNotifier {
  _FakeGameNotifier(this._initial);
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

Widget _wrap({
  required GameSessionState gameState,
  required LobbyState lobbyState,
}) {
  return ProviderScope(
    overrides: [
      lobbyProvider.overrideWith(() => _FakeLobbyNotifier(lobbyState)),
      gameProvider.overrideWith(() => _FakeGameNotifier(gameState)),
      audioServiceProvider.overrideWithValue(_FakeAudioService()),
    ],
    child: const MaterialApp(home: GameOverScreen()),
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
        _wrap(gameState: const GameIdle(), lobbyState: const LobbyIdle()),
      );

      expect(
        find.text('No hay ningún resultado de partida'),
        findsOneWidget,
      );
    });

    testWidgets(
      'el host ve el ranking en orden real de eliminación y el botón de '
      'revancha',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            gameState: const GameFinished(_result),
            lobbyState: const LobbyInRoom(room: _room, localPlayerId: 'host'),
          ),
        );

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
      'un jugador no-host no ve el botón de revancha',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            gameState: const GameFinished(_result),
            lobbyState: const LobbyInRoom(room: _room, localPlayerId: 'p2'),
          ),
        );

        expect(find.text('Revancha'), findsNothing);
        expect(
          find.textContaining('Esperando a que el host inicie'),
          findsOneWidget,
        );
      },
    );
  });
}

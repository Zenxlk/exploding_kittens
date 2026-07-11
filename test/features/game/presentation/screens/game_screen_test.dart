import 'package:exploding_kittens/core/audio/audio_service.dart';
import 'package:exploding_kittens/core/audio/i_audio_service.dart';
import 'package:exploding_kittens/features/game/domain/i_game_gateway.dart';
import 'package:exploding_kittens/features/game/presentation/providers/game_providers.dart';
import 'package:exploding_kittens/features/game/presentation/screens/game_screen.dart';
import 'package:exploding_kittens/features/lobby/domain/models/lobby_player.dart';
import 'package:exploding_kittens/features/lobby/domain/models/lobby_room.dart';
import 'package:exploding_kittens/features/lobby/presentation/providers/lobby_providers.dart';
import 'package:exploding_kittens/game_engine/events/game_event.dart';
import 'package:exploding_kittens/game_engine/models/deck/deck_model.dart';
import 'package:exploding_kittens/game_engine/models/game/game_config.dart';
import 'package:exploding_kittens/game_engine/models/game/game_state.dart';
import 'package:exploding_kittens/game_engine/models/player/player_model.dart';
import 'package:exploding_kittens/game_engine/models/turn/turn_action.dart';
import 'package:exploding_kittens/game_engine/models/turn/turn_model.dart';
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

class _FakeRemoteGameNotifier extends RemoteGameNotifier {
  _FakeRemoteGameNotifier(this._initial);
  final GameSessionState _initial;

  @override
  GameSessionState build() => _initial;
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

class _FakeGameGateway implements IGameGateway {
  GameState Function(List<PlayerModel>, GameConfig)? onStart;

  @override
  Stream<GameEvent> get events => const Stream.empty();

  @override
  GameState startGame(List<PlayerModel> players, GameConfig config) =>
      onStart!(players, config);

  @override
  GameState apply(TurnAction action) => throw UnimplementedError();

  @override
  GameState resolveNopeWindow() => throw UnimplementedError();

  @override
  GameState eliminatePlayerForDisconnect(String playerId) =>
      throw UnimplementedError();

  @override
  GameState markPlayerDisconnected(String playerId) =>
      throw UnimplementedError();

  @override
  GameState markPlayerReconnected(String playerId) =>
      throw UnimplementedError();
}

const _room = LobbyRoom(
  id: 'room-1',
  hostId: 'host',
  players: [
    LobbyPlayer(id: 'host', name: 'Ana', isHost: true, isReady: true),
    LobbyPlayer(id: 'p2', name: 'Beto', isReady: true),
  ],
);

Widget _wrap({
  required LobbyState lobbyState,
  required _FakeGameGateway gateway,
  RemoteGameNotifier Function()? remoteNotifierFactory,
}) {
  return ProviderScope(
    overrides: [
      lobbyProvider.overrideWith(() => _FakeLobbyNotifier(lobbyState)),
      gameProvider.overrideWith(() => GameNotifier(gateway: gateway)),
      audioServiceProvider.overrideWithValue(_FakeAudioService()),
      if (remoteNotifierFactory != null)
        remoteGameProvider.overrideWith(remoteNotifierFactory),
    ],
    child: const MaterialApp(home: GameScreen()),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('GameScreen', () {
    testWidgets('el host inicia la partida y ve su propia mano', (
      tester,
    ) async {
      final gateway = _FakeGameGateway();
      gateway.onStart = (players, config) => GameState(
            id: 'g1',
            config: config,
            players: players,
            deck: const DeckModel(drawPile: [], discardPile: []),
            turn: TurnModel(currentPlayerId: 'host', phase: TurnPhase.playing),
            phase: GamePhase.playing,
          );

      await tester.pumpWidget(
        _wrap(
          lobbyState: const LobbyInRoom(room: _room, localPlayerId: 'host'),
          gateway: gateway,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ana'), findsOneWidget);
      expect(find.text('Beto'), findsOneWidget);
    });

    testWidgets(
      'un jugador no-host sin GameState aún ve el mensaje de reparto',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            lobbyState: const LobbyInRoom(room: _room, localPlayerId: 'p2'),
            gateway: _FakeGameGateway(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Repartiendo cartas…'), findsOneWidget);
      },
    );

    testWidgets(
      'un jugador no-host con partida en curso ve la mesa vía '
      'RemoteGameNotifier',
      (tester) async {
        final state = GameState(
          id: 'g1',
          config: const GameConfig(playerCount: 2),
          players: const [
            PlayerModel(id: 'host', name: 'Ana', hand: []),
            PlayerModel(id: 'p2', name: 'Beto', hand: []),
          ],
          deck: const DeckModel(drawPile: [], discardPile: []),
          turn: TurnModel(currentPlayerId: 'host', phase: TurnPhase.playing),
          phase: GamePhase.playing,
        );

        await tester.pumpWidget(
          _wrap(
            lobbyState: const LobbyInRoom(room: _room, localPlayerId: 'p2'),
            gateway: _FakeGameGateway(),
            remoteNotifierFactory: () =>
                _FakeRemoteGameNotifier(GameRunning(state: state)),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Ana'), findsOneWidget);
        expect(find.text('Beto'), findsOneWidget);
      },
    );

    testWidgets('sin sala activa muestra el mensaje por defecto', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(lobbyState: const LobbyIdle(), gateway: _FakeGameGateway()),
      );
      await tester.pumpAndSettle();

      expect(find.text('No hay ninguna partida en curso'), findsOneWidget);
    });
  });
}

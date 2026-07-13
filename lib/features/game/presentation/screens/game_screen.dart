import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:exploding_kittens/core/audio/audio_service.dart';
import 'package:exploding_kittens/core/audio/i_audio_service.dart';
import 'package:exploding_kittens/core/constants/asset_paths.dart';
import 'package:exploding_kittens/core/router/route_names.dart';
import 'package:exploding_kittens/core/theme/app_colors.dart';
import 'package:exploding_kittens/core/theme/app_text_styles.dart';
import 'package:exploding_kittens/features/game/presentation/audio/game_sound_controller.dart';
import 'package:exploding_kittens/features/game/presentation/providers/card_asset_provider.dart';
import 'package:exploding_kittens/features/game/presentation/providers/game_network_bridge_provider.dart';
import 'package:exploding_kittens/features/game/presentation/providers/game_providers.dart';
import 'package:exploding_kittens/features/game/presentation/widgets/game_table_view.dart';
import 'package:exploding_kittens/features/lobby/presentation/providers/lobby_providers.dart';
import 'package:exploding_kittens/features/settings/domain/app_settings.dart';
import 'package:exploding_kittens/features/settings/presentation/providers/settings_providers.dart';
import 'package:exploding_kittens/game_engine/models/game/game_config.dart';
import 'package:exploding_kittens/game_engine/models/player/player_model.dart';

/// Cada dispositivo conectado a la sala es dueño de un único jugador: el
/// host corre el motor real (vía `LocalGameGateway`/`GameNotifier`) y lo
/// retransmite por red (`gameNetworkBridgeProvider`); los demás reflejan lo
/// que llega por WebSocket vía `RemoteGameNotifier` — mismo `GameTableView`
/// para ambos, ninguno de los dos widgets de mesa distingue de dónde sale
/// el `GameState`.
class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  // Se guardan como campos (no releídos vía `ref.read` en dispose): Riverpod
  // no permite leer providers en dispose(), el widget ya está desmontado.
  late final GameSoundController _soundController;
  late final IAudioService _audioService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startIfNeeded());
    _audioService = ref.read(audioServiceProvider);
    _soundController = GameSoundController(
      events: _isHost()
          ? ref.read(gameProvider.notifier).events
          : ref.read(remoteGameProvider.notifier).events,
      audioService: _audioService,
      settings: () => ref.read(settingsProvider).value ?? const AppSettings(),
    );
    _syncMusic();
  }

  // Antes de que haya sala (lobbyState no es LobbyInRoom) no importa cuál se
  // elija: build() ya muestra el mensaje de "no hay partida" en ese caso.
  bool _isHost() {
    final lobbyState = ref.read(lobbyProvider);
    return lobbyState is! LobbyInRoom || lobbyState.isHost;
  }

  void _syncMusic() {
    final settings = ref.read(settingsProvider).value ?? const AppSettings();
    _audioService.playMusic(
      AssetPaths.musicIngame,
      enabled: settings.musicEnabled,
      volume: settings.volume,
    );
  }

  @override
  void dispose() {
    _soundController.dispose();
    _audioService.stopMusic();
    super.dispose();
  }

  void _startIfNeeded() {
    final lobbyState = ref.read(lobbyProvider);
    if (lobbyState is! LobbyInRoom) return;

    if (!lobbyState.isHost) {
      final client = ref.read(lobbyProvider.notifier).wsClient;
      if (client != null) {
        ref
            .read(remoteGameProvider.notifier)
            .listenTo(client.messages, client.send);
      }
      return;
    }

    if (ref.read(gameProvider) is! GameIdle) return;

    // Activa el puente host↔red antes de arrancar la partida, para no
    // perderse el primer GameState (el reparto inicial).
    ref.read(gameNetworkBridgeProvider);

    final players = lobbyState.room.players
        .map((p) => PlayerModel(id: p.id, name: p.name, hand: const []))
        .toList();

    ref
        .read(gameProvider.notifier)
        .startLocalGame(players, GameConfig(playerCount: players.length));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<GameSessionState>(gameProvider, (_, next) {
      if (next is GameFinished) context.go(RouteNames.gameOver);
    });
    ref.listen<GameSessionState>(remoteGameProvider, (_, next) {
      if (next is GameFinished) context.go(RouteNames.gameOver);
    });
    ref.listen(settingsProvider, (_, __) => _syncMusic());

    final lobbyState = ref.watch(lobbyProvider);
    final resolver = ref.watch(cardAssetResolverProvider).value;

    if (lobbyState is! LobbyInRoom) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: _CenteredMessage('No hay ninguna partida en curso'),
      );
    }

    final isHost = lobbyState.isHost;
    // Mantiene vivo el puente host↔red mientras esta pantalla esté montada
    // (ya se activó en _startIfNeeded, pero un Provider sin watchers activos
    // podría no sobrevivir a un rebuild en algún escenario de test/hot reload).
    if (isHost) ref.watch(gameNetworkBridgeProvider);

    final sessionState =
        isHost ? ref.watch(gameProvider) : ref.watch(remoteGameProvider);
    final localPlayerId = lobbyState.localPlayerId;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: switch (sessionState) {
        GameRunning(:final state) => GameTableView(
            gameState: state,
            localPlayerId: localPlayerId,
            onDraw: () => isHost
                ? ref.read(gameProvider.notifier).drawCard(localPlayerId)
                : ref.read(remoteGameProvider.notifier).drawCard(localPlayerId),
            onPlaySimpleCard: (card) => isHost
                ? ref.read(gameProvider.notifier).playCard(localPlayerId, card)
                : ref
                    .read(remoteGameProvider.notifier)
                    .playCard(localPlayerId, card),
            onPlayFavor: (card, targetId) => isHost
                ? ref
                    .read(gameProvider.notifier)
                    .playFavor(localPlayerId, card, targetId)
                : ref
                    .read(remoteGameProvider.notifier)
                    .playFavor(localPlayerId, card, targetId),
            onPlayCatPair: (cards, targetId) => isHost
                ? ref
                    .read(gameProvider.notifier)
                    .playCatPair(localPlayerId, cards, targetId)
                : ref
                    .read(remoteGameProvider.notifier)
                    .playCatPair(localPlayerId, cards, targetId),
            onPlayNope: (card) => isHost
                ? ref.read(gameProvider.notifier).playNope(localPlayerId, card)
                : ref
                    .read(remoteGameProvider.notifier)
                    .playNope(localPlayerId, card),
            onDefuseBomb: (card, position) => isHost
                ? ref
                    .read(gameProvider.notifier)
                    .defuse(localPlayerId, card, position)
                : ref
                    .read(remoteGameProvider.notifier)
                    .defuse(localPlayerId, card, position),
            onChooseCard: (cardId) => isHost
                ? ref
                    .read(gameProvider.notifier)
                    .chooseCard(localPlayerId, cardId)
                : ref
                    .read(remoteGameProvider.notifier)
                    .chooseCard(localPlayerId, cardId),
            assetPathFor: resolver?.faceAssetFor,
            cardBackAssetPath: resolver?.cardBackAsset(),
          ),
        _ => const _CenteredMessage('Repartiendo cartas…'),
      },
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          style: AppTextStyles.body,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

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
import 'package:exploding_kittens/features/game/presentation/providers/game_providers.dart';
import 'package:exploding_kittens/features/game/presentation/widgets/game_table_view.dart';
import 'package:exploding_kittens/features/lobby/presentation/providers/lobby_providers.dart';
import 'package:exploding_kittens/features/settings/domain/app_settings.dart';
import 'package:exploding_kittens/features/settings/presentation/providers/settings_providers.dart';
import 'package:exploding_kittens/game_engine/models/game/game_config.dart';
import 'package:exploding_kittens/game_engine/models/player/player_model.dart';

/// Cada dispositivo conectado a la sala es dueño de un único jugador: por
/// ahora solo el host corre el motor real (vía `LocalGameGateway`);
/// sincronizar el estado con los demás dispositivos por red es Fase 5.
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
      events: ref.read(gameProvider.notifier).events,
      audioService: _audioService,
      settings: () => ref.read(settingsProvider).value ?? const AppSettings(),
    );
    _syncMusic();
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
    if (ref.read(gameProvider) is! GameIdle) return;

    final lobbyState = ref.read(lobbyProvider);
    if (lobbyState is! LobbyInRoom || !lobbyState.isHost) return;

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
    ref.listen(settingsProvider, (_, __) => _syncMusic());

    final lobbyState = ref.watch(lobbyProvider);
    final resolver = ref.watch(cardAssetResolverProvider).value;

    if (lobbyState is! LobbyInRoom) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: _CenteredMessage('No hay ninguna partida en curso'),
      );
    }

    if (!lobbyState.isHost) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: _CenteredMessage(
          'Esperando sincronización con el host…\n(llega en la Fase 5)',
        ),
      );
    }

    final sessionState = ref.watch(gameProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: switch (sessionState) {
        GameRunning(:final state) => GameTableView(
            gameState: state,
            localPlayerId: lobbyState.localPlayerId,
            onDraw: () => ref
                .read(gameProvider.notifier)
                .drawCard(lobbyState.localPlayerId),
            onPlaySimpleCard: (card) => ref
                .read(gameProvider.notifier)
                .playCard(lobbyState.localPlayerId, card),
            onPlayFavor: (card, targetId) => ref
                .read(gameProvider.notifier)
                .playFavor(lobbyState.localPlayerId, card, targetId),
            onPlayCatPair: (cards, targetId) => ref
                .read(gameProvider.notifier)
                .playCatPair(lobbyState.localPlayerId, cards, targetId),
            onPlayNope: (card) => ref
                .read(gameProvider.notifier)
                .playNope(lobbyState.localPlayerId, card),
            onDefuseBomb: (card, position) => ref
                .read(gameProvider.notifier)
                .defuse(lobbyState.localPlayerId, card, position),
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

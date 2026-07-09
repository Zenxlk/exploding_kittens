import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:exploding_kittens/core/router/route_names.dart';
import 'package:exploding_kittens/core/theme/app_colors.dart';
import 'package:exploding_kittens/core/theme/app_text_styles.dart';
import 'package:exploding_kittens/features/game/presentation/providers/card_asset_provider.dart';
import 'package:exploding_kittens/features/game/presentation/providers/game_providers.dart';
import 'package:exploding_kittens/features/game/presentation/widgets/game_table_view.dart';
import 'package:exploding_kittens/features/lobby/presentation/providers/lobby_providers.dart';
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startIfNeeded());
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
      if (next case GameFinished(:final result)) {
        context.go('${RouteNames.gameOver}?winnerId=${result.winnerId}');
      }
    });

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

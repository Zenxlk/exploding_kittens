import 'package:flutter/material.dart';

import 'package:exploding_kittens/core/theme/app_colors.dart';
import 'package:exploding_kittens/core/theme/app_text_styles.dart';
import 'package:exploding_kittens/game_engine/models/player/player_model.dart';
import 'package:exploding_kittens/game_engine/models/player/player_status.dart';

/// Fila de avatares de todos los jugadores (o de los oponentes, según lo que
/// le pase el caller) con su contador de cartas y quién tiene el turno.
/// Widget "tonto".
class PlayersHudWidget extends StatelessWidget {
  const PlayersHudWidget({
    super.key,
    required this.players,
    required this.currentPlayerId,
  });

  final List<PlayerModel> players;
  final String currentPlayerId;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 108,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: players.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final player = players[index];
          return _PlayerBadge(
            player: player,
            isCurrentTurn: player.id == currentPlayerId,
          );
        },
      ),
    );
  }
}

class _PlayerBadge extends StatelessWidget {
  const _PlayerBadge({required this.player, required this.isCurrentTurn});

  final PlayerModel player;
  final bool isCurrentTurn;

  static const _turnTransitionDuration = Duration(milliseconds: 250);

  bool get _isEliminated => player.status == PlayerStatus.eliminated;
  bool get _isDisconnected => player.status == PlayerStatus.disconnected;

  @override
  Widget build(BuildContext context) {
    final opacity = _isEliminated ? 0.4 : (_isDisconnected ? 0.6 : 1.0);

    return Opacity(
      opacity: opacity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 16,
            child: AnimatedOpacity(
              duration: _turnTransitionDuration,
              opacity: isCurrentTurn ? 1 : 0,
              child: const Icon(Icons.arrow_drop_down,
                  size: 20, color: AppColors.warning),
            ),
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedContainer(
                duration: _turnTransitionDuration,
                padding: EdgeInsets.all(isCurrentTurn ? 3 : 0),
                decoration: isCurrentTurn
                    ? const BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.fromBorderSide(
                          BorderSide(color: AppColors.warning, width: 2.5),
                        ),
                      )
                    : const BoxDecoration(shape: BoxShape.circle),
                child: CircleAvatar(
                  radius: 22,
                  backgroundColor:
                      isCurrentTurn ? AppColors.primary : AppColors.surface,
                  child: Text(
                    player.name.isNotEmpty ? player.name[0].toUpperCase() : '?',
                    style: AppTextStyles.title,
                  ),
                ),
              ),
              if (_isDisconnected)
                const Positioned(
                  right: -2,
                  bottom: -2,
                  child: Icon(
                    Icons.wifi_off_rounded,
                    size: 16,
                    color: AppColors.secondary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            player.name,
            style: AppTextStyles.caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (_isDisconnected)
            Text(
              'Reconectando…',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.secondary,
                fontSize: 10,
              ),
            )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.style,
                    size: 12, color: AppColors.onBackground),
                const SizedBox(width: 2),
                Text('${player.cardCount}', style: AppTextStyles.caption),
              ],
            ),
        ],
      ),
    );
  }
}

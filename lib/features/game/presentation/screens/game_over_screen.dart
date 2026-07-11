import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:exploding_kittens/core/audio/audio_service.dart';
import 'package:exploding_kittens/core/audio/i_audio_service.dart';
import 'package:exploding_kittens/core/constants/asset_paths.dart';
import 'package:exploding_kittens/core/router/route_names.dart';
import 'package:exploding_kittens/core/theme/app_colors.dart';
import 'package:exploding_kittens/core/theme/app_text_styles.dart';
import 'package:exploding_kittens/features/game/presentation/providers/game_providers.dart';
import 'package:exploding_kittens/features/lobby/presentation/providers/lobby_providers.dart';
import 'package:exploding_kittens/features/settings/domain/app_settings.dart';
import 'package:exploding_kittens/features/settings/presentation/providers/settings_providers.dart';
import 'package:exploding_kittens/game_engine/models/game/game_config.dart';
import 'package:exploding_kittens/game_engine/models/player/player_model.dart';

/// Resultado de la partida: ganador, ranking por orden real de eliminación
/// (último eliminado queda 2º, el primero en explotar queda último) y
/// revancha. La revancha sigue siendo solo del host (mismo límite que
/// `GameScreen`: solo el host corre el `GameEngine` real), pero el resultado
/// en sí ya se sincroniza a los no-host vía `remoteGameProvider`.
class GameOverScreen extends ConsumerStatefulWidget {
  const GameOverScreen({super.key});

  @override
  ConsumerState<GameOverScreen> createState() => _GameOverScreenState();
}

class _GameOverScreenState extends ConsumerState<GameOverScreen> {
  // Se guarda como campo (no se relee vía `ref.read` en dispose): Riverpod
  // no permite leer providers en dispose(), el widget ya está desmontado.
  late final IAudioService _audioService;

  @override
  void initState() {
    super.initState();
    _audioService = ref.read(audioServiceProvider);
    _syncMusic();
  }

  void _syncMusic() {
    final settings = ref.read(settingsProvider).value ?? const AppSettings();
    _audioService.playMusic(
      AssetPaths.musicGameOver,
      enabled: settings.musicEnabled,
      volume: settings.volume,
    );
  }

  @override
  void dispose() {
    _audioService.stopMusic();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(settingsProvider, (_, __) => _syncMusic());
    // El host navega a GameScreen manualmente dentro de _rematch(); un
    // no-host no dispara esa acción, solo refleja lo que le llega —
    // necesita su propio disparador para no quedarse varado aquí en cuanto
    // remoteGameProvider deja de estar en GameFinished (nueva partida).
    ref.listen<GameSessionState>(remoteGameProvider, (_, next) {
      if (next is GameRunning) context.go(RouteNames.game);
    });

    final lobbyState = ref.watch(lobbyProvider);
    final isHostDevice = lobbyState is! LobbyInRoom || lobbyState.isHost;
    final sessionState =
        isHostDevice ? ref.watch(gameProvider) : ref.watch(remoteGameProvider);

    if (sessionState is! GameFinished) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: _CenteredColumn(
          children: [
            Text(
              'No hay ningún resultado de partida',
              style: AppTextStyles.body,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => _goHome(context),
              child: const Text('Volver al menú'),
            ),
          ],
        ),
      );
    }

    final result = sessionState.result;
    final inRoom = lobbyState is LobbyInRoom ? lobbyState : null;
    final players = inRoom?.room.players ?? const [];
    String nameFor(String id) =>
        players.where((p) => p.id == id).firstOrNull?.name ?? id;

    final ranking = [result.winnerId, ...result.eliminationOrder.reversed];
    final isHost = inRoom?.isHost ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _CenteredColumn(
          children: [
            Text(
              '¡${result.winnerName} ganó!',
              style: AppTextStyles.title,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              '${result.totalTurns} turnos jugados',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: 24),
            for (var i = 0; i < ranking.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  '${i + 1}. ${nameFor(ranking[i])}',
                  style: AppTextStyles.body,
                ),
              ),
            const SizedBox(height: 32),
            if (isHost)
              FilledButton(
                onPressed: () => _rematch(inRoom!),
                style:
                    FilledButton.styleFrom(backgroundColor: AppColors.primary),
                child: const Text('Revancha'),
              )
            else
              Text(
                'Esperando a que el host inicie una revancha…',
                style: AppTextStyles.caption,
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => _goHome(context),
              child: const Text('Volver al menú'),
            ),
          ],
        ),
      ),
    );
  }

  // Sin esto, el WsServer del host (o la conexión del cliente) quedaba vivo
  // al volver al menú y crear/unirse a otra sala reusaba el mismo
  // LobbyRepository sin cerrar lo anterior — "servidor fantasma" que
  // bloqueaba el join de la sala nueva (ver docs/VERIFICATION_LOG.md).
  Future<void> _goHome(BuildContext context) async {
    await ref.read(lobbyProvider.notifier).leaveRoom();
    if (context.mounted) context.go(RouteNames.home);
  }

  void _rematch(LobbyInRoom lobbyState) {
    final players = lobbyState.room.players
        .map((p) => PlayerModel(id: p.id, name: p.name, hand: const []))
        .toList();
    ref
        .read(gameProvider.notifier)
        .startLocalGame(players, GameConfig(playerCount: players.length));
    context.go(RouteNames.game);
  }
}

class _CenteredColumn extends StatelessWidget {
  const _CenteredColumn({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
import 'package:exploding_kittens/l10n/app_localizations.dart';

/// Resultado de la partida: ganador, ranking por orden real de eliminación
/// (último eliminado queda 2º, el primero en explotar queda último) y
/// revancha. La revancha la sigue disparando solo el host, pero el camino
/// difiere según el modo: en LAN arranca el `GameEngine` local ahí mismo
/// (mismo límite que `GameScreen`: solo el host lo corre); en online manda
/// el mismo `start_game` de siempre y el servidor decide solo con la fase
/// de la sala (`cards_game_service`, `onStartGame` acepta tanto
/// `phaseWaiting` como `phaseFinished`) — ver `_rematch()`. El resultado en
/// sí ya se sincroniza a los no-host vía `remoteGameProvider` en los dos
/// modos.
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
    // Mismo criterio que GameScreen._runsLocalEngine(): en modo online ni
    // siquiera el host corre el motor local, así que refleja remoteGameProvider
    // como cualquier no-host.
    final runsLocalEngine = lobbyState is! LobbyInRoom ||
        (lobbyState.isHost && !ref.read(lobbyProvider.notifier).isOnline);
    final sessionState = runsLocalEngine
        ? ref.watch(gameProvider)
        : ref.watch(remoteGameProvider);
    final l10n = AppLocalizations.of(context)!;

    if (sessionState is! GameFinished) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: _CenteredColumn(
          children: [
            Text(
              l10n.gameOverNoResult,
              style: AppTextStyles.body,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => _goHome(context),
              child: Text(l10n.gameOverBackToMenu),
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
    final lobbyIsHost = inRoom?.isHost ?? false;
    // Entrada escalonada: cada fila del ranking aparece un poco después de
    // la anterior; los botones esperan a que termine la última fila.
    final buttonsDelay = (200 + ranking.length * 60).ms;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _CenteredColumn(
          children: [
            Text(
              l10n.gameOverWinnerAnnouncement(result.winnerName),
              style: AppTextStyles.title,
              textAlign: TextAlign.center,
            ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.2, end: 0),
            const SizedBox(height: 4),
            Text(
              l10n.gameOverTurnsPlayed(result.totalTurns),
              style: AppTextStyles.caption,
            ).animate().fadeIn(delay: 100.ms, duration: 300.ms),
            const SizedBox(height: 24),
            for (var i = 0; i < ranking.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  l10n.gameOverRankingEntry(i + 1, nameFor(ranking[i])),
                  style: AppTextStyles.body,
                ),
              )
                  .animate()
                  .fadeIn(delay: (200 + i * 60).ms, duration: 250.ms)
                  .slideX(begin: 0.1, end: 0),
            const SizedBox(height: 32),
            if (lobbyIsHost)
              FilledButton(
                onPressed: () => _rematch(inRoom!),
                style:
                    FilledButton.styleFrom(backgroundColor: AppColors.primary),
                child: Text(l10n.gameOverRematch),
              ).animate().fadeIn(delay: buttonsDelay)
            else
              Text(
                l10n.gameOverWaitingForRematch,
                style: AppTextStyles.caption,
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: buttonsDelay),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => _goHome(context),
              child: Text(l10n.gameOverBackToMenu),
            ).animate().fadeIn(delay: buttonsDelay),
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

  // LAN: arranca el motor local ahí mismo y navega de una — el host es el
  // único que corre GameEngine en LAN, no hay nada que esperar por red.
  // Online: no hay motor local que arrancar (cards_game_service#10 lo
  // resuelve del lado del servidor con el mismo start_game de siempre,
  // ahora también válido con la sala en phaseFinished) — el host manda la
  // acción y espera igual que cualquier no-host: el listener de
  // remoteGameProvider de build() navega solo en cuanto llegue el primer
  // GameState de la revancha.
  void _rematch(LobbyInRoom lobbyState) {
    final lobbyNotifier = ref.read(lobbyProvider.notifier);
    if (lobbyNotifier.isOnline) {
      lobbyNotifier.startGame();
      return;
    }

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

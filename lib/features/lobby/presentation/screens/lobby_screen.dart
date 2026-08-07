import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import 'package:exploding_kittens/core/audio/menu_music_mixin.dart';
import 'package:exploding_kittens/core/config/online_config.dart';
import 'package:exploding_kittens/core/router/route_names.dart';
import 'package:exploding_kittens/core/theme/app_colors.dart';
import 'package:exploding_kittens/core/theme/app_text_styles.dart';
import 'package:exploding_kittens/features/lobby/domain/models/discovered_room.dart';
import 'package:exploding_kittens/features/lobby/domain/models/lobby_player.dart';
import 'package:exploding_kittens/features/lobby/domain/models/lobby_room.dart';
import 'package:exploding_kittens/features/lobby/domain/models/lobby_status.dart';
import 'package:exploding_kittens/features/lobby/presentation/providers/lobby_providers.dart';
import 'package:exploding_kittens/features/settings/presentation/providers/settings_providers.dart';
import 'package:exploding_kittens/l10n/app_localizations.dart';

class LobbyScreen extends ConsumerStatefulWidget {
  const LobbyScreen({super.key, required this.isHost});
  final bool isHost;

  @override
  ConsumerState<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends ConsumerState<LobbyScreen>
    with MenuMusicMixin<LobbyScreen> {
  // null hasta que el jugador elige LAN u online — a diferencia de antes de
  // la Fase 7 de modo online, ya no se auto-dispara createRoom()/
  // startDiscovery() en initState: ahora depende de esta elección explícita
  // (ver LobbyMode, decidido a propósito así para no forzar a jugadores de
  // la misma LAN a pasar por Internet solo porque el build tenga un backend
  // online configurado).
  LobbyMode? _selectedMode;

  void _onModeSelected(LobbyMode mode) {
    if (widget.isHost) {
      setState(() => _selectedMode = mode);
      ref.read(lobbyProvider.notifier).createRoom(mode: mode);
    } else if (mode == LobbyMode.lan) {
      setState(() => _selectedMode = mode);
      ref.read(lobbyProvider.notifier).startDiscovery();
    } else {
      // No hay nada que "conectar" todavía acá — _selectedMode se setea
      // recién si el jugador confirma un código, para no mostrar el
      // spinner de _ConnectingView detrás del diálogo antes de tiempo
      // (_selectedMode no nulo ya salta el selector de modo en build()).
      _showRoomCodeDialog();
    }
  }

  void _showRoomCodeDialog() {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(l10n.lobbyRoomCodeDialogTitle, style: AppTextStyles.title),
        content: TextField(
          controller: controller,
          style: AppTextStyles.body,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            hintText: l10n.lobbyRoomCodeHint,
            hintStyle: AppTextStyles.caption.copyWith(
              color: AppColors.onBackground.withValues(alpha: 0.4),
            ),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              l10n.commonCancel,
              style: AppTextStyles.body.copyWith(
                color: AppColors.onBackground.withValues(alpha: 0.5),
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              final code = controller.text.trim().toUpperCase();
              if (code.isNotEmpty) {
                Navigator.pop(ctx);
                setState(() => _selectedMode = LobbyMode.online);
                ref
                    .read(lobbyProvider.notifier)
                    .joinRoom(code, mode: LobbyMode.online);
              }
            },
            child: Text(
              l10n.lobbyConnect,
              style: AppTextStyles.body.copyWith(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(settingsProvider, (_, __) => syncMenuMusic());
    ref.listen<LobbyState>(lobbyProvider, (_, next) {
      switch (next) {
        case LobbyInRoom(:final room) when room.status == LobbyStatus.starting:
          context.go(RouteNames.game);
        case LobbyError(:final message):
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: AppColors.primary,
            ),
          );
          context.pop();
        default:
          break;
      }
    });
    // Aparte del listen de arriba a propósito: ese switch ya cubre
    // LobbyError (falla al crear/unirse); esto es un WsErrorMessage
    // llegando mientras ya se está adentro de la sala (ej. start_game
    // rechazado por "Faltan jugadores listos") — antes se perdía en
    // silencio, ver issue #39.
    ref.listen<LobbyState>(lobbyProvider, (_, next) {
      if (next is LobbyInRoom && next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    });

    final lobbyState = ref.watch(lobbyProvider);
    final l10n = AppLocalizations.of(context)!;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) {
          await ref.read(lobbyProvider.notifier).leaveRoom();
          if (context.mounted) context.pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.onBackground,
          elevation: 0,
          title: Text(
            widget.isHost ? l10n.homeCreateRoom : l10n.homeJoinRoom,
            style: AppTextStyles.title,
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () async {
              await ref.read(lobbyProvider.notifier).leaveRoom();
              if (context.mounted) context.pop();
            },
          ),
        ),
        body: SafeArea(
          child: _selectedMode == null
              ? _ModeSelectionView(
                  isHost: widget.isHost,
                  onSelect: _onModeSelected,
                )
              : switch (lobbyState) {
                  LobbyIdle() || LobbyConnecting() => _ConnectingView(
                      label: widget.isHost
                          ? l10n.lobbyCreatingRoom
                          : l10n.lobbyConnectingEllipsis,
                    ),
                  LobbyDiscovering(:final rooms) => _DiscoveringView(
                      rooms: rooms,
                      onJoin: (r) => ref
                          .read(lobbyProvider.notifier)
                          .joinRoom(r.hostAddress),
                    ),
                  LobbyInRoom() =>
                    _InRoomView(lobbyState, mode: _selectedMode!),
                  LobbyError() =>
                    _ConnectingView(label: l10n.lobbyGenericError),
                },
        ),
      ),
    );
  }
}

// ── Mode selection (LAN vs online, Fase 7) ───────────────────────────────────

class _ModeSelectionView extends StatelessWidget {
  const _ModeSelectionView({required this.isHost, required this.onSelect});
  final bool isHost;
  final ValueChanged<LobbyMode> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.wifi_tethering_rounded,
              size: 56,
              color: AppColors.secondary,
            ),
            const Gap(16),
            Text(
              isHost ? l10n.lobbyHowToHost : l10n.lobbyHowToJoin,
              style: AppTextStyles.title,
              textAlign: TextAlign.center,
            ),
            const Gap(24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => onSelect(LobbyMode.lan),
                icon: const Icon(Icons.wifi_rounded),
                label: Text(l10n.lobbyLocalWifi),
              ),
            ),
            const Gap(12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: OnlineConfig.isConfigured
                    ? () => onSelect(LobbyMode.online)
                    : null,
                icon: const Icon(Icons.public_rounded),
                label: Text(
                  OnlineConfig.isConfigured
                      ? l10n.lobbyOnline
                      : l10n.lobbyOnlineUnavailable,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Connecting splash ──────────────────────────────────────────────────────────

class _ConnectingView extends StatelessWidget {
  const _ConnectingView({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppColors.primary),
          const Gap(20),
          Text(label, style: AppTextStyles.body),
        ],
      ),
    );
  }
}

// ── Discovery view ─────────────────────────────────────────────────────────────

class _DiscoveringView extends StatelessWidget {
  const _DiscoveringView({
    required this.rooms,
    required this.onJoin,
  });

  final List<DiscoveredRoom> rooms;
  final void Function(DiscoveredRoom) onJoin;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.secondary,
                ),
              ),
              const Gap(10),
              Text(
                l10n.lobbyScanningNetwork,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.onBackground.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: rooms.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.wifi_find_rounded,
                        size: 56,
                        color: AppColors.onBackground.withValues(alpha: 0.2),
                      ),
                      const Gap(12),
                      Text(
                        l10n.lobbyNoRoomsFound,
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.onBackground.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: rooms.length,
                  itemBuilder: (_, i) => _RoomCard(
                    room: rooms[i],
                    onTap: () => onJoin(rooms[i]),
                  ).animate().fadeIn(delay: (i * 60).ms).slideY(
                        begin: 0.2,
                        end: 0,
                        curve: Curves.easeOut,
                      ),
                ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: TextButton.icon(
            onPressed: () => _showManualIpDialog(context),
            icon: const Icon(Icons.edit_rounded, size: 16),
            label: Text(l10n.lobbyEnterIpManually),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.onBackground.withValues(alpha: 0.55),
            ),
          ),
        ),
      ],
    );
  }

  void _showManualIpDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(l10n.lobbyHostIpDialogTitle, style: AppTextStyles.title),
        content: TextField(
          controller: controller,
          style: AppTextStyles.body,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: l10n.lobbyIpHint,
            hintStyle: AppTextStyles.caption.copyWith(
              color: AppColors.onBackground.withValues(alpha: 0.4),
            ),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              l10n.commonCancel,
              style: AppTextStyles.body.copyWith(
                color: AppColors.onBackground.withValues(alpha: 0.5),
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              final ip = controller.text.trim();
              if (ip.isNotEmpty) {
                Navigator.pop(ctx);
                onJoin(DiscoveredRoom(
                  roomId: 'manual',
                  hostName: ip,
                  hostAddress: ip,
                  port: 8765,
                  playerCount: 0,
                  maxPlayers: 5,
                ));
              }
            },
            child: Text(
              l10n.lobbyConnect,
              style: AppTextStyles.body.copyWith(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoomCard extends StatelessWidget {
  const _RoomCard({required this.room, required this.onTap});
  final DiscoveredRoom room;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: const Icon(
          Icons.meeting_room_rounded,
          color: AppColors.secondary,
          size: 28,
        ),
        title: Text(room.hostName, style: AppTextStyles.body),
        subtitle: Text(
          room.hostAddress,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.onBackground.withValues(alpha: 0.45),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${room.playerCount}/${room.maxPlayers}',
              style: AppTextStyles.caption.copyWith(
                color: room.isFull ? AppColors.eliminated : AppColors.success,
              ),
            ),
            const Gap(8),
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.onBackground.withValues(alpha: 0.3),
            ),
          ],
        ),
        onTap: room.isFull ? null : onTap,
      ),
    );
  }
}

// ── In-room view ──────────────────────────────────────────────────────────────

class _InRoomView extends ConsumerWidget {
  const _InRoomView(this.lobbyState, {required this.mode});
  final LobbyInRoom lobbyState;
  final LobbyMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final room = lobbyState.room;
    final isHost = lobbyState.isHost;
    // Bots server-side (modo online) son un issue futuro separado — acá
    // solo tiene sentido ofrecer agregar bots cuando el motor real corre
    // en este dispositivo (LAN/local, ver ILobbyRepository.addBot).
    final canManageBots =
        isHost && mode == LobbyMode.lan && room.status == LobbyStatus.waiting;

    return Column(
      children: [
        // ── Room info header ────────────────────────────────────────────
        _RoomHeader(room: room, isHost: isHost, mode: mode),

        // ── Player list ─────────────────────────────────────────────────
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: room.players.length,
            itemBuilder: (_, i) => _PlayerTile(
              player: room.players[i],
              isLocalPlayer: room.players[i].id == lobbyState.localPlayerId,
              onRemoveBot: canManageBots
                  ? () => ref
                      .read(lobbyProvider.notifier)
                      .removeBot(room.players[i].id)
                  : null,
            )
                .animate()
                .fadeIn(delay: (i * 50).ms)
                .slideX(begin: 0.1, end: 0, curve: Curves.easeOut),
          ),
        ),

        // ── Agregar bot (issue #47) ─────────────────────────────────────
        if (canManageBots && !room.isFull) _AddBotButton(room: room, ref: ref),

        // ── Action bar ──────────────────────────────────────────────────
        _ActionBar(lobbyState: lobbyState, ref: ref),
      ],
    );
  }
}

class _AddBotButton extends StatelessWidget {
  const _AddBotButton({required this.room, required this.ref});
  final LobbyRoom room;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () {
            final botNumber = room.players.where((p) => p.isBot).length + 1;
            ref
                .read(lobbyProvider.notifier)
                .addBot(l10n.lobbyBotName(botNumber));
          },
          icon: const Icon(Icons.smart_toy_rounded, size: 18),
          label: Text(l10n.lobbyAddBot),
        ),
      ),
    );
  }
}

class _RoomHeader extends ConsumerWidget {
  const _RoomHeader({
    required this.room,
    required this.isHost,
    required this.mode,
  });
  final LobbyRoom room;
  final bool isHost;
  final LobbyMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wifiIp = ref.watch(wifiIpProvider);
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      color: AppColors.surface,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.lobbyPlayerCount(room.players.length, room.maxPlayers),
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.secondary,
                    letterSpacing: 1,
                  ),
                ),
                const Gap(2),
                if (isHost && mode == LobbyMode.online)
                  // El código de sala es room.id: cards_game_service lo usa
                  // como identidad de la sala (ver internal/lobby/lobby.go,
                  // CreateRoom), a diferencia de LAN donde ese id no se
                  // muestra — ahí se comparte la IP de WiFi en su lugar.
                  _CopyableValue(
                    value: room.id,
                    copiedMessage: l10n.lobbyRoomCodeCopied,
                  )
                else if (isHost)
                  wifiIp.when(
                    data: (ip) => ip == null
                        ? Text(
                            l10n.lobbyNoWifi,
                            style: AppTextStyles.body
                                .copyWith(color: AppColors.eliminated),
                          )
                        : _CopyableValue(
                            value: ip,
                            copiedMessage: l10n.lobbyIpCopied,
                          ),
                    loading: () => Text(
                      l10n.lobbyReadingIp,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.onBackground.withValues(alpha: 0.4),
                      ),
                    ),
                    error: (_, __) => Text(
                      l10n.lobbyWifiIpUnavailable,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.eliminated,
                      ),
                    ),
                  )
                else
                  Text(
                    l10n.lobbyWaitingForHost,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.onBackground.withValues(alpha: 0.5),
                    ),
                  ),
              ],
            ),
          ),
          // Waiting dots animation
          if (room.players.length < room.maxPlayers)
            Row(
              children: List.generate(
                room.maxPlayers - room.players.length,
                (i) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.onBackground.withValues(alpha: 0.15),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// Tocar copia [value] al portapapeles y confirma con un snackbar — usado
// para la IP de WiFi (LAN) y el código de sala (online), mismo gesto,
// distinto valor.
class _CopyableValue extends StatelessWidget {
  const _CopyableValue({required this.value, required this.copiedMessage});
  final String value;
  final String copiedMessage;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Clipboard.setData(ClipboardData(text: value));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(copiedMessage),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: AppTextStyles.body),
          const Gap(6),
          Icon(
            Icons.copy_rounded,
            size: 14,
            color: AppColors.onBackground.withValues(alpha: 0.4),
          ),
        ],
      ),
    );
  }
}

class _PlayerTile extends StatelessWidget {
  const _PlayerTile({
    required this.player,
    required this.isLocalPlayer,
    this.onRemoveBot,
  });
  final LobbyPlayer player;
  final bool isLocalPlayer;

  // No-null solo cuando el que mira es el host, el bot se puede sacar
  // (sala en espera, LAN) y [player] es efectivamente un bot — controla el
  // botón de "quitar" en trailing. issue #47.
  final VoidCallback? onRemoveBot;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: player.isHost
            ? AppColors.primary.withValues(alpha: 0.2)
            : AppColors.surface,
        child: player.isBot
            ? const Icon(Icons.smart_toy_rounded, color: AppColors.secondary)
            : Text(
                player.name.isEmpty ? '?' : player.name[0].toUpperCase(),
                style: AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.bold,
                  color: player.isHost
                      ? AppColors.primary
                      : AppColors.onBackground,
                ),
              ),
      ),
      title: Row(
        children: [
          Text(
            isLocalPlayer ? l10n.lobbyPlayerNameYou(player.name) : player.name,
            style: AppTextStyles.body,
          ),
          if (player.isHost) ...[
            const Gap(6),
            Icon(Icons.star_rounded, size: 14, color: AppColors.warning),
          ],
        ],
      ),
      trailing: player.isBot
          ? (onRemoveBot == null
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: AppColors.eliminated),
                  tooltip: l10n.lobbyRemoveBot,
                  onPressed: onRemoveBot,
                ))
          : player.isHost
              ? null
              : AnimatedSwitcher(
                  duration: 300.ms,
                  child: player.isReady
                      ? const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.success,
                          key: ValueKey('ready'),
                        )
                      : Icon(
                          Icons.radio_button_unchecked_rounded,
                          color: AppColors.onBackground.withValues(alpha: 0.3),
                          key: const ValueKey('not_ready'),
                        ),
                ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.lobbyState, required this.ref});
  final LobbyInRoom lobbyState;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final isHost = lobbyState.isHost;
    final room = lobbyState.room;
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.all(20),
      color: AppColors.surface,
      child: SizedBox(
        width: double.infinity,
        child: isHost
            ? ElevatedButton.icon(
                onPressed: room.canStart
                    ? () => ref.read(lobbyProvider.notifier).startGame()
                    : null,
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(
                  room.canStart
                      ? l10n.lobbyStartGame
                      : l10n.lobbyWaitingForPlayers,
                  style: AppTextStyles.body,
                ),
              )
            : ElevatedButton.icon(
                onPressed: () => ref
                    .read(lobbyProvider.notifier)
                    .setReady(ready: !lobbyState.isLocalPlayerReady),
                icon: Icon(
                  lobbyState.isLocalPlayerReady
                      ? Icons.close_rounded
                      : Icons.check_rounded,
                ),
                label: Text(
                  lobbyState.isLocalPlayerReady
                      ? l10n.lobbyNotReady
                      : l10n.lobbyReady,
                  style: AppTextStyles.body,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: lobbyState.isLocalPlayerReady
                      ? AppColors.surface
                      : AppColors.success,
                  foregroundColor: lobbyState.isLocalPlayerReady
                      ? AppColors.onBackground.withValues(alpha: 0.7)
                      : Colors.white,
                ),
              ),
      ),
    );
  }
}

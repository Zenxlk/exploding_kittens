import 'package:flutter/material.dart';

import 'package:exploding_kittens/core/theme/app_colors.dart';
import 'package:exploding_kittens/core/theme/app_text_styles.dart';
import 'package:exploding_kittens/features/game/presentation/widgets/deck_widget.dart';
import 'package:exploding_kittens/features/game/presentation/widgets/discard_pile_widget.dart';
import 'package:exploding_kittens/features/game/presentation/widgets/player_hand_widget.dart';
import 'package:exploding_kittens/features/game/presentation/widgets/players_hud_widget.dart';
import 'package:exploding_kittens/game_engine/models/card/card_model.dart';
import 'package:exploding_kittens/game_engine/models/card/card_type.dart';
import 'package:exploding_kittens/game_engine/models/game/game_state.dart';
import 'package:exploding_kittens/game_engine/models/turn/turn_model.dart';

/// Cartas que hoy se pueden jugar con un botón simple, sin objetivo ni
/// overlay: Favor, pares/tríos de gato, Nope y Defuse llegan en el próximo
/// paso (overlays de selección de objetivo).
const _quickPlayTypes = {
  CardType.attack,
  CardType.skip,
  CardType.shuffle,
  CardType.seeTheFuture,
};

/// Composición de la mesa de juego para el jugador local: cada dispositivo
/// solo ve y controla la mano de su propio jugador (no la de quien tenga el
/// turno), pensado para partidas en red con un dispositivo por jugador.
/// Widget "tonto": recibe el [GameState] y reporta intenciones por callback,
/// no decide reglas ni lee providers.
class GameTableView extends StatefulWidget {
  const GameTableView({
    super.key,
    required this.gameState,
    required this.localPlayerId,
    required this.onDraw,
    required this.onPlaySimpleCard,
    this.assetPathFor,
    this.cardBackAssetPath,
  });

  final GameState gameState;
  final String localPlayerId;
  final VoidCallback onDraw;
  final ValueChanged<CardModel> onPlaySimpleCard;
  final String? Function(CardType type)? assetPathFor;
  final String? cardBackAssetPath;

  @override
  State<GameTableView> createState() => _GameTableViewState();
}

class _GameTableViewState extends State<GameTableView> {
  String? _selectedCardId;

  @override
  void didUpdateWidget(covariant GameTableView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si la mano cambió (se robó/jugó una carta), la selección puede quedar
    // apuntando a una carta que ya no existe.
    final me = widget.gameState.playerById(widget.localPlayerId);
    final stillHeld = me?.hand.any((c) => c.id == _selectedCardId) ?? false;
    if (!stillHeld) _selectedCardId = null;
  }

  bool get _isMyTurn =>
      widget.gameState.turn.currentPlayerId == widget.localPlayerId;

  bool get _canAct =>
      _isMyTurn && widget.gameState.turn.phase == TurnPhase.playing;

  @override
  Widget build(BuildContext context) {
    final me = widget.gameState.playerById(widget.localPlayerId);
    final hand = me?.hand ?? const <CardModel>[];
    final selected = _selectedCardId == null
        ? null
        : hand.where((c) => c.id == _selectedCardId).firstOrNull;
    final topDiscard = widget.gameState.deck.topDiscard;

    return SafeArea(
      child: Column(
        children: [
          PlayersHudWidget(
            players: widget.gameState.players,
            currentPlayerId: widget.gameState.turn.currentPlayerId,
          ),
          _StatusBanner(gameState: widget.gameState, isMyTurn: _isMyTurn),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DeckWidget(
                      drawPileCount: widget.gameState.deck.drawPileCount,
                      cardBackAssetPath: widget.cardBackAssetPath,
                      onTap: _canAct ? widget.onDraw : null,
                    ),
                    const SizedBox(width: 24),
                    DiscardPileWidget(
                      topCard: topDiscard,
                      topCardAssetPath: topDiscard == null
                          ? null
                          : widget.assetPathFor?.call(topDiscard.type),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (selected != null)
            _SelectionBar(
              card: selected,
              canPlay: _canAct && _quickPlayTypes.contains(selected.type),
              onPlay: () {
                widget.onPlaySimpleCard(selected);
                setState(() => _selectedCardId = null);
              },
              onCancel: () => setState(() => _selectedCardId = null),
            ),
          PlayerHandWidget(
            hand: hand,
            selectedCardIds:
                _selectedCardId == null ? const {} : {_selectedCardId!},
            playableCardIds: _canAct
                ? hand
                    .where((c) => _quickPlayTypes.contains(c.type))
                    .map((c) => c.id)
                    .toSet()
                : const {},
            assetPathFor: widget.assetPathFor,
            onCardTap: (card) => setState(
              () =>
                  _selectedCardId = _selectedCardId == card.id ? null : card.id,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.gameState, required this.isMyTurn});

  final GameState gameState;
  final bool isMyTurn;

  @override
  Widget build(BuildContext context) {
    final text = switch (gameState.turn.phase) {
      TurnPhase.nopeWindow => 'Ventana de Nope abierta…',
      TurnPhase.resolving =>
        'Resolviendo Defuse (el selector llega en el próximo paso)',
      _ when !isMyTurn => 'Turno de ${gameState.currentPlayer?.name ?? '…'}',
      _ => null,
    };

    if (text == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        text,
        style: AppTextStyles.caption,
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    required this.card,
    required this.canPlay,
    required this.onPlay,
    required this.onCancel,
  });

  final CardModel card;
  final bool canPlay;
  final VoidCallback onPlay;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              canPlay
                  ? '${card.type.name} seleccionada'
                  : 'Esta carta se juega en el próximo paso',
              style: AppTextStyles.caption,
            ),
          ),
          TextButton(onPressed: onCancel, child: const Text('Cancelar')),
          FilledButton(
            onPressed: canPlay ? onPlay : null,
            style: FilledButton.styleFrom(backgroundColor: AppColors.success),
            child: const Text('Jugar'),
          ),
        ],
      ),
    );
  }
}

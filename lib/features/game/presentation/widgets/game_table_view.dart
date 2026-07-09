import 'package:flutter/material.dart';

import 'package:exploding_kittens/core/constants/game_constants.dart';
import 'package:exploding_kittens/core/theme/app_colors.dart';
import 'package:exploding_kittens/core/theme/app_text_styles.dart';
import 'package:exploding_kittens/features/game/presentation/widgets/deck_widget.dart';
import 'package:exploding_kittens/features/game/presentation/widgets/discard_pile_widget.dart';
import 'package:exploding_kittens/features/game/presentation/widgets/explosion_overlay.dart';
import 'package:exploding_kittens/features/game/presentation/widgets/favor_target_overlay.dart';
import 'package:exploding_kittens/features/game/presentation/widgets/insert_bomb_overlay.dart';
import 'package:exploding_kittens/features/game/presentation/widgets/nope_window_overlay.dart';
import 'package:exploding_kittens/features/game/presentation/widgets/player_hand_widget.dart';
import 'package:exploding_kittens/features/game/presentation/widgets/players_hud_widget.dart';
import 'package:exploding_kittens/features/game/presentation/widgets/see_the_future_overlay.dart';
import 'package:exploding_kittens/game_engine/models/card/card_model.dart';
import 'package:exploding_kittens/game_engine/models/card/card_type.dart';
import 'package:exploding_kittens/game_engine/models/game/game_state.dart';
import 'package:exploding_kittens/game_engine/models/turn/turn_model.dart';

/// Cartas que se juegan con un botón simple, sin objetivo: Nope y Defuse se
/// juegan en su propio contexto (ventana de Nope / resolución de bomba), no
/// desde aquí.
const _quickPlayTypes = {
  CardType.attack,
  CardType.skip,
  CardType.shuffle,
  CardType.seeTheFuture,
};

/// Qué se puede hacer con la selección actual de cartas de la mano.
sealed class _Selection {
  const _Selection(this.cards);
  final List<CardModel> cards;
}

class _NoSelection extends _Selection {
  const _NoSelection() : super(const []);
}

/// Una sola carta jugable de inmediato (Attack, Skip, Shuffle, See the Future).
class _QuickPlaySelection extends _Selection {
  _QuickPlaySelection(CardModel card) : super([card]);
  CardModel get card => cards.first;
}

/// Necesita elegir un jugador objetivo antes de resolverse (Favor o par de
/// gatos). [isPair] distingue cuál de las dos acciones construir al confirmar.
class _NeedsTargetSelection extends _Selection {
  const _NeedsTargetSelection(super.cards, this.isPair);
  final bool isPair;
}

/// Una sola carta de gato esperando su pareja.
class _CatCardWaitingForPair extends _Selection {
  const _CatCardWaitingForPair(super.cards);
}

/// Selección que no se puede jugar todavía desde aquí (Nope/Defuse sueltos,
/// trío de gatos —necesita elegir una carta concreta de la mano rival—,
/// combinaciones inválidas).
class _UnsupportedSelection extends _Selection {
  const _UnsupportedSelection(super.cards);
}

_Selection _classifySelection(List<CardModel> cards) {
  if (cards.isEmpty) return const _NoSelection();

  if (cards.length == 1) {
    final card = cards.first;
    if (_quickPlayTypes.contains(card.type)) {
      return _QuickPlaySelection(card);
    }
    if (card.type == CardType.favor) {
      return _NeedsTargetSelection(cards, false);
    }
    if (card.type.isCatCard) {
      return _CatCardWaitingForPair(cards);
    }
    return _UnsupportedSelection(cards);
  }

  if (cards.length == 2 &&
      cards[0].type.isCatCard &&
      cards[0].type == cards[1].type) {
    return _NeedsTargetSelection(cards, true);
  }

  return _UnsupportedSelection(cards);
}

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
    required this.onPlayFavor,
    required this.onPlayCatPair,
    required this.onPlayNope,
    required this.onDefuseBomb,
    this.assetPathFor,
    this.cardBackAssetPath,
  });

  final GameState gameState;
  final String localPlayerId;
  final VoidCallback onDraw;
  final ValueChanged<CardModel> onPlaySimpleCard;
  final void Function(CardModel card, String targetPlayerId) onPlayFavor;
  final void Function(List<CardModel> cards, String targetPlayerId)
      onPlayCatPair;
  final ValueChanged<CardModel> onPlayNope;
  final void Function(CardModel defuseCard, int insertAtPosition) onDefuseBomb;
  final String? Function(CardType type)? assetPathFor;
  final String? cardBackAssetPath;

  @override
  State<GameTableView> createState() => _GameTableViewState();
}

class _GameTableViewState extends State<GameTableView> {
  Set<String> _selectedCardIds = {};
  bool _choosingTarget = false;

  // Descartar el overlay de See the Future es una decisión puramente local
  // de UI: GameState.seeTheFutureCards solo se limpia cuando el turno
  // avanza (ver TurnManager.advance), no cuando el jugador ya lo vio.
  bool _seeTheFutureDismissed = false;

  // No hay ningún campo en GameState que marque "alguien acaba de explotar":
  // se detecta por diff (un jugador vivo en el build anterior que ya no lo
  // está) y se guarda como estado local hasta que la animación termina.
  String? _explodingPlayerName;

  @override
  void didUpdateWidget(covariant GameTableView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si la mano cambió (se robó/jugó una carta), la selección puede quedar
    // apuntando a cartas que ya no existen.
    final me = widget.gameState.playerById(widget.localPlayerId);
    final hand = me?.hand ?? const <CardModel>[];
    _selectedCardIds =
        _selectedCardIds.where((id) => hand.any((c) => c.id == id)).toSet();
    if (_selectedCardIds.isEmpty) _choosingTarget = false;

    // Una nueva revelación (null → no-null) debe volver a mostrarse aunque
    // la anterior ya se hubiera descartado.
    final hadReveal = oldWidget.gameState.seeTheFutureCards != null;
    final hasReveal = widget.gameState.seeTheFutureCards != null;
    if (!hadReveal && hasReveal) _seeTheFutureDismissed = false;

    final newlyEliminated = oldWidget.gameState.alivePlayers.where((p) {
      final now = widget.gameState.playerById(p.id);
      return now != null && !now.isAlive;
    });
    if (newlyEliminated.isNotEmpty) {
      _explodingPlayerName = newlyEliminated.first.name;
    }
  }

  bool get _isMyTurn =>
      widget.gameState.turn.currentPlayerId == widget.localPlayerId;

  bool get _canAct =>
      _isMyTurn && widget.gameState.turn.phase == TurnPhase.playing;

  void _onCardTap(CardModel card) {
    setState(() {
      if (_selectedCardIds.contains(card.id)) {
        _selectedCardIds = {..._selectedCardIds}..remove(card.id);
        return;
      }

      final me = widget.gameState.playerById(widget.localPlayerId);
      final hand = me?.hand ?? const <CardModel>[];
      final selected =
          hand.where((c) => _selectedCardIds.contains(c.id)).toList();

      final sameTypeAsSelection = selected.isNotEmpty &&
          selected.first.type.isCatCard &&
          selected.first.type == card.type;

      _selectedCardIds =
          sameTypeAsSelection ? {..._selectedCardIds, card.id} : {card.id};
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedCardIds = {};
      _choosingTarget = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final me = widget.gameState.playerById(widget.localPlayerId);
    final hand = me?.hand ?? const <CardModel>[];
    final selectedCards =
        hand.where((c) => _selectedCardIds.contains(c.id)).toList();
    final selection = _classifySelection(selectedCards);
    final topDiscard = widget.gameState.deck.topDiscard;
    final seeTheFutureCards = widget.gameState.seeTheFutureCards;
    final showSeeTheFuture =
        seeTheFutureCards != null && !_seeTheFutureDismissed;
    final nopeWindowOpen = widget.gameState.turn.phase == TurnPhase.nopeWindow;
    final myNopeCards = hand.where((c) => c.type == CardType.nope).toList();
    final resolvingMyBomb = _isMyTurn &&
        widget.gameState.turn.phase == TurnPhase.resolving &&
        widget.gameState.pendingBomb != null;

    return Stack(
      children: [
        SafeArea(child: _buildTable(hand, selection, topDiscard)),
        if (showSeeTheFuture)
          SeeTheFutureOverlay(
            topCards: seeTheFutureCards,
            assetPathFor: widget.assetPathFor,
            onDismiss: () => setState(() => _seeTheFutureDismissed = true),
          ),
        if (nopeWindowOpen)
          NopeWindowOverlay(
            duration: const Duration(milliseconds: GameConstants.nopeWindowMs),
            nopeChainCount: widget.gameState.turn.nopeChainCount,
            canPlayNope: myNopeCards.isNotEmpty &&
                widget.gameState.pendingAction != null,
            onPlayNope: () => widget.onPlayNope(myNopeCards.first),
          ),
        if (resolvingMyBomb)
          InsertBombOverlay(
            drawPileCount: widget.gameState.deck.drawPileCount,
            onConfirm: (position) => widget.onDefuseBomb(
              hand.firstWhere((c) => c.type == CardType.defuse),
              position,
            ),
          ),
        if (_choosingTarget && selection is _NeedsTargetSelection)
          FavorTargetOverlay(
            candidates: widget.gameState.alivePlayers
                .where((p) => p.id != widget.localPlayerId)
                .toList(),
            onCancel: _clearSelection,
            onSelect: (targetId) {
              if (selection.isPair) {
                widget.onPlayCatPair(selection.cards, targetId);
              } else {
                widget.onPlayFavor(selection.cards.first, targetId);
              }
              _clearSelection();
            },
          ),
        if (_explodingPlayerName != null)
          ExplosionOverlay(
            eliminatedPlayerName: _explodingPlayerName!,
            onFinished: () => setState(() => _explodingPlayerName = null),
          ),
      ],
    );
  }

  Widget _buildTable(
    List<CardModel> hand,
    _Selection selection,
    CardModel? topDiscard,
  ) {
    return Column(
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
        _SelectionBar(
          selection: selection,
          canAct: _canAct,
          onPlaySimple: () {
            widget.onPlaySimpleCard((selection as _QuickPlaySelection).card);
            _clearSelection();
          },
          onChooseTarget: () => setState(() => _choosingTarget = true),
          onCancel: _clearSelection,
        ),
        PlayerHandWidget(
          hand: hand,
          selectedCardIds: _selectedCardIds,
          playableCardIds: _canAct
              ? hand
                  .where((c) => _quickPlayTypes.contains(c.type))
                  .map((c) => c.id)
                  .toSet()
              : const {},
          assetPathFor: widget.assetPathFor,
          onCardTap: _onCardTap,
        ),
      ],
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
      TurnPhase.resolving when !isMyTurn =>
        'Esperando a que ${gameState.currentPlayer?.name ?? '…'} '
            'esconda la bomba…',
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
    required this.selection,
    required this.canAct,
    required this.onPlaySimple,
    required this.onChooseTarget,
    required this.onCancel,
  });

  final _Selection selection;
  final bool canAct;
  final VoidCallback onPlaySimple;
  final VoidCallback onChooseTarget;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    if (selection is _NoSelection) return const SizedBox.shrink();

    final (message, buttonLabel, onConfirm) = switch (selection) {
      _QuickPlaySelection(:final card) => (
          '${card.type.name} seleccionada',
          'Jugar',
          canAct ? onPlaySimple : null,
        ),
      _NeedsTargetSelection(:final isPair) => (
          isPair ? 'Par de gatos listo' : 'Favor seleccionado',
          'Elegir objetivo',
          canAct ? onChooseTarget : null,
        ),
      _CatCardWaitingForPair() => (
          'Toca otra carta del mismo tipo para formar un par',
          'Jugar',
          null,
        ),
      _UnsupportedSelection() => (
          'Esta carta se juega en otro momento',
          'Jugar',
          null,
        ),
      _NoSelection() => ('', 'Jugar', null),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(message, style: AppTextStyles.caption),
          ),
          TextButton(onPressed: onCancel, child: const Text('Cancelar')),
          FilledButton(
            onPressed: onConfirm,
            style: FilledButton.styleFrom(backgroundColor: AppColors.success),
            child: Text(buttonLabel),
          ),
        ],
      ),
    );
  }
}

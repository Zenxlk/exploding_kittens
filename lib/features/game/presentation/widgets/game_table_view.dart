import 'dart:async';

import 'package:flutter/material.dart';

import 'package:exploding_kittens/core/constants/game_constants.dart';
import 'package:exploding_kittens/core/constants/layout_constants.dart';
import 'package:exploding_kittens/core/extensions/context_extensions.dart';
import 'package:exploding_kittens/core/theme/app_colors.dart';
import 'package:exploding_kittens/core/theme/app_text_styles.dart';
import 'package:exploding_kittens/features/game/presentation/widgets/card_choice_overlay.dart';
import 'package:exploding_kittens/features/game/presentation/widgets/deck_widget.dart';
import 'package:exploding_kittens/features/game/presentation/widgets/discard_pile_widget.dart';
import 'package:exploding_kittens/features/game/presentation/widgets/explosion_overlay.dart';
import 'package:exploding_kittens/features/game/presentation/widgets/favor_target_overlay.dart';
import 'package:exploding_kittens/features/game/presentation/widgets/insert_bomb_overlay.dart';
import 'package:exploding_kittens/features/game/presentation/widgets/nope_window_overlay.dart';
import 'package:exploding_kittens/features/game/presentation/widgets/player_hand_widget.dart';
import 'package:exploding_kittens/features/game/presentation/widgets/players_hud_widget.dart';
import 'package:exploding_kittens/features/game/presentation/widgets/see_the_future_overlay.dart';
import 'package:exploding_kittens/game_engine/events/game_event.dart';
import 'package:exploding_kittens/game_engine/models/card/card_model.dart';
import 'package:exploding_kittens/game_engine/models/card/card_type.dart';
import 'package:exploding_kittens/game_engine/models/game/game_state.dart';
import 'package:exploding_kittens/game_engine/models/turn/turn_action.dart';
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

/// A qué acción corresponde una `_NeedsTargetSelection`.
enum _TargetActionKind { favor, catPair, catTrio }

/// Necesita elegir un jugador objetivo antes de resolverse (Favor, par o
/// trío de gatos). [kind] distingue cuál de las tres acciones construir al
/// confirmar.
class _NeedsTargetSelection extends _Selection {
  const _NeedsTargetSelection(super.cards, this.kind);
  final _TargetActionKind kind;
}

/// Una sola carta de gato esperando su pareja (o su trío).
class _CatCardWaitingForPair extends _Selection {
  const _CatCardWaitingForPair(super.cards);
}

/// Selección que no se puede jugar todavía desde aquí (Nope/Defuse sueltos,
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
      return _NeedsTargetSelection(cards, _TargetActionKind.favor);
    }
    if (card.type.isCatCard) {
      return _CatCardWaitingForPair(cards);
    }
    return _UnsupportedSelection(cards);
  }

  if (cards.length == 2 &&
      cards[0].type.isCatCard &&
      cards[0].type == cards[1].type) {
    return _NeedsTargetSelection(cards, _TargetActionKind.catPair);
  }

  if (cards.length == 3 &&
      cards[0].type.isCatCard &&
      cards.every((c) => c.type == cards[0].type)) {
    return _NeedsTargetSelection(cards, _TargetActionKind.catTrio);
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
    required this.onPlayCatTrio,
    required this.onPlayNope,
    required this.onDefuseBomb,
    required this.onChooseCard,
    this.assetPathFor,
    this.cardBackAssetPath,
    this.events,
  });

  final GameState gameState;
  final String localPlayerId;
  final VoidCallback onDraw;
  final ValueChanged<CardModel> onPlaySimpleCard;
  final void Function(CardModel card, String targetPlayerId) onPlayFavor;
  final void Function(List<CardModel> cards, String targetPlayerId)
      onPlayCatPair;
  final void Function(List<CardModel> cards, String targetPlayerId)
      onPlayCatTrio;
  final ValueChanged<CardModel> onPlayNope;
  final void Function(CardModel defuseCard, int insertAtPosition) onDefuseBomb;
  // Genérico a propósito (no "onGiveFavorCard"): hoy solo lo dispara el
  // objetivo de un Favor eligiendo qué carta de su propia mano entregar,
  // pero está pensado para cualquier otra "elegí una carta concreta" futura.
  final ValueChanged<String> onChooseCard;
  final String? Function(CardType type)? assetPathFor;
  final String? cardBackAssetPath;
  // Mismo stream que ya consume GameSoundController (GameNotifier/
  // RemoteGameNotifier.events): fuente de animaciones que un diff de
  // GameState no puede detectar por sí solo (p. ej. mezclar el mazo no
  // cambia ni su longitud ni nada que se renderice). Opcional para no
  // romper los call sites existentes que no la necesitan.
  final Stream<GameEvent>? events;

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

  // Disparador para DeckWidget.shuffleTrigger: viene de un GameEvent, no de
  // un diff de GameState (mezclar no cambia nada renderizable).
  int _shuffleTrigger = 0;

  // Disparador para el pulso corto del mazo al robar (distinto del
  // bamboleo de mezclar, para que se distingan visualmente).
  int _deckPulseTrigger = 0;

  // Un CardDrawnEvent para el jugador local llega antes que el rebuild con
  // la mano ya crecida (el GameState viaja por otro camino) — se guarda
  // como marcador hasta el próximo didUpdateWidget, donde recién se puede
  // identificar qué id es la carta nueva. Robar por Favor/pareja/trío
  // también crece la mano en 1 sin este marcador, así que no se confunden.
  bool _pendingLocalDraw = false;
  Set<String> _justDrawnCardIds = {};

  StreamSubscription<GameEvent>? _eventsSubscription;

  @override
  void initState() {
    super.initState();
    _subscribeToEvents();
  }

  void _subscribeToEvents() {
    _eventsSubscription = widget.events?.listen(_onGameEvent);
  }

  void _onGameEvent(GameEvent event) {
    switch (event) {
      case DeckShuffledEvent():
        setState(() => _shuffleTrigger++);
      case CardDrawnEvent(:final playerId)
          when playerId == widget.localPlayerId:
        _pendingLocalDraw = true;
        setState(() => _deckPulseTrigger++);
      default:
        break;
    }
  }

  void _scheduleClearJustDrawn(Set<String> ids) {
    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() => _justDrawnCardIds = _justDrawnCardIds.difference(ids));
    });
  }

  @override
  void dispose() {
    _eventsSubscription?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant GameTableView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.events != widget.events) {
      _eventsSubscription?.cancel();
      _subscribeToEvents();
    }
    // Si la mano cambió (se robó/jugó una carta), la selección puede quedar
    // apuntando a cartas que ya no existen.
    final me = widget.gameState.playerById(widget.localPlayerId);
    final hand = me?.hand ?? const <CardModel>[];
    _selectedCardIds =
        _selectedCardIds.where((id) => hand.any((c) => c.id == id)).toSet();
    if (_selectedCardIds.isEmpty) _choosingTarget = false;
    _justDrawnCardIds =
        _justDrawnCardIds.where((id) => hand.any((c) => c.id == id)).toSet();

    if (_pendingLocalDraw) {
      final oldHandIds =
          (oldWidget.gameState.playerById(widget.localPlayerId)?.hand ??
                  const <CardModel>[])
              .map((c) => c.id)
              .toSet();
      final newCardIds =
          hand.map((c) => c.id).where((id) => !oldHandIds.contains(id)).toSet();
      if (newCardIds.isNotEmpty) {
        _justDrawnCardIds = {..._justDrawnCardIds, ...newCardIds};
        _pendingLocalDraw = false;
        _scheduleClearJustDrawn(newCardIds);
      }
    }

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

  /// Si el jugador local es a quien le toca elegir una carta ahora mismo
  /// (Favor: el objetivo, desde su propia mano; trío de gatos: el actor, a
  /// ciegas desde la mano rival), arma los datos para el `CardChoiceOverlay`.
  /// `null` para cualquier otro jugador — ellos ven el cartel de
  /// `_StatusBanner` en su lugar.
  ({String title, List<CardModel> candidates, bool faceUp})?
      _pendingCardChoiceFor(List<CardModel> localHand) {
    if (widget.gameState.turn.phase != TurnPhase.awaitingCardChoice) {
      return null;
    }
    final pending = widget.gameState.pendingAction;

    if (pending is PlayFavorAction &&
        pending.targetPlayerId == widget.localPlayerId) {
      final askerName =
          widget.gameState.playerById(pending.playerId)?.name ?? '…';
      return (
        title: 'Elegí una carta para darle a $askerName',
        candidates: localHand,
        faceUp: true,
      );
    }

    if (pending is PlayCatTrioAction &&
        pending.playerId == widget.localPlayerId) {
      final target = widget.gameState.playerById(pending.targetPlayerId);
      return (
        title: 'Elegí a ciegas una carta de la mano de '
            '${target?.name ?? '…'}',
        candidates: target?.hand ?? const [],
        faceUp: false,
      );
    }

    return null;
  }

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
    // GameState.seeTheFutureCards viaja compartido en la red (no hay un
    // canal privado por jugador todavía — ver docs/GAME_RULES.md), así que
    // sin este chequeo el overlay se le mostraba también a quien no jugó la
    // carta. Solo el jugador activo pudo haberla jugado (GameRules.validate
    // exige ser el jugador actual), así que alcanza con filtrar por turno.
    final showSeeTheFuture =
        seeTheFutureCards != null && _isMyTurn && !_seeTheFutureDismissed;
    final nopeWindowOpen = widget.gameState.turn.phase == TurnPhase.nopeWindow;
    final myNopeCards = hand.where((c) => c.type == CardType.nope).toList();
    final resolvingMyBomb = _isMyTurn &&
        widget.gameState.turn.phase == TurnPhase.resolving &&
        widget.gameState.pendingBomb != null;
    final pendingCardChoice = _pendingCardChoiceFor(hand);

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
              switch (selection.kind) {
                case _TargetActionKind.favor:
                  widget.onPlayFavor(selection.cards.first, targetId);
                case _TargetActionKind.catPair:
                  widget.onPlayCatPair(selection.cards, targetId);
                case _TargetActionKind.catTrio:
                  widget.onPlayCatTrio(selection.cards, targetId);
              }
              _clearSelection();
            },
          ),
        if (pendingCardChoice != null)
          CardChoiceOverlay(
            title: pendingCardChoice.title,
            candidates: pendingCardChoice.candidates,
            faceUp: pendingCardChoice.faceUp,
            assetPathFor: widget.assetPathFor,
            onSelect: widget.onChooseCard,
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
    final isLandscape = context.isLandscape;

    final hud = PlayersHudWidget(
      players: widget.gameState.players,
      currentPlayerId: widget.gameState.turn.currentPlayerId,
    );
    final statusBanner = _StatusBanner(
      gameState: widget.gameState,
      isMyTurn: _isMyTurn,
      localPlayerId: widget.localPlayerId,
    );
    final deckAndDiscard = _buildPlayDropZone(
      _buildDeckAndDiscard(
        topDiscard,
        gap: isLandscape
            ? LayoutConstants.deckDiscardGapLandscape
            : LayoutConstants.deckDiscardGapPortrait,
      ),
    );
    final selectionBar = _SelectionBar(
      selection: selection,
      canAct: _canAct,
      onPlaySimple: () {
        widget.onPlaySimpleCard((selection as _QuickPlaySelection).card);
        _clearSelection();
      },
      onChooseTarget: () => setState(() => _choosingTarget = true),
      onCancel: _clearSelection,
    );
    final playerHand = PlayerHandWidget(
      hand: hand,
      selectedCardIds: _selectedCardIds,
      playableCardIds: _canAct
          ? hand
              .where((c) => _quickPlayTypes.contains(c.type))
              .map((c) => c.id)
              .toSet()
          : const {},
      justDrawnCardIds: _justDrawnCardIds,
      assetPathFor: widget.assetPathFor,
      onCardTap: _onCardTap,
      cardWidth: _handCardWidth(context),
    );

    if (!isLandscape) {
      return Column(
        children: [
          hud,
          statusBanner,
          Expanded(child: Center(child: deckAndDiscard)),
          selectionBar,
          playerHand,
        ],
      );
    }

    // En landscape la altura es escasa y el ancho sobra: la mano deja de
    // estar anclada abajo a lo ancho de toda la pantalla (competiría por
    // esa poca altura) y pasa a su propia columna a la derecha, junto al
    // bloque mazo/descarte + status/selección a la izquierda.
    return Column(
      children: [
        hud,
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    statusBanner,
                    Expanded(child: Center(child: deckAndDiscard)),
                    selectionBar,
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Center(child: playerHand),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Envuelve el bloque de mazo/descarte como destino de arrastre: soltar
  /// ahí una carta de [_quickPlayTypes] la juega directo (ver
  /// [PlayerHandWidget] para el lado que arma el `Draggable`). Cartas que
  /// necesitan objetivo, o cualquier arrastre fuera de mi turno, quedan
  /// rechazadas — `onWillAcceptWithDetails` decide qué resalta el borde.
  Widget _buildPlayDropZone(Widget child) {
    return DragTarget<CardModel>(
      onWillAcceptWithDetails: (details) =>
          _canAct && _quickPlayTypes.contains(details.data.type),
      onAcceptWithDetails: (details) {
        widget.onPlaySimpleCard(details.data);
        _clearSelection();
      },
      builder: (context, candidateData, rejectedData) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: candidateData.isNotEmpty
                ? Border.all(color: AppColors.success, width: 2)
                : null,
          ),
          child: child,
        );
      },
    );
  }

  Widget _buildDeckAndDiscard(CardModel? topDiscard, {required double gap}) {
    return SingleChildScrollView(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DeckWidget(
            drawPileCount: widget.gameState.deck.drawPileCount,
            cardBackAssetPath: widget.cardBackAssetPath,
            onTap: _canAct ? widget.onDraw : null,
            shuffleTrigger: _shuffleTrigger,
            pulseTrigger: _deckPulseTrigger,
          ),
          SizedBox(width: gap),
          DiscardPileWidget(
            topCard: topDiscard,
            topCardAssetPath: topDiscard == null
                ? null
                : widget.assetPathFor?.call(topDiscard.type),
          ),
        ],
      ),
    );
  }

  double _handCardWidth(BuildContext context) {
    if (context.isTablet) return LayoutConstants.handCardWidthTablet;
    return context.isLandscape
        ? LayoutConstants.handCardWidthLandscapePhone
        : LayoutConstants.handCardWidthPortraitPhone;
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.gameState,
    required this.isMyTurn,
    required this.localPlayerId,
  });

  final GameState gameState;
  final bool isMyTurn;
  final String localPlayerId;

  @override
  Widget build(BuildContext context) {
    final text = _messageFor();
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

  String? _messageFor() {
    switch (gameState.turn.phase) {
      case TurnPhase.nopeWindow:
        return 'Ventana de Nope abierta…';
      case TurnPhase.resolving when !isMyTurn:
        return 'Esperando a que ${gameState.currentPlayer?.name ?? '…'} '
            'esconda la bomba…';
      case TurnPhase.awaitingCardChoice:
        final pending = gameState.pendingAction;
        // Al que le toca elegir ve el CardChoiceOverlay en su lugar (cubre
        // toda la pantalla), así que este mensaje es solo para el resto.
        if (pending is PlayFavorAction &&
            pending.targetPlayerId != localPlayerId) {
          final targetName =
              gameState.playerById(pending.targetPlayerId)?.name ?? '…';
          return 'Esperando a que $targetName elija una carta…';
        }
        if (pending is PlayCatTrioAction && pending.playerId != localPlayerId) {
          final askerName = gameState.playerById(pending.playerId)?.name ?? '…';
          return 'Esperando a que $askerName elija una carta…';
        }
        return null;
      default:
        if (!isMyTurn) {
          return 'Turno de ${gameState.currentPlayer?.name ?? '…'}';
        }
        return null;
    }
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
      _NeedsTargetSelection(:final kind) => (
          switch (kind) {
            _TargetActionKind.favor => 'Favor seleccionado',
            _TargetActionKind.catPair => 'Par de gatos listo',
            _TargetActionKind.catTrio => 'Trío de gatos listo',
          },
          'Elegir objetivo',
          canAct ? onChooseTarget : null,
        ),
      _CatCardWaitingForPair() => (
          'Un gato solo no se puede jugar: toca otra carta igual para '
              'formar un par, o toca el mazo para robar y pasar el turno',
          'Jugar',
          null,
        ),
      _UnsupportedSelection() => (
          'Esta carta no se juega así — toca el mazo para robar y pasar '
              'el turno',
          'Jugar',
          null,
        ),
      _NoSelection() => ('', 'Jugar', null),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(message, style: AppTextStyles.caption),
          const SizedBox(height: 4),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 4,
            children: [
              TextButton(onPressed: onCancel, child: const Text('Cancelar')),
              FilledButton(
                onPressed: onConfirm,
                style:
                    FilledButton.styleFrom(backgroundColor: AppColors.success),
                child: Text(buttonLabel),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

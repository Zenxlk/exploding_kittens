import 'package:exploding_kittens/game_engine/models/card/card_model.dart';
import 'package:exploding_kittens/game_engine/models/card/card_type.dart';
import 'package:exploding_kittens/game_engine/models/deck/deck_model.dart';
import 'package:exploding_kittens/game_engine/models/game/game_config.dart';
import 'package:exploding_kittens/game_engine/models/game/game_result.dart';
import 'package:exploding_kittens/game_engine/models/game/game_state.dart';
import 'package:exploding_kittens/game_engine/models/player/player_model.dart';
import 'package:exploding_kittens/game_engine/models/player/player_status.dart';
import 'package:exploding_kittens/game_engine/models/turn/turn_action.dart';
import 'package:exploding_kittens/game_engine/models/turn/turn_model.dart';

/// Traduce entre el dialecto de red que habla el backend online
/// (`cards_game_service`) y los modelos Dart del motor — necesario solo para
/// el modo online. LAN sigue usando `GameState.toJson()`/`fromJson()` tal
/// cual (Dart hablándole a Dart, mismo dialecto en ambas puntas), sin pasar
/// por acá.
///
/// Dos motivos separados por los que hace falta este archivo, no uno solo:
///
/// 1. **`CardType`/`TurnPhase` van en `snake_case` en el motor Go**
///    (`games/explodingkittens/cards.go`/`state.go`), pero el `.name` nativo
///    de un enum Dart es `camelCase` (`CardType.explodingKitten.name` →
///    `"explodingKitten"`, no `"exploding_kitten"`). `CardModel.fromJson`/
///    `TurnModel.fromJson` (pensados solo para el `WsServer` de LAN,
///    Dart-a-Dart) revientan o comparan mal contra el JSON que manda/espera
///    el backend real — afecta a cualquier carta multi-palabra
///    (`explodingKitten`, `seeTheFuture`, `rainbowRalphingCat`,
///    `beardedDragon`, `hairyPotatoCat`) y a la mitad de las fases de turno
///    (`nopeWindow`, `drawRequired`, `awaitingCardChoice`), en las dos
///    direcciones: al leer el `game_state` que manda el servidor, y al
///    mandar una `action` que lleve una carta. El discriminante `type` de
///    cada `TurnAction`/`WsMessage` no tiene este problema — ya está escrito
///    en `snake_case` a mano en ambos lados (`'play_card'`, `'choose_card'`,
///    etc.), no sale de `.name`.
/// 2. **El `game_state` online es una proyección redactada** (`View` en
///    `games/explodingkittens/view.go`), no el `GameState` completo que
///    manda `WsServer` en LAN — a propósito, para no filtrar la mano de
///    los rivales a un cliente que no es de confianza. Sintetiza acá lo que
///    el `View` nunca manda: `config` (no viaja, no hace falta — ningún
///    método de `GameEngine` corre del lado remoto), el contenido real del
///    mazo (solo viaja `deckSize`), y las cartas concretas de la mano de
///    cada rival (solo viaja `handSize`).
// ── CardType / TurnPhase: conversión explícita, no genérica ────────────────
//
// Mapas explícitos en vez de un conversor camelCase↔snake_case genérico a
// propósito: son enums cerrados y chicos (13 y 6 valores), un mapa explícito
// documenta el contrato de wire real carta por carta en vez de asumir un
// patrón de nombres que podría dejar de cumplirse sin avisar.

const Map<CardType, String> _cardTypeToWire = {
  CardType.explodingKitten: 'exploding_kitten',
  CardType.defuse: 'defuse',
  CardType.nope: 'nope',
  CardType.attack: 'attack',
  CardType.skip: 'skip',
  CardType.favor: 'favor',
  CardType.shuffle: 'shuffle',
  CardType.seeTheFuture: 'see_the_future',
  CardType.tacocat: 'tacocat',
  CardType.rainbowRalphingCat: 'rainbow_ralphing_cat',
  CardType.beardedDragon: 'bearded_dragon',
  CardType.cattermelon: 'cattermelon',
  CardType.hairyPotatoCat: 'hairy_potato_cat',
};

final Map<String, CardType> _wireToCardType = {
  for (final entry in _cardTypeToWire.entries) entry.value: entry.key,
};

const Map<TurnPhase, String> _turnPhaseToWire = {
  TurnPhase.playing: 'playing',
  TurnPhase.nopeWindow: 'nope_window',
  TurnPhase.drawRequired: 'draw_required',
  TurnPhase.resolving: 'resolving',
  TurnPhase.ended: 'ended',
  TurnPhase.awaitingCardChoice: 'awaiting_card_choice',
};

final Map<String, TurnPhase> _wireToTurnPhase = {
  for (final entry in _turnPhaseToWire.entries) entry.value: entry.key,
};

CardModel _cardFromWire(Map<String, dynamic> json) {
  final wireType = json['type'] as String;
  final type = _wireToCardType[wireType];
  if (type == null) {
    throw FormatException('CardType desconocido del backend online: $wireType');
  }
  return CardModel(id: json['id'] as String, type: type);
}

Map<String, dynamic> _cardToWire(CardModel card) => {
      'id': card.id,
      'type': _cardTypeToWire[card.type]!,
    };

// Cartas cuya identidad real no importa: el motor remoto no corre del lado
// del cliente, así que ni `id` ni `type` se leen nunca para decidir nada —
// solo hacen falta para satisfacer campos `required` de los modelos. Nunca
// se renderizan como cara real: los consumidores de la mano de un rival
// (PlayersHudWidget, el `CardChoiceOverlay` a ciegas con `faceUp: false`)
// solo usan la cantidad, no el tipo.
int _placeholderSeq = 0;
CardModel _placeholderCard([String tag = 'placeholder']) =>
    CardModel(id: '_online_${tag}_${_placeholderSeq++}', type: CardType.defuse);

// ── Estado entrante: View (redactado) → GameState ───────────────────────────

/// Convierte el `game_state` que manda el backend online (la proyección
/// `View` de `games/explodingkittens/view.go`, ya redactada por el propio
/// servidor para esta conexión — no hace falta saber qué jugador es el
/// viewer acá, el servidor ya decidió a quién le manda la mano real) al
/// `GameState` que ya sabe dibujar el resto de la UI.
GameState gameStateFromOnlineView(Map<String, dynamic> json) {
  final players = (json['players'] as List)
      .map((p) => _playerFromWire(p as Map<String, dynamic>))
      .toList();

  final discardTopRaw = json['discardTop'] as Map<String, dynamic>?;
  final deckSize = json['deckSize'] as int;

  final resultRaw = json['result'] as Map<String, dynamic>?;
  final seeTheFutureRaw = json['seeTheFutureCards'] as List<dynamic>?;

  return GameState(
    id: json['id'] as String,
    // No viaja por privacidad (revelaría el seed de barajado) y ningún
    // método de GameEngine corre del lado remoto — placeholder inerte.
    config: GameConfig(playerCount: players.length),
    players: players,
    deck: DeckModel(
      drawPile: List.generate(deckSize, (i) => _placeholderCard('draw$i')),
      discardPile: discardTopRaw != null ? [_cardFromWire(discardTopRaw)] : [],
    ),
    turn: _turnFromWire(json['turn'] as Map<String, dynamic>),
    phase: GamePhase.values.byName(json['phase'] as String),
    pendingAction:
        _pendingActionFromWire(json['pendingAction'] as Map<String, dynamic>?),
    pendingBomb:
        (json['pendingBomb'] as bool) ? _placeholderCard('bomb') : null,
    seeTheFutureCards: seeTheFutureRaw
        ?.map((c) => _cardFromWire(c as Map<String, dynamic>))
        .toList(),
    result: resultRaw != null ? GameResult.fromJson(resultRaw) : null,
    turnCount: json['turnCount'] as int,
    eliminationOrder: (json['eliminationOrder'] as List).cast<String>(),
  );
}

PlayerModel _playerFromWire(Map<String, dynamic> json) {
  final id = json['id'] as String;
  final rawHand = json['hand'] as List<dynamic>?;
  // El servidor ya decidió si esta conexión es la dueña de esta mano — si
  // manda `hand`, es la propia; si no, solo `handSize` y hay que rellenar
  // con placeholders (ver el comentario de _placeholderCard).
  final hand = rawHand != null
      ? rawHand.map((c) => _cardFromWire(c as Map<String, dynamic>)).toList()
      : List.generate(
          json['handSize'] as int,
          (i) => _placeholderCard('${id}_hand$i'),
        );

  return PlayerModel(
    id: id,
    name: json['name'] as String,
    hand: hand,
    status: PlayerStatus.values.byName(json['status'] as String),
  );
}

TurnModel _turnFromWire(Map<String, dynamic> json) {
  final wirePhase = json['phase'] as String;
  final phase = _wireToTurnPhase[wirePhase];
  if (phase == null) {
    throw FormatException(
        'TurnPhase desconocida del backend online: $wirePhase');
  }
  return TurnModel(
    currentPlayerId: json['currentPlayerId'] as String,
    phase: phase,
    actionsLeft: json['actionsLeft'] as int,
    nopeChainCount: json['nopeChainCount'] as int,
  );
}

/// El `View.PendingAction` del servidor solo manda `type`/`playerId`/
/// `targetPlayerId` (nunca las cartas concretas, por privacidad) — alcanza
/// para lo único que la UI lee hoy de `pendingAction` (`GameTableView`
/// distingue Favor de trío de gatos por el tipo runtime, y lee
/// `playerId`/`targetPlayerId` de cada uno), pero obliga a rellenar el resto
/// de cada `TurnAction` con placeholders para poder construir la instancia.
TurnAction? _pendingActionFromWire(Map<String, dynamic>? json) {
  if (json == null) return null;
  final playerId = json['playerId'] as String;
  final targetPlayerId = json['targetPlayerId'] as String? ?? '';

  return switch (json['type'] as String) {
    'draw_card' => DrawCardAction(playerId: playerId),
    'play_card' => PlayCardAction(playerId: playerId, card: _placeholderCard()),
    'play_favor' => PlayFavorAction(
        playerId: playerId,
        card: _placeholderCard(),
        targetPlayerId: targetPlayerId,
      ),
    'play_cat_pair' => PlayCatPairAction(
        playerId: playerId,
        cards: List.generate(2, (_) => _placeholderCard()),
        targetPlayerId: targetPlayerId,
      ),
    'play_cat_trio' => PlayCatTrioAction(
        playerId: playerId,
        cards: List.generate(3, (_) => _placeholderCard()),
        targetPlayerId: targetPlayerId,
      ),
    'defuse_bomb' => DefuseBombAction(
        playerId: playerId,
        defuseCard: _placeholderCard(),
        insertAtPosition: 0,
      ),
    'nope' => NopeAction(playerId: playerId, nopeCard: _placeholderCard()),
    'choose_card' => ChooseCardAction(playerId: playerId, cardId: ''),
    _ => null,
  };
}

// ── Acciones salientes: TurnAction → JSON del backend online ────────────────

/// Igual que `TurnAction.toJson()`, pero recodificando el `type` de cada
/// `CardModel` embebida a `snake_case` — ver el punto 1 del comentario de
/// arriba. El discriminante `type` de la acción en sí ya es compatible tal
/// cual (`'play_card'`, `'choose_card'`, etc. ya están en snake_case en
/// `TurnAction.toJson()`).
Map<String, dynamic> turnActionToOnlineJson(TurnAction action) {
  return switch (action) {
    DrawCardAction() || ChooseCardAction() => action.toJson(),
    PlayCardAction(:final playerId, :final card) => {
        'type': 'play_card',
        'playerId': playerId,
        'card': _cardToWire(card),
      },
    PlayFavorAction(:final playerId, :final card, :final targetPlayerId) => {
        'type': 'play_favor',
        'playerId': playerId,
        'card': _cardToWire(card),
        'targetPlayerId': targetPlayerId,
      },
    PlayCatPairAction(:final playerId, :final cards, :final targetPlayerId) => {
        'type': 'play_cat_pair',
        'playerId': playerId,
        'cards': cards.map(_cardToWire).toList(),
        'targetPlayerId': targetPlayerId,
      },
    PlayCatTrioAction(:final playerId, :final cards, :final targetPlayerId) => {
        'type': 'play_cat_trio',
        'playerId': playerId,
        'cards': cards.map(_cardToWire).toList(),
        'targetPlayerId': targetPlayerId,
      },
    DefuseBombAction(
      :final playerId,
      :final defuseCard,
      :final insertAtPosition,
    ) =>
      {
        'type': 'defuse_bomb',
        'playerId': playerId,
        'defuseCard': _cardToWire(defuseCard),
        'insertAtPosition': insertAtPosition,
      },
    NopeAction(:final playerId, :final nopeCard) => {
        'type': 'nope',
        'playerId': playerId,
        'nopeCard': _cardToWire(nopeCard),
      },
  };
}

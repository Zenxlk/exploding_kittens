import 'package:equatable/equatable.dart';

/// Pesos de la función de evaluación heurística (`GameStateEvaluator`).
/// Deliberadamente `double` planos — nada de tipos Dart específicos — para
/// que la misma tabla de pesos sea re-describible tal cual en el futuro
/// puerto a Go (ver `docs/ARCHITECTURE.md`, sección "Motor de bots").
class BotWeights extends Equatable {
  const BotWeights({
    required this.survivalWeight,
    required this.defuseWeight,
    required this.escapeCardWeight,
    required this.infoWeight,
    required this.opponentPressureWeight,
  });

  /// Pondera `BotFeatures.explosionProbability` (0..1). Negativo: cuanto
  /// más alta la probabilidad de explotar, peor el estado.
  final double survivalWeight;

  /// Pondera `BotFeatures.defuseCount` — tener Defuse de sobra es bueno.
  final double defuseWeight;

  /// Pondera `BotFeatures.escapeCardCount` (Skip/Attack en mano).
  final double escapeCardWeight;

  /// Pondera `BotFeatures.hasSafeKnownDraw` (0 o 1) — saber que el tope del
  /// mazo no es una bomba, por Ver el Futuro.
  final double infoWeight;

  /// Pondera `BotFeatures.weakestOpponentHandSize` — negativo: un rival con
  /// pocas cartas está más cerca de quedarse sin recursos, presión a favor.
  final double opponentPressureWeight;

  static const standard = BotWeights(
    survivalWeight: -6,
    defuseWeight: 1.5,
    escapeCardWeight: 0.8,
    infoWeight: 0.5,
    opponentPressureWeight: -0.3,
  );

  @override
  List<Object?> get props => [
        survivalWeight,
        defuseWeight,
        escapeCardWeight,
        infoWeight,
        opponentPressureWeight,
      ];

  Map<String, dynamic> toJson() => {
        'survivalWeight': survivalWeight,
        'defuseWeight': defuseWeight,
        'escapeCardWeight': escapeCardWeight,
        'infoWeight': infoWeight,
        'opponentPressureWeight': opponentPressureWeight,
      };

  factory BotWeights.fromJson(Map<String, dynamic> j) => BotWeights(
        survivalWeight: (j['survivalWeight'] as num).toDouble(),
        defuseWeight: (j['defuseWeight'] as num).toDouble(),
        escapeCardWeight: (j['escapeCardWeight'] as num).toDouble(),
        infoWeight: (j['infoWeight'] as num).toDouble(),
        opponentPressureWeight: (j['opponentPressureWeight'] as num).toDouble(),
      );
}

/// Configuración del motor de bots — un único motor paramétrico, no
/// estrategias separadas: la dificultad sale de variar `determinizations`
/// (cuántas hipótesis de información oculta se muestrean por candidata,
/// ver `Determinizer`) y `temperature` (cuánto se aleja de siempre elegir
/// la de mayor puntaje), sobre los mismos pesos.
class BotConfig extends Equatable {
  const BotConfig({
    required this.weights,
    this.determinizations = 8,
    this.lookaheadDepth = 1,
    this.temperature = 0.15,
  })  : assert(determinizations > 0),
        assert(
          lookaheadDepth == 1,
          'Lookahead >1 todavía no está implementado — declarado para no '
          'migrar la firma pública el día que se agregue.',
        ),
        assert(temperature >= 0);

  final BotWeights weights;
  final int determinizations;
  final int lookaheadDepth;
  final double temperature;

  static const easy = BotConfig(
    weights: BotWeights.standard,
    determinizations: 3,
    temperature: 0.6,
  );
  static const normal = BotConfig(
    weights: BotWeights.standard,
    determinizations: 8,
    temperature: 0.15,
  );
  static const hard = BotConfig(
    weights: BotWeights.standard,
    determinizations: 16,
    temperature: 0.02,
  );

  @override
  List<Object?> get props =>
      [weights, determinizations, lookaheadDepth, temperature];

  Map<String, dynamic> toJson() => {
        'weights': weights.toJson(),
        'determinizations': determinizations,
        'lookaheadDepth': lookaheadDepth,
        'temperature': temperature,
      };

  factory BotConfig.fromJson(Map<String, dynamic> j) => BotConfig(
        weights: BotWeights.fromJson(j['weights'] as Map<String, dynamic>),
        determinizations: j['determinizations'] as int,
        lookaheadDepth: j['lookaheadDepth'] as int,
        temperature: (j['temperature'] as num).toDouble(),
      );
}

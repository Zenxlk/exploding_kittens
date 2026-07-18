import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:exploding_kittens/core/theme/app_colors.dart';
import 'package:exploding_kittens/core/theme/app_text_styles.dart';
import 'package:exploding_kittens/features/game/presentation/theme/card_visuals.dart';
import 'package:exploding_kittens/game_engine/models/card/card_type.dart';

/// Widget "tonto": no lee providers, solo recibe datos ya resueltos.
///
/// [assetPath] es la ruta ya resuelta por `CardAssetResolver` (null =
/// todavía no hay arte final, se dibuja el placeholder de [CardVisuals]).
class CardWidget extends StatefulWidget {
  const CardWidget({
    super.key,
    required this.type,
    this.faceUp = true,
    this.assetPath,
    this.isPlayable = false,
    this.isSelected = false,
    this.justDrawn = false,
    this.width = 72,
    this.onTap,
  });

  final CardType type;
  final bool faceUp;
  final String? assetPath;
  final bool isPlayable;
  final bool isSelected;
  // Distinto de `isPlayable` a propósito: una carta recién robada puede ya
  // ser jugable, y acoplar los dos efectos duplicaría o pisaría la
  // animación de entrada.
  final bool justDrawn;
  final double width;
  final VoidCallback? onTap;

  @override
  State<CardWidget> createState() => _CardWidgetState();
}

class _CardWidgetState extends State<CardWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flipController;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: widget.faceUp ? 1 : 0,
    );
  }

  @override
  void didUpdateWidget(covariant CardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.faceUp != widget.faceUp) {
      widget.faceUp ? _flipController.forward() : _flipController.reverse();
    }
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  double get _height => widget.width * 1.4;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _flipController,
        builder: (context, _) {
          final angle = (1 - _flipController.value) * math.pi;
          final showingFront = _flipController.value > 0.5;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0012)
              ..rotateY(angle),
            child: showingFront
                ? _CardFace(
                    type: widget.type,
                    assetPath: widget.assetPath,
                    isPlayable: widget.isPlayable,
                    isSelected: widget.isSelected,
                    justDrawn: widget.justDrawn,
                    width: widget.width,
                    height: _height,
                  )
                : Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(math.pi),
                    child: _CardBack(width: widget.width, height: _height),
                  ),
          );
        },
      ),
    );
  }
}

class _CardFace extends StatelessWidget {
  const _CardFace({
    required this.type,
    required this.assetPath,
    required this.isPlayable,
    required this.isSelected,
    required this.justDrawn,
    required this.width,
    required this.height,
  });

  final CardType type;
  final String? assetPath;
  final bool isPlayable;
  final bool isSelected;
  final bool justDrawn;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final (color, icon, label) = CardVisuals.of(type);

    final card = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected ? AppColors.warning : Colors.black38,
          width: isSelected ? 3 : 1,
        ),
        boxShadow: isPlayable
            ? [
                BoxShadow(
                  color: AppColors.success.withValues(alpha: 0.7),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: assetPath != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: Image.asset(assetPath!, fit: BoxFit.cover),
            )
          : Padding(
              padding: const EdgeInsets.all(6),
              // FittedBox absorbe el desborde vertical en tarjetas muy
              // angostas (mano en landscape phone); el SizedBox interior
              // fija el ancho de layout para que el texto siga ajustando a
              // 2 líneas en vez de perder el wrap al quedar sin restricción.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: SizedBox(
                  width: width - 12,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, color: Colors.white, size: width * 0.4),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.cardLabel,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );

    // Ambos efectos son de un solo uso (no en loop, a diferencia del glow
    // estático de arriba): cada uno se reproduce solo cuando su propia
    // rama se monta de nuevo (la condición pasa de falsa a verdadera), no
    // en cada rebuild — mismo truco para las dos, independientes entre sí.
    Widget result = card;
    if (isPlayable) {
      result = result.animate().scaleXY(
          begin: 0.92, end: 1, duration: 220.ms, curve: Curves.easeOut);
    }
    if (justDrawn) {
      result = result
          .animate()
          .fadeIn(duration: 300.ms)
          .slideY(begin: -0.3, end: 0, duration: 300.ms, curve: Curves.easeOut);
    }
    return result;
  }
}

class _CardBack extends StatelessWidget {
  const _CardBack({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.cardBack,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black38),
      ),
      child: Center(
        child: Icon(
          Icons.circle,
          color: Colors.white.withValues(alpha: 0.25),
          size: width * 0.3,
        ),
      ),
    );
  }
}

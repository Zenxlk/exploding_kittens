import 'package:flutter/material.dart';
import 'app_colors.dart';

// Bangers (letras estilo cómic/explosión) para títulos grandes; Baloo2
// (redondeada, legible en tamaños chicos) para todo lo demás. Ver
// assets/fonts/ATTRIBUTION.md.
abstract final class AppTextStyles {
  static const TextStyle headline = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: AppColors.onBackground,
    fontFamily: 'Bangers',
    letterSpacing: 1,
  );

  static const TextStyle title = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.onBackground,
    fontFamily: 'Baloo2',
  );

  static const TextStyle body = TextStyle(
    fontSize: 14,
    color: AppColors.onBackground,
    fontFamily: 'Baloo2',
  );

  static const TextStyle caption = TextStyle(
    fontSize: 11,
    color: AppColors.onBackground,
    fontFamily: 'Baloo2',
  );

  static const TextStyle cardLabel = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.bold,
    color: Colors.white,
    letterSpacing: 0.5,
    fontFamily: 'Baloo2',
  );
}

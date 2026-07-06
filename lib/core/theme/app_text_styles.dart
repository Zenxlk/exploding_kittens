import 'package:flutter/material.dart';
import 'app_colors.dart';

abstract final class AppTextStyles {
  static const TextStyle headline = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: AppColors.onBackground,
    fontFamily: 'ExplodingFont',
  );

  static const TextStyle title = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.onBackground,
  );

  static const TextStyle body = TextStyle(
    fontSize: 14,
    color: AppColors.onBackground,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 11,
    color: AppColors.onBackground,
  );

  static const TextStyle cardLabel = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.bold,
    color: Colors.white,
    letterSpacing: 0.5,
  );
}

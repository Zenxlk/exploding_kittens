import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:exploding_kittens/core/constants/layout_constants.dart';

extension BuildContextX on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get textTheme => Theme.of(this).textTheme;
  Size get screenSize => MediaQuery.sizeOf(this);
  double get screenWidth => MediaQuery.sizeOf(this).width;
  double get screenHeight => MediaQuery.sizeOf(this).height;
  bool get isLandscape =>
      MediaQuery.orientationOf(this) == Orientation.landscape;

  /// El lado más corto de la pantalla, sin importar la orientación actual.
  double get shortestSide => math.min(screenWidth, screenHeight);

  bool get isTablet =>
      shortestSide >= LayoutConstants.tabletShortSideBreakpoint;
}

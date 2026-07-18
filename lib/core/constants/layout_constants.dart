/// Umbrales y tamaños para el layout adaptativo de la pantalla de juego.
abstract final class LayoutConstants {
  /// Ancho del lado corto de la pantalla a partir del cual se considera
  /// "tablet" en vez de "phone". Se mide contra `shortestSide` (no contra
  /// `screenWidth` crudo) para que rotar un phone no lo haga cruzar el
  /// umbral por accidente. Alineado al corte compact/medium de Material 3.
  static const double tabletShortSideBreakpoint = 600;

  /// Ancho de carta en la mano del jugador local, por escenario.
  static const double handCardWidthPortraitPhone = 64;
  static const double handCardWidthLandscapePhone = 48;
  static const double handCardWidthTablet = 84;

  /// Separación horizontal entre el mazo y la pila de descarte.
  static const double deckDiscardGapPortrait = 24;
  static const double deckDiscardGapLandscape = 16;
}

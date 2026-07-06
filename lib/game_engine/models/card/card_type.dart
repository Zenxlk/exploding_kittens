enum CardType {
  // Especiales
  explodingKitten,
  defuse,
  nope,

  // Acciones
  attack,
  skip,
  favor,
  shuffle,
  seeTheFuture,

  // Gatos (pares/tríos para robar)
  tacocat,
  rainbowRalphingCat,
  beardedDragon,
  cattermelon,
  hairyPotatoCat;

  bool get isCatCard => switch (this) {
    tacocat ||
    rainbowRalphingCat ||
    beardedDragon ||
    cattermelon ||
    hairyPotatoCat => true,
    _ => false,
  };

  bool get isPlayable => this != explodingKitten && this != defuse;

  bool get requiresTarget => this == favor;
}

abstract final class AssetPaths {
  // Cartas
  static const String cards = 'assets/cards/';
  static String card(String name) => '${cards}$name.png';

  static const String cardBack = 'assets/cards/card_back.png';
  static const String explodingKitten = 'assets/cards/exploding_kitten.png';
  static const String defuse = 'assets/cards/defuse.png';
  static const String nope = 'assets/cards/nope.png';
  static const String attack = 'assets/cards/attack.png';
  static const String skip = 'assets/cards/skip.png';
  static const String favor = 'assets/cards/favor.png';
  static const String shuffle = 'assets/cards/shuffle.png';
  static const String seeTheFuture = 'assets/cards/see_the_future.png';

  // Gatos
  static const String tacocat = 'assets/cards/tacocat.png';
  static const String rainbowRalphingCat = 'assets/cards/rainbow_ralphing_cat.png';
  static const String beardedDragon = 'assets/cards/bearded_dragon.png';
  static const String cattermelon = 'assets/cards/cattermelon.png';
  static const String hairyPotatoCat = 'assets/cards/hairy_potato_cat.png';

  // Sonidos
  static const String soundCardDraw = 'sounds/card_draw.mp3';
  static const String soundCardPlay = 'sounds/card_play.mp3';
  static const String soundCardShuffle = 'sounds/card_shuffle.mp3';
  static const String soundExplosion = 'sounds/explosion.mp3';
  static const String soundDefuse = 'sounds/defuse.mp3';
  static const String soundNope = 'sounds/nope.mp3';
  static const String soundEliminated = 'sounds/player_eliminated.mp3';
  static const String soundBgm = 'sounds/bgm_game.mp3';

  // Animaciones Lottie
  static const String animExplosion = 'assets/animations/explosion.json';
  static const String animCardDraw = 'assets/animations/card_draw.json';
  static const String animVictory = 'assets/animations/victory.json';

  // Imágenes
  static const String logo = 'assets/images/logo.png';
  static const String backgroundTable = 'assets/images/background_table.png';
  static const String splashBg = 'assets/images/splash_bg.png';
}

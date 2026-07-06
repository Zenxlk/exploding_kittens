abstract final class AppConstants {
  static const String appName = 'Exploding Kittens';
  static const String company = 'ZenXLK';

  // Puerto WebSocket para partidas locales por WiFi
  static const int localGamePort = 8765;

  // mDNS service type para descubrimiento en red local
  static const String mdnsServiceType = '_explkittens._tcp';

  static const Duration splashDuration = Duration(seconds: 2);
}

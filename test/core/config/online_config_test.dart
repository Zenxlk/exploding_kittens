import 'package:exploding_kittens/core/config/online_config.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OnlineConfig', () {
    tearDown(dotenv.clean);

    test('isConfigured es false sin .env cargado', () {
      expect(OnlineConfig.isConfigured, isFalse);
    });

    test('isConfigured es false con ONLINE_SERVER_URL vacía', () {
      dotenv.loadFromString(envString: 'ONLINE_SERVER_URL=');
      expect(OnlineConfig.isConfigured, isFalse);
    });

    test('isConfigured es true con una URL configurada', () {
      dotenv.loadFromString(
        envString: 'ONLINE_SERVER_URL=https://example.run.app',
      );
      expect(OnlineConfig.isConfigured, isTrue);
    });

    test('httpUri arma la URL http(s) con el path dado', () {
      dotenv.loadFromString(
        envString: 'ONLINE_SERVER_URL=https://example.run.app',
      );
      expect(
        OnlineConfig.httpUri('/rooms').toString(),
        'https://example.run.app/rooms',
      );
    });

    test('wsUri mapea https a wss', () {
      dotenv.loadFromString(
        envString: 'ONLINE_SERVER_URL=https://example.run.app',
      );
      expect(
        OnlineConfig.wsUri('/ws/AB12CD').toString(),
        'wss://example.run.app/ws/AB12CD',
      );
    });

    test('wsUri mapea http a ws (pruebas locales)', () {
      dotenv.loadFromString(
        envString: 'ONLINE_SERVER_URL=http://localhost:8080',
      );
      expect(
        OnlineConfig.wsUri('/ws/AB12CD').toString(),
        'ws://localhost:8080/ws/AB12CD',
      );
    });
  });
}

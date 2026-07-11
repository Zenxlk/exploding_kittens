import 'package:exploding_kittens/core/audio/audio_service.dart';
import 'package:exploding_kittens/core/audio/i_audio_service.dart';
import 'package:exploding_kittens/core/constants/app_constants.dart';
import 'package:exploding_kittens/core/constants/asset_paths.dart';
import 'package:exploding_kittens/core/router/route_names.dart';
import 'package:exploding_kittens/features/splash/presentation/screens/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RecordingAudioService implements IAudioService {
  final List<String> musicCalls = [];

  @override
  Future<void> playEffect(String assetPath, {required double volume}) async {}

  @override
  Future<void> playMusic(
    String assetPath, {
    required bool enabled,
    required double volume,
  }) async {
    musicCalls.add(assetPath);
  }

  @override
  Future<void> stopMusic() async {}

  @override
  Future<void> pauseMusic() async {}

  @override
  Future<void> resumeMusic() async {}

  @override
  Future<void> dispose() async {}
}

// SplashScreen navega con go_router's context.go tras splashDuration, así
// que necesita un GoRouter real en el árbol.
Widget _wrap(_RecordingAudioService audioService) {
  final router = GoRouter(
    initialLocation: RouteNames.splash,
    routes: [
      GoRoute(
          path: RouteNames.splash, builder: (_, __) => const SplashScreen()),
      GoRoute(
        path: RouteNames.home,
        builder: (_, __) => const Scaffold(body: Text('home-screen')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [audioServiceProvider.overrideWithValue(audioService)],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SplashScreen', () {
    testWidgets('empieza a reproducir la música de menú al montarse', (
      tester,
    ) async {
      final audioService = _RecordingAudioService();
      await tester.pumpWidget(_wrap(audioService));
      await tester.pump();

      expect(audioService.musicCalls, contains(AssetPaths.musicMenu));

      // Deja que el Timer de navegación termine para no dejar timers
      // pendientes al final del test.
      await tester.pump(AppConstants.splashDuration);
      await tester.pumpAndSettle();
      expect(find.text('home-screen'), findsOneWidget);
    });
  });
}

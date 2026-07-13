import 'package:exploding_kittens/core/audio/audio_service.dart';
import 'package:exploding_kittens/core/audio/i_audio_service.dart';
import 'package:exploding_kittens/core/constants/app_constants.dart';
import 'package:exploding_kittens/core/constants/asset_paths.dart';
import 'package:exploding_kittens/core/router/route_names.dart';
import 'package:exploding_kittens/features/home/presentation/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

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

// HomeScreen navega con go_router's context.push, así que necesita un
// GoRouter real en el árbol (no solo un Navigator) para que los taps de los
// botones funcionen. También envuelto en ProviderScope: el botón "Cómo
// jugar" lleva a un RulesScreen real (un ConsumerWidget), no un stub, ya
// que es barato de renderizar.
Widget _wrapWithRouter({IAudioService? audioService}) {
  final router = GoRouter(
    initialLocation: RouteNames.home,
    routes: [
      GoRoute(path: RouteNames.home, builder: (_, __) => const HomeScreen()),
      GoRoute(
        path: RouteNames.createRoom,
        builder: (_, __) => const Scaffold(body: Text('createRoom-screen')),
      ),
      GoRoute(
        path: RouteNames.joinRoom,
        builder: (_, __) => const Scaffold(body: Text('joinRoom-screen')),
      ),
      GoRoute(
        path: RouteNames.settings,
        builder: (_, __) => const Scaffold(body: Text('settings-screen')),
      ),
      GoRoute(
        path: RouteNames.rules,
        builder: (_, __) => const Scaffold(body: Text('rules-screen')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      if (audioService != null)
        audioServiceProvider.overrideWithValue(audioService),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  group('HomeScreen', () {
    testWidgets('renders title, main actions and footer', (tester) async {
      await tester.pumpWidget(_wrapWithRouter());
      await tester.pumpAndSettle();

      expect(find.text(AppConstants.appName), findsOneWidget);
      expect(find.text('Crear sala'), findsOneWidget);
      expect(find.text('Unirse a sala'), findsOneWidget);
      expect(find.text('Cómo jugar'), findsOneWidget);
      expect(find.text('Ajustes'), findsOneWidget);
      expect(
        find.text('Proyecto de fans · Sin fines comerciales'),
        findsOneWidget,
      );
    });

    testWidgets('tapping "Crear sala" navigates to createRoom route',
        (tester) async {
      await tester.pumpWidget(_wrapWithRouter());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Crear sala'));
      await tester.pumpAndSettle();

      expect(find.text('createRoom-screen'), findsOneWidget);
    });

    testWidgets('tapping "Unirse a sala" navigates to joinRoom route',
        (tester) async {
      await tester.pumpWidget(_wrapWithRouter());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Unirse a sala'));
      await tester.pumpAndSettle();

      expect(find.text('joinRoom-screen'), findsOneWidget);
    });

    testWidgets('tapping "Ajustes" navigates to settings route',
        (tester) async {
      await tester.pumpWidget(_wrapWithRouter());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ajustes'));
      await tester.pumpAndSettle();

      expect(find.text('settings-screen'), findsOneWidget);
    });

    testWidgets('tapping "Cómo jugar" navigates to rules route',
        (tester) async {
      await tester.pumpWidget(_wrapWithRouter());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cómo jugar'));
      await tester.pumpAndSettle();

      expect(find.text('rules-screen'), findsOneWidget);
    });

    testWidgets('empieza a reproducir la música de menú al montarse', (
      tester,
    ) async {
      final audioService = _RecordingAudioService();
      await tester.pumpWidget(_wrapWithRouter(audioService: audioService));
      await tester.pumpAndSettle();

      expect(audioService.musicCalls, contains(AssetPaths.musicMenu));
    });
  });
}

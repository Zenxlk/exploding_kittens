import 'package:exploding_kittens/app.dart';
import 'package:exploding_kittens/core/audio/audio_service.dart';
import 'package:exploding_kittens/core/audio/i_audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RecordingAudioService implements IAudioService {
  final List<String> calls = [];

  @override
  Future<void> playEffect(String assetPath, {required double volume}) async {}

  @override
  Future<void> playMusic(
    String assetPath, {
    required bool enabled,
    required double volume,
  }) async {}

  @override
  Future<void> stopMusic() async {}

  @override
  Future<void> pauseMusic() async => calls.add('pause');

  @override
  Future<void> resumeMusic() async => calls.add('resume');

  @override
  Future<void> dispose() async {}
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('App', () {
    testWidgets(
      'pausa la música al pasar a segundo plano y la reanuda al volver',
      (tester) async {
        final audioService = _RecordingAudioService();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              audioServiceProvider.overrideWithValue(audioService),
            ],
            child: const App(),
          ),
        );
        await tester.pumpAndSettle();
        // Deja pasar el Timer de SplashScreen para no dejarlo pendiente.
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.paused,
        );
        expect(audioService.calls, ['pause']);

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        expect(audioService.calls, ['pause', 'resume']);
      },
    );

    testWidgets('el estado inactive no pausa ni reanuda nada', (
      tester,
    ) async {
      final audioService = _RecordingAudioService();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [audioServiceProvider.overrideWithValue(audioService)],
          child: const App(),
        ),
      );
      await tester.pumpAndSettle();
      // Deja pasar el Timer de SplashScreen para no dejarlo pendiente.
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.inactive,
      );
      expect(audioService.calls, isEmpty);
    });
  });
}

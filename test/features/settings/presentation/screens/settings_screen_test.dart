import 'package:exploding_kittens/features/settings/presentation/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrapWithProviders() {
  return const ProviderScope(
    child: MaterialApp(home: SettingsScreen()),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SettingsScreen', () {
    testWidgets('loads persisted settings and renders sections',
        (tester) async {
      await tester.pumpWidget(_wrapWithProviders());
      await tester.pumpAndSettle();

      expect(find.text('Ajustes'), findsOneWidget);
      expect(find.text('PERFIL'), findsOneWidget);
      expect(find.text('AUDIO'), findsOneWidget);
      expect(find.text('ACERCA DE'), findsOneWidget);
      expect(find.text('Nombre de jugador'), findsOneWidget);
      expect(find.text('Efectos de sonido'), findsOneWidget);
      expect(find.text('Música de fondo'), findsOneWidget);

      final nameField = tester.widget<TextField>(find.byType(TextField));
      expect(nameField.controller!.text, 'Jugador');
    });

    testWidgets('submitting a new player name persists it', (tester) async {
      await tester.pumpWidget(_wrapWithProviders());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Zen');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('settings_player_name'), 'Zen');
    });

    testWidgets('toggling sound switch updates state and hides the slider',
        (tester) async {
      await tester.pumpWidget(_wrapWithProviders());
      await tester.pumpAndSettle();

      // Slider is visible while sound is enabled (default).
      expect(find.byType(Slider), findsOneWidget);

      // "Efectos de sonido" is the first Switch in the list, before
      // "Música de fondo".
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      expect(find.byType(Slider), findsNothing);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('settings_sound_enabled'), false);
    });
  });
}

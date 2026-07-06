import 'package:exploding_kittens/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App smoke test — arranca sin errores', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: App()),
    );
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}

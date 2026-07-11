import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/audio/audio_service.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

/// Pausa/reanuda la música de fondo con el ciclo de vida de la app — sin
/// esto, minimizar o cerrar la app dejaba la música sonando de fondo
/// (`AudioService`/`audioplayers` no se enteran solos de que la app ya no
/// está visible). Vive en la raíz porque aplica a cualquier pantalla, no
/// solo a las que ya manejan su propia música (`GameScreen`/`GameOverScreen`
/// siguen cortando la suya al salir, sin cambios ahí).
class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final audioService = ref.read(audioServiceProvider);
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        audioService.pauseMusic();
      case AppLifecycleState.resumed:
        audioService.resumeMusic();
      case AppLifecycleState.inactive:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Exploding Kittens',
      theme: AppTheme.dark,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}

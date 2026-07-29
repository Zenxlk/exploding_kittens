import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Lee las credenciales de Supabase desde `.env` (cargado por
/// [loadDotEnvIfPresent] antes de leer nada de acá). Ausentes o vacías
/// significa "sin Supabase configurado": la app entera sigue funcionando en
/// modo invitado, sin ramas especiales en el resto del código — ver
/// `docs/ARCHITECTURE.md`, sección "Autenticación con Supabase (Fase 7)".
abstract final class SupabaseConfig {
  // dotenv.get() lanza NotInitializedError si nadie llamó a load() todavía
  // (p. ej. en tests, que nunca corren main()) — sin este chequeo, leer
  // isConfigured antes de loadDotEnvIfPresent() tira la app/el test abajo
  // en vez de simplemente reportar "no configurado".
  static String get url =>
      dotenv.isInitialized ? dotenv.get('SUPABASE_URL', fallback: '') : '';
  static String get anonKey =>
      dotenv.isInitialized ? dotenv.get('SUPABASE_ANON_KEY', fallback: '') : '';

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;

  /// Intenta cargar `.env` (declarado como asset en `pubspec.yaml`). Si el
  /// archivo no existe — build sin `.env` local, o CI sin secretos reales —
  /// [dotenv] queda vacío y [isConfigured] da `false` en vez de tirar la
  /// app abajo: `.env` es opcional por diseño, no un requisito de build.
  static Future<void> loadDotEnvIfPresent() async {
    try {
      await dotenv.load();
    } catch (_) {
      // Sin .env: modo invitado, ver comentario de la clase.
    }
  }
}

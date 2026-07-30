import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Lee la URL base del backend online (`cards_game_service`) desde `.env`
/// (cargado por `SupabaseConfig.loadDotEnvIfPresent` antes de leer nada de
/// acá). Ausente o vacía significa "sin backend online configurado": el
/// modo online no aparece como opción en la UI y la app sigue funcionando
/// 100% LAN/invitado, igual que hoy — ver `docs/ARCHITECTURE.md`, sección
/// "Autenticación con Supabase", y la issue de modo online del lado
/// cliente.
///
/// No hay una URL por defecto a propósito: el backend no está atado a
/// ninguna instancia en particular (cualquiera puede desplegar la suya,
/// ver `cards_game_service/docs/DEPLOYMENT.md`), así que hardcodear acá el
/// despliegue personal de un mantenedor acoplaría el cliente público a esa
/// única instancia.
abstract final class OnlineConfig {
  static String get baseUrl =>
      dotenv.isInitialized ? dotenv.get('ONLINE_SERVER_URL', fallback: '') : '';

  static bool get isConfigured => baseUrl.isNotEmpty;

  /// URL http(s) para un path relativo (ej. `POST /rooms`).
  static Uri httpUri(String path) => Uri.parse(baseUrl).replace(path: path);

  /// URL ws(s) para un path relativo (ej. `GET /ws/{code}`), mapeando el
  /// esquema http(s) de [baseUrl] a su equivalente ws(s) — así
  /// `ONLINE_SERVER_URL` solo necesita declararse una vez, con el esquema
  /// http(s) normal de cualquier URL de backend.
  static Uri wsUri(String path) {
    final http = Uri.parse(baseUrl);
    final wsScheme = http.scheme == 'https' ? 'wss' : 'ws';
    return http.replace(scheme: wsScheme, path: path);
  }
}

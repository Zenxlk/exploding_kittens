import 'package:flutter/foundation.dart';

enum LogLevel { debug, info, warning, error }

abstract final class AppLogger {
  static void debug(String msg, {String? tag}) =>
      _log(LogLevel.debug, msg, tag: tag);

  static void info(String msg, {String? tag}) =>
      _log(LogLevel.info, msg, tag: tag);

  static void warning(String msg, {String? tag}) =>
      _log(LogLevel.warning, msg, tag: tag);

  static void error(String msg, {Object? error, StackTrace? stack, String? tag}) {
    _log(LogLevel.error, msg, tag: tag);
    if (error != null) debugPrint('  error: $error');
    if (stack != null) debugPrint('  stack: $stack');
  }

  static void _log(LogLevel level, String msg, {String? tag}) {
    if (!kDebugMode) return;
    final prefix = switch (level) {
      LogLevel.debug => '[D]',
      LogLevel.info => '[I]',
      LogLevel.warning => '[W]',
      LogLevel.error => '[E]',
    };
    final label = tag != null ? '[$tag]' : '';
    debugPrint('$prefix$label $msg');
  }
}

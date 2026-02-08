import 'package:flutter/foundation.dart';

class SikaLogger {
  static void info(String message, {String? tag}) {
    _log('INFO', message, tag);
  }

  static void warn(String message, {String? tag}) {
    _log('WARN', message, tag);
  }

  static void error(String message, {String? tag, dynamic error}) {
    _log('ERROR', message, tag, error: error);
  }

  static void _log(String level, String message, String? tag, {dynamic error}) {
    final timestamp = DateTime.now().toIso8601String();
    final tagStr = tag != null ? '[$tag] ' : '';
    final sanitizedMessage = _sanitize(message);
    
    debugPrint('$timestamp $level $tagStr$sanitizedMessage');
    if (error != null) {
      debugPrint('Error details: $error');
    }
  }

  static String _sanitize(String message) {
    // Masquer les secrets potentiels (tokens, keys, etc.)
    final secrets = RegExp(r'(token|key|secret|password|auth|anonKey)[\s:=]+([^\s,]+)', caseSensitive: false);
    return message.replaceAllMapped(secrets, (match) => '${match.group(1)}: [REDACTED]');
  }
}

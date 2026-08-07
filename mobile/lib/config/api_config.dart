import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

class ApiConfig {
  static const _prefsKey = 'backend_host';

  static String _host = '';

  /// Default host:port depending on platform.
  static String get defaultHost {
    if (Platform.isAndroid) return '192.168.1.106:3000';
    if (Platform.isIOS) return '127.0.0.1:3000';
    return 'localhost:3000';
  }

  /// Current host:port (without http /api).
  static String get host => _host.isEmpty ? defaultHost : _host;

  /// Full API base URL, e.g. http://192.168.1.10:3000/api
  static String get baseUrl => 'http://$host/api';

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _host = prefs.getString(_prefsKey) ?? '';
  }

  /// Accepts IP, host:port, or full URL like http://192.168.1.10:3000/api
  static Future<void> setHost(String input) async {
    final normalized = normalizeHost(input);
    if (normalized.isEmpty) {
      throw Exception('عنوان السيرفر غير صالح');
    }
    _host = normalized;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, _host);
  }

  static Future<void> resetToDefault() async {
    _host = '';
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }

  static String normalizeHost(String raw) {
    var value = raw.trim();
    if (value.isEmpty) return '';

    value = value.replaceAll(RegExp(r'\s+'), '');
    value = value.replaceFirst(RegExp(r'^https?://', caseSensitive: false), '');
    value = value.replaceFirst(RegExp(r'/api/?$', caseSensitive: false), '');
    value = value.replaceFirst(RegExp(r'/$'), '');

    // If user entered only IP / hostname, append default port.
    if (!value.contains(':')) {
      value = '$value:3000';
    }

    // Basic validation: host:port
    final parts = value.split(':');
    if (parts.length != 2) return '';
    final port = int.tryParse(parts[1]);
    if (port == null || port < 1 || port > 65535) return '';
    if (parts[0].isEmpty) return '';

    return value;
  }
}

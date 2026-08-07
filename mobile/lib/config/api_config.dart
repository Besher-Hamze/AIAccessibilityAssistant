import 'dart:io';

class ApiConfig {
  static String get baseUrl {
    if (Platform.isAndroid) {
      return 'http://192.168.1.106:3000/api';
    }
    if (Platform.isIOS) {
      return 'http://127.0.0.1:3000/api';
    }
    return 'http://localhost:3000/api';
  }
}

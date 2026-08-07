import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AccessibilityProvider extends ChangeNotifier {
  bool highContrast = false;
  bool largeControls = true;
  bool tapToTalk = true;
  bool autoSpeak = true;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    highContrast = prefs.getBool('a11y_high_contrast') ?? false;
    largeControls = prefs.getBool('a11y_large_controls') ?? true;
    tapToTalk = prefs.getBool('a11y_tap_to_talk') ?? true;
    autoSpeak = prefs.getBool('a11y_auto_speak') ?? true;
    notifyListeners();
  }

  Future<void> _save(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> setHighContrast(bool value) async {
    highContrast = value;
    await _save('a11y_high_contrast', value);
    notifyListeners();
  }

  Future<void> setLargeControls(bool value) async {
    largeControls = value;
    await _save('a11y_large_controls', value);
    notifyListeners();
  }

  Future<void> setTapToTalk(bool value) async {
    tapToTalk = value;
    await _save('a11y_tap_to_talk', value);
    notifyListeners();
  }

  Future<void> setAutoSpeak(bool value) async {
    autoSpeak = value;
    await _save('a11y_auto_speak', value);
    notifyListeners();
  }

  double get scale => largeControls ? 1.15 : 1.0;
  double get minTouch => largeControls ? 56 : 48;
}

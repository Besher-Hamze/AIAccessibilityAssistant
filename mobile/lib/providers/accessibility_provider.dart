import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AccessibilityProvider extends ChangeNotifier {
  static const defaultSpeechRate = 0.5;

  bool highContrast = false;
  bool largeControls = true;
  bool autoSpeak = true;

  /// The assistant keeps listening after each answer — no touch needed.
  bool handsFree = true;

  /// After a quiet period the assistant sleeps and waits for "يا مساعد".
  bool autoSleep = true;

  double speechRate = defaultSpeechRate;

  bool _loaded = false;
  bool get loaded => _loaded;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    highContrast = prefs.getBool('a11y_high_contrast') ?? false;
    largeControls = prefs.getBool('a11y_large_controls') ?? true;
    autoSpeak = prefs.getBool('a11y_auto_speak') ?? true;
    handsFree = prefs.getBool('a11y_hands_free') ?? true;
    autoSleep = prefs.getBool('a11y_auto_sleep') ?? true;
    speechRate = prefs.getDouble('a11y_speech_rate') ?? defaultSpeechRate;
    _loaded = true;
    notifyListeners();
  }

  Future<void> _save(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> setHighContrast(bool value) async {
    highContrast = value;
    notifyListeners();
    await _save('a11y_high_contrast', value);
  }

  Future<void> setLargeControls(bool value) async {
    largeControls = value;
    notifyListeners();
    await _save('a11y_large_controls', value);
  }

  Future<void> setAutoSpeak(bool value) async {
    autoSpeak = value;
    notifyListeners();
    await _save('a11y_auto_speak', value);
  }

  Future<void> setHandsFree(bool value) async {
    handsFree = value;
    notifyListeners();
    await _save('a11y_hands_free', value);
  }

  Future<void> setAutoSleep(bool value) async {
    autoSleep = value;
    notifyListeners();
    await _save('a11y_auto_sleep', value);
  }

  Future<void> setSpeechRate(double value) async {
    speechRate = value.clamp(0.2, 0.9);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('a11y_speech_rate', speechRate);
  }

  double get scale => largeControls ? 1.15 : 1.0;
  double get minTouch => largeControls ? 56 : 48;
}

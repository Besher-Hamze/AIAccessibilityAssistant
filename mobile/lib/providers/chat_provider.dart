import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/chat_message.dart';
import '../services/api_service.dart';
import '../services/windows_speech.dart';
import '../utils/speech_text.dart';

class ChatProvider extends ChangeNotifier {
  static const _modelPrefsKey = 'ollama_model';

  final ApiService _api;
  final FlutterTts _tts = FlutterTts();

  /// On Windows speech comes from the server's Edge voice instead of flutter_tts.
  final WindowsSpeech? _windowsSpeech = Platform.isWindows ? WindowsSpeech() : null;

  List<ChatMessage> _messages = [];
  List<String> _availableModels = [];
  String? _selectedModel;
  bool _isProcessing = false;
  bool _isSpeaking = false;
  String? _speakingText;
  bool _autoSpeak = true;
  bool _modelsLoading = false;
  bool _ttsReady = false;
  String? _error;
  double _speechRate = 0.5;
  Completer<void>? _speechDone;

  String? _lastGender;
  String? _lastToolUsed;
  DateTime? _speechAudioAt;

  ChatProvider(this._api) {
    _initTts();
    _restoreSelectedModel();
  }

  List<ChatMessage> get messages => _messages;
  List<String> get availableModels => _availableModels;
  String? get selectedModel => _selectedModel;
  bool get isProcessing => _isProcessing;
  bool get isSpeaking => _isSpeaking;
  String? get speakingText => _speakingText;
  bool get autoSpeak => _autoSpeak;
  bool get modelsLoading => _modelsLoading;
  String? get error => _error;
  String? get lastToolUsed => _lastToolUsed;

  /// When the current reply's audio started (or is about to start) playing.
  /// Barge-in detection uses it to learn the speaker echo level first.
  DateTime? get speechAudioAt => _speechAudioAt;

  /// Extra time before audio is actually audible after [speechAudioAt]
  /// (PowerShell + media player startup on Windows).
  Duration get speechAudioWarmup => _windowsSpeech != null
      ? const Duration(milliseconds: 1800)
      : const Duration(milliseconds: 700);

  String? get lastAssistantReply {
    for (final m in _messages.reversed) {
      if (m.isAssistant && !m.isLoading) return m.content;
    }
    return null;
  }

  Future<void> _initTts() async {
    if (_windowsSpeech != null) return;
    try {
      await _tts.setSpeechRate(_speechRate);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      await _tts.awaitSpeakCompletion(true);

      final languages = await _tts.getLanguages;
      final langList = (languages is List)
          ? languages.map((e) => e.toString()).toList()
          : <String>[];

      String? arabic;
      for (final candidate in ['ar-SA', 'ar-EG', 'ar-AE', 'ar', 'ar_SA', 'ar_EG']) {
        if (langList.any((l) => l.toLowerCase() == candidate.toLowerCase())) {
          arabic = candidate;
          break;
        }
      }
      arabic ??= langList.firstWhere(
        (l) => l.toLowerCase().startsWith('ar'),
        orElse: () => 'ar',
      );
      await _tts.setLanguage(arabic);

      if (Platform.isAndroid) {
        await _tts.setQueueMode(1);
      }

      _tts.setStartHandler(() {
        _isSpeaking = true;
        _speechAudioAt = DateTime.now();
        notifyListeners();
      });
      _tts.setCompletionHandler(() {
        _isSpeaking = false;
        _speakingText = null;
        _completeSpeech();
        notifyListeners();
      });
      _tts.setCancelHandler(() {
        _isSpeaking = false;
        _speakingText = null;
        _completeSpeech();
        notifyListeners();
      });
      _tts.setErrorHandler((msg) {
        _isSpeaking = false;
        _speakingText = null;
        _completeSpeech();
        _error = 'تعذر تشغيل الصوت على الجهاز';
        notifyListeners();
        if (kDebugMode) debugPrint('TTS error: $msg');
      });

      _ttsReady = true;
    } catch (e) {
      _ttsReady = false;
      if (kDebugMode) debugPrint('TTS init failed: $e');
    }
  }

  void _completeSpeech() {
    final done = _speechDone;
    _speechDone = null;
    if (done != null && !done.isCompleted) done.complete();
  }

  Future<void> setSpeechRate(double rate) async {
    _speechRate = rate;
    if (_windowsSpeech != null) return;
    try {
      await _tts.setSpeechRate(rate);
    } catch (_) {}
  }

  Future<void> _restoreSelectedModel() async {
    final prefs = await SharedPreferences.getInstance();
    _selectedModel = prefs.getString(_modelPrefsKey);
    notifyListeners();
  }

  Future<void> loadModels() async {
    _modelsLoading = true;
    notifyListeners();
    try {
      final data = await _api.getAiModels();
      final models = (data['models'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .toList();
      _availableModels = models;

      final current = data['current']?.toString();
      if (_selectedModel == null ||
          (_selectedModel!.isNotEmpty &&
              models.isNotEmpty &&
              !models.contains(_selectedModel))) {
        _selectedModel = models.contains(current)
            ? current
            : (models.isNotEmpty ? models.first : current);
        if (_selectedModel != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_modelPrefsKey, _selectedModel!);
        }
      }
    } catch (_) {}
    _modelsLoading = false;
    notifyListeners();
  }

  Future<void> setSelectedModel(String? model) async {
    if (model == null || model.isEmpty || model == _selectedModel) return;
    _selectedModel = model;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modelPrefsKey, model);
    notifyListeners();
  }

  Future<void> toggleAutoSpeak() async {
    if (_isSpeaking) {
      await stopSpeaking();
    }
    _autoSpeak = !_autoSpeak;
    notifyListeners();
  }

  void setAutoSpeak(bool value) {
    if (_autoSpeak == value) return;
    _autoSpeak = value;
    if (!value) {
      stopSpeaking();
    }
    notifyListeners();
  }

  Future<void> loadHistory() async {
    try {
      final history = await _api.getChatHistory();
      _messages = history
          .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
          .toList();
      notifyListeners();
    } catch (_) {}
  }

  Future<bool> clearHistory() async {
    await stopSpeaking();
    try {
      await _api.clearChatHistory();
      _messages = [];
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  /// Returns true when a write tool was executed (so UI can refresh data).
  Future<bool> sendTextMessage(
    String text, {
    String? speakerGender,
    String? speakerGenderAr,
    double? confidence,
  }) async {
    if (text.trim().isEmpty || _isProcessing) return false;

    final userMsg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: 'user',
      content: text.trim(),
      createdAt: DateTime.now(),
      speakerGender: speakerGender,
      speakerGenderAr: speakerGenderAr,
      confidence: confidence,
    );

    final loadingMsg = ChatMessage(
      id: 'loading',
      role: 'assistant',
      content: 'جاري المعالجة...',
      createdAt: DateTime.now(),
      isLoading: true,
    );

    _messages.add(userMsg);
    _messages.add(loadingMsg);
    _isProcessing = true;
    _error = null;
    _lastToolUsed = null;
    if (speakerGender != null) _lastGender = speakerGender;
    notifyListeners();

    var mutated = false;
    try {
      final result = await _api.chat(text.trim(), model: _selectedModel);
      _messages.removeWhere((m) => m.id == 'loading');

      final reply = result['reply'] as String? ?? 'تم.';
      final tool = result['toolUsed'] as String?;
      _lastToolUsed = tool;
      mutated = tool != null &&
          (tool.startsWith('create_') ||
              tool.startsWith('update_') ||
              tool.contains('invoice') ||
              tool.contains('stock'));

      _messages.add(ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        role: 'assistant',
        content: reply,
        createdAt: DateTime.now(),
        toolUsed: tool,
        intent: result['intent']?.toString(),
      ));

      _isProcessing = false;
      notifyListeners();
      if (_autoSpeak) {
        await _speak(reply);
      }
    } catch (e) {
      _messages.removeWhere((m) => m.id == 'loading');
      _error = e.toString().replaceAll('Exception: ', '');
      _messages.add(ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        role: 'assistant',
        content: 'عذراً، حدث خطأ. تأكد من تشغيل الخادم و Ollama.',
        createdAt: DateTime.now(),
      ));
    }

    _isProcessing = false;
    notifyListeners();
    return mutated;
  }

  /// Sends a recorded WAV file to Whisper. Returns text + speaker info.
  Future<Map<String, dynamic>> transcribe(String path) async {
    final stt = await _api.speechToText(File(path));
    return stt;
  }

  /// Adds a locally handled exchange (no LLM) to the transcript and speaks it.
  Future<void> say(String reply, {String? userText, bool force = false}) async {
    final now = DateTime.now();
    if (userText != null && userText.trim().isNotEmpty) {
      _messages.add(ChatMessage(
        id: 'local_u_${now.microsecondsSinceEpoch}',
        role: 'user',
        content: userText.trim(),
        createdAt: now,
      ));
    }
    _messages.add(ChatMessage(
      id: 'local_a_${now.microsecondsSinceEpoch}',
      role: 'assistant',
      content: reply,
      createdAt: now,
      intent: 'local',
    ));
    notifyListeners();
    if (_autoSpeak || force) await _speak(reply);
  }

  /// Drops the in-memory transcript (e.g. on logout).
  void resetSession() {
    stopSpeaking();
    _messages = [];
    _error = null;
    notifyListeners();
  }

  /// Speaks [text] even if auto-speak is off (used for confirmations).
  Future<void> speakNow(String text) => _speak(text);

  Future<void> _speak(String text) async {
    final original = text.trim();
    if (original.isEmpty) return;

    final cleaned = sanitizeForSpeech(original);
    if (cleaned.isEmpty) return;

    final windows = _windowsSpeech;
    if (windows != null) {
      await _speakOnWindows(windows, original, cleaned);
      return;
    }

    if (!_ttsReady) {
      await _initTts();
    }

    try {
      await stopSpeaking();
      final female = _lastGender == 'female';
      await _tts.setPitch(female ? 1.18 : 0.95);
      _speakingText = original;
      _isSpeaking = true;
      final done = Completer<void>();
      _speechDone = done;
      _speechAudioAt = DateTime.now();
      notifyListeners();
      await _tts.speak(cleaned);
      // Some platforms return before speech ends; wait for the completion handler.
      final maxWait = Duration(milliseconds: 1500 + cleaned.length * 140);
      await done.future.timeout(maxWait, onTimeout: () {});
      if (_isSpeaking && _speakingText == original) {
        _isSpeaking = false;
        _speakingText = null;
        notifyListeners();
      }
    } catch (e) {
      _isSpeaking = false;
      _speakingText = null;
      _completeSpeech();
      _error = 'تعذر تشغيل الصوت. تأكد من وجود صوت عربي في إعدادات الجهاز.';
      notifyListeners();
      if (kDebugMode) debugPrint('TTS speak failed: $e');
    }
  }

  Future<void> _speakOnWindows(WindowsSpeech windows, String original, String cleaned) async {
    await stopSpeaking();
    _speakingText = original;
    _isSpeaking = true;
    _speechAudioAt = null;
    notifyListeners();
    try {
      final mp3 = await _api.textToSpeech(cleaned);
      // Stopped (or replaced) while the audio was being generated.
      if (_speakingText != original) return;
      _speechAudioAt = DateTime.now();
      // speechRate 0.5 is normal speed.
      await windows.play(mp3, speed: (0.5 + _speechRate).clamp(0.6, 1.5));
    } catch (e) {
      _error = 'تعذر تشغيل الصوت. تأكد من تشغيل خدمة الصوت.';
      if (kDebugMode) debugPrint('Windows TTS failed: $e');
    } finally {
      if (_speakingText == original) {
        _isSpeaking = false;
        _speakingText = null;
        notifyListeners();
      }
    }
  }

  Future<void> speakMessage(String text) async {
    if (_isSpeaking && _speakingText == text) {
      await stopSpeaking();
      return;
    }
    await _speak(text);
  }

  Future<void> stopSpeaking() async {
    try {
      final windows = _windowsSpeech;
      if (windows != null) {
        await windows.stop();
      } else {
        await _tts.stop();
      }
    } catch (_) {}
    _completeSpeech();
    if (_isSpeaking || _speakingText != null) {
      _isSpeaking = false;
      _speakingText = null;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    stopSpeaking();
    super.dispose();
  }
}

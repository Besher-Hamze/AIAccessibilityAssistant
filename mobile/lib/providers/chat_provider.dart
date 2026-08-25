import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/chat_message.dart';
import '../services/api_service.dart';
import '../utils/speech_text.dart';

class ChatProvider extends ChangeNotifier {
  static const _modelPrefsKey = 'ollama_model';

  final ApiService _api;
  final AudioRecorder _recorder = AudioRecorder();
  final FlutterTts _tts = FlutterTts();

  List<ChatMessage> _messages = [];
  List<String> _availableModels = [];
  String? _selectedModel;
  bool _isRecording = false;
  bool _isProcessing = false;
  bool _isSpeaking = false;
  String? _speakingText;
  bool _autoSpeak = true;
  bool _modelsLoading = false;
  bool _ttsReady = false;
  String? _error;

  String? _lastGender;

  ChatProvider(this._api) {
    _initTts();
    _restoreSelectedModel();
  }

  List<ChatMessage> get messages => _messages;
  List<String> get availableModels => _availableModels;
  String? get selectedModel => _selectedModel;
  bool get isRecording => _isRecording;
  bool get isProcessing => _isProcessing;
  bool get isSpeaking => _isSpeaking;
  String? get speakingText => _speakingText;
  bool get autoSpeak => _autoSpeak;
  bool get modelsLoading => _modelsLoading;
  String? get error => _error;

  Future<void> _initTts() async {
    try {
      await _tts.setSpeechRate(0.45);
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
        notifyListeners();
      });
      _tts.setCompletionHandler(() {
        _isSpeaking = false;
        _speakingText = null;
        notifyListeners();
      });
      _tts.setCancelHandler(() {
        _isSpeaking = false;
        _speakingText = null;
        notifyListeners();
      });
      _tts.setErrorHandler((msg) {
        _isSpeaking = false;
        _speakingText = null;
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
    notifyListeners();

    var mutated = false;
    try {
      final result = await _api.chat(text.trim(), model: _selectedModel);
      _messages.removeWhere((m) => m.id == 'loading');

      final reply = result['reply'] as String? ?? 'تم.';
      final tool = result['toolUsed'] as String?;
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
      ));

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

  Future<void> startRecording() async {
    if (_isRecording || _isProcessing) return;

    if (!await _recorder.hasPermission()) {
      _error = 'يجب السماح بالوصول للميكروفون';
      notifyListeners();
      return;
    }

    // Stop TTS so mic can capture cleanly.
    await stopSpeaking();

    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.wav';

    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.wav, sampleRate: 16000),
      path: path,
    );

    _isRecording = true;
    _error = null;
    notifyListeners();
  }

  Future<void> stopRecordingAndSend() async {
    if (!_isRecording) return;

    final path = await _recorder.stop();
    _isRecording = false;
    notifyListeners();

    if (path == null) return;

    _isProcessing = true;
    notifyListeners();

    try {
      final stt = await _api.speechToText(File(path));
      final text = (stt['text'] as String? ?? '').trim();
      if (text.isEmpty) {
        _error = 'لم يتم التعرف على الكلام. حاول مرة أخرى في مكان أكثر هدوءاً.';
        _isProcessing = false;
        notifyListeners();
        return;
      }
      _lastGender = stt['gender']?.toString();
      _isProcessing = false;
      await sendTextMessage(
        text,
        speakerGender: stt['gender']?.toString(),
        speakerGenderAr: stt['gender_ar']?.toString(),
        confidence: (stt['confidence'] as num?)?.toDouble(),
      );
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _isProcessing = false;
      notifyListeners();
    }
  }

  Future<void> _speak(String text) async {
    final original = text.trim();
    if (original.isEmpty) return;

    final cleaned = sanitizeForSpeech(original);
    if (cleaned.isEmpty) return;

    if (!_ttsReady) {
      await _initTts();
    }

    try {
      await stopSpeaking();
      final female = _lastGender == 'female';
      await _tts.setPitch(female ? 1.18 : 0.95);
      _speakingText = original;
      _isSpeaking = true;
      notifyListeners();
      await _tts.speak(cleaned);
    } catch (e) {
      _isSpeaking = false;
      _speakingText = null;
      _error = 'تعذر تشغيل الصوت. تأكد من وجود صوت عربي في إعدادات الجهاز.';
      notifyListeners();
      if (kDebugMode) debugPrint('TTS speak failed: $e');
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
      await _tts.stop();
    } catch (_) {}
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
    _recorder.dispose();
    _tts.stop();
    super.dispose();
  }
}

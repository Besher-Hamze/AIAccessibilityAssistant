import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../models/chat_message.dart';
import '../services/api_service.dart';

class ChatProvider extends ChangeNotifier {
  final ApiService _api;
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();

  List<ChatMessage> _messages = [];
  bool _isRecording = false;
  bool _isProcessing = false;
  bool _autoSpeak = true;
  String? _error;

  ChatProvider(this._api);

  List<ChatMessage> get messages => _messages;
  bool get isRecording => _isRecording;
  bool get isProcessing => _isProcessing;
  bool get autoSpeak => _autoSpeak;
  String? get error => _error;

  void toggleAutoSpeak() {
    _autoSpeak = !_autoSpeak;
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
  Future<bool> sendTextMessage(String text) async {
    if (text.trim().isEmpty || _isProcessing) return false;

    final userMsg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: 'user',
      content: text.trim(),
      createdAt: DateTime.now(),
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
      final result = await _api.chat(text.trim());
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

    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.wav';

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
      final text = await _api.speechToText(File(path));
      if (text.trim().isEmpty) {
        _error = 'لم يتم التعرف على الكلام. حاول مرة أخرى.';
        _isProcessing = false;
        notifyListeners();
        return;
      }
      _isProcessing = false;
      await sendTextMessage(text);
    } catch (e) {
      _error = e.toString();
      _isProcessing = false;
      notifyListeners();
    }
  }

  Future<void> _speak(String text) async {
    try {
      final bytes = await _api.textToSpeech(text);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/tts_${DateTime.now().millisecondsSinceEpoch}.mp3');
      await file.writeAsBytes(bytes);
      await _player.play(DeviceFileSource(file.path));
    } catch (_) {}
  }

  Future<void> speakMessage(String text) async {
    await _speak(text);
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }
}

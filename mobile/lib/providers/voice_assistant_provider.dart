import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../screens/audit_screen.dart';
import '../screens/create_invoice_screen.dart';
import '../screens/help_screen.dart';
import '../screens/users_screen.dart';
import '../utils/report_pdf_helper.dart';
import '../voice/arabic_text.dart';
import '../voice/voice_command_router.dart';
import '../voice/wav_trim.dart';
import 'accessibility_provider.dart';
import 'auth_provider.dart';
import 'chat_provider.dart';
import 'data_provider.dart';
import 'demo_provider.dart';
import 'navigation_provider.dart';

enum VoicePhase { idle, sleeping, listening, thinking, speaking }

class _PendingConfirmation {
  final Future<void> Function() onYes;
  const _PendingConfirmation(this.onYes);
}

/// The hands-free voice brain of the app.
///
/// Listens continuously (voice activity detection on mic amplitude),
/// transcribes with Whisper, runs app-control commands locally and sends
/// everything else to the AI agent. After a quiet period it sleeps and only
/// reacts to the wake word ("يا مساعد").
class VoiceAssistantProvider extends ChangeNotifier with WidgetsBindingObserver {
  VoiceAssistantProvider({
    required ChatProvider chat,
    required DataProvider data,
    required AccessibilityProvider a11y,
    required AuthProvider auth,
    required DemoProvider demo,
    required NavigationProvider nav,
  })  : _chat = chat,
        _data = data,
        _a11y = a11y,
        _auth = auth,
        _demo = demo,
        _nav = nav {
    WidgetsBinding.instance.addObserver(this);
    _chat.addListener(_onChatChanged);
    _a11y.addListener(_onSettingsChanged);
    _auth.addListener(_onAuthChanged);
    _onSettingsChanged();
    _onAuthChanged();
  }

  static const _frameMs = 80;
  static const _sleepAfter = Duration(seconds: 50);

  final ChatProvider _chat;
  final DataProvider _data;
  final AccessibilityProvider _a11y;
  final AuthProvider _auth;
  final DemoProvider _demo;
  final NavigationProvider _nav;

  final AudioRecorder _recorder = AudioRecorder();
  // audioplayers_windows sends channel messages off the platform thread, which
  // Flutter warns can crash the app, so earcons are only played on mobile.
  final AudioPlayer? _sfx = Platform.isWindows ? null : AudioPlayer();

  /// Smoothed microphone level 0..1, drives the orb animation.
  final ValueNotifier<double> level = ValueNotifier(0);

  /// Set by the login screen so "ادخل" can press its login button.
  Future<bool> Function(String? role)? loginHandler;

  VoicePhase _phase = VoicePhase.idle;
  bool _expanded = false;
  bool _typing = false;
  bool _showTranscript = false;
  String? _heard;
  String? _hint;

  bool _disposed = false;
  bool _appActive = true;
  bool _loopRunning = false;
  bool _capturing = false;
  bool _captureFailed = false;
  bool _busy = false;
  bool _announceListening = true;
  bool _listenAfterSpeaking = false;
  bool _bargeWatchPending = false;
  bool _muteReplies = false;
  String? _queuedAudio;
  Completer<bool>? _captureResult;
  _PendingConfirmation? _pending;
  DateTime _lastActivity = DateTime.now();
  int _failures = 0;

  bool? _appliedHandsFree;
  double? _appliedRate;
  bool? _wasAuthenticated;

  VoicePhase get phase => _chat.isSpeaking ? VoicePhase.speaking : _phase;
  bool get expanded => _expanded;
  bool get typing => _typing;
  bool get showTranscript => _showTranscript;
  bool get handsFree => _a11y.handsFree;
  String? get heard => _heard;
  String? get hint => _hint;
  String? get reply => _chat.lastAssistantReply;

  String get statusLabel {
    switch (phase) {
      case VoicePhase.listening:
        return 'أستمع إليك…';
      case VoicePhase.thinking:
        return 'لحظة، أفكّر…';
      case VoicePhase.speaking:
        return 'أتحدث الآن — المس الدائرة لإيقافي';
      case VoicePhase.sleeping:
        return 'وضع الراحة — قل «يا مساعد» لإيقاظي';
      case VoicePhase.idle:
        return handsFree
            ? 'المس الدائرة لأبدأ الاستماع'
            : 'المس الدائرة وتحدّث';
    }
  }

  // ───────────────────────── UI actions ─────────────────────────

  void expand() {
    if (_expanded) return;
    _expanded = true;
    notifyListeners();
  }

  void collapse() {
    if (!_expanded && !_typing) return;
    _expanded = false;
    _typing = false;
    _showTranscript = false;
    notifyListeners();
  }

  void setTyping(bool value) {
    _typing = value;
    if (value) _expanded = true;
    notifyListeners();
  }

  void toggleTranscript() {
    _showTranscript = !_showTranscript;
    notifyListeners();
  }

  /// The orb is the single big button: talk, stop talking, wake up.
  void onOrbTap() {
    HapticFeedback.mediumImpact();
    _hint = null;
    if (_chat.isSpeaking) {
      _chat.stopSpeaking();
      return;
    }
    switch (_phase) {
      case VoicePhase.listening:
        if (_capturing) {
          _finishCaptureNow();
        } else if (!handsFree) {
          unawaited(_listenOnce());
        }
      case VoicePhase.thinking:
        break;
      case VoicePhase.sleeping:
        unawaited(_wake(greet: false));
      case VoicePhase.idle:
        _lastActivity = DateTime.now();
        if (handsFree) {
          _announceListening = true;
          _startLoop();
        } else {
          unawaited(_listenOnce());
        }
      case VoicePhase.speaking:
        break;
    }
    notifyListeners();
  }

  /// Typed text or a tapped suggestion: handled exactly like speech.
  Future<void> submitText(String text) async {
    if (text.trim().isEmpty) return;
    _typing = false;
    expand();
    _abortCapture();
    await handleText(text.trim());
  }

  // ───────────────────────── listeners ─────────────────────────

  void _onChatChanged() {
    if (_chat.isSpeaking) _startBargeInWatch();
    notifyListeners();
  }

  /// While the assistant talks, keep listening so the user can interrupt it
  /// just by speaking. The utterance that interrupted is then handled normally.
  void _startBargeInWatch() {
    if (_bargeWatchPending || !_canListen || _phase == VoicePhase.sleeping) return;
    _bargeWatchPending = true;
    unawaited(() async {
      try {
        // A normal capture may still be closing; never mix it with our voice.
        _abortCapture();
        while (_capturing && _chat.isSpeaking) {
          await Future.delayed(const Duration(milliseconds: 60));
        }
        if (!_chat.isSpeaking || !_canListen) return;
        final path = await _capture(
          sleeping: false,
          noSpeechTimeout: const Duration(minutes: 5),
          bargeIn: true,
        );
        if (path == null) return;
        if (!_canListen) {
          _deleteQuietly(path);
          return;
        }
        _queuedAudio = path;
        _startLoop();
      } finally {
        _bargeWatchPending = false;
      }
    }());
  }

  void _onSettingsChanged() {
    if (!_a11y.loaded || _disposed) return;
    _chat.setAutoSpeak(_a11y.autoSpeak);
    if (_appliedRate != _a11y.speechRate) {
      _appliedRate = _a11y.speechRate;
      _chat.setSpeechRate(_a11y.speechRate);
    }
    if (_appliedHandsFree != _a11y.handsFree) {
      final first = _appliedHandsFree == null;
      _appliedHandsFree = _a11y.handsFree;
      WakelockPlus.toggle(enable: _a11y.handsFree).catchError((_) {});
      if (_a11y.handsFree) {
        _lastActivity = DateTime.now();
        _announceListening = true;
        if (_phase == VoicePhase.idle) _phase = VoicePhase.listening;
        if (first) {
          // Let the first frame render (and the permission prompt appear) first.
          Future.delayed(const Duration(milliseconds: 1200), _startLoop);
        } else {
          _startLoop();
        }
      } else {
        _abortCapture();
        if (_phase != VoicePhase.thinking) _phase = VoicePhase.idle;
      }
    }
    notifyListeners();
  }

  void _onAuthChanged() {
    final authed = _auth.isAuthenticated;
    if (_wasAuthenticated == authed) return;
    final firstCheck = _wasAuthenticated == null;
    _wasAuthenticated = authed;
    _pending = null;
    if (authed) {
      _chat.loadHistory();
      _chat.loadModels();
    } else if (!firstCheck) {
      _chat.resetSession();
      _heard = null;
      _nav.reset();
    }
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _appActive = false;
      _abortCapture();
      _chat.stopSpeaking();
    } else if (state == AppLifecycleState.resumed && !_appActive) {
      _appActive = true;
      _announceListening = true;
      _startLoop();
    }
  }

  @override
  Future<bool> didPopRoute() async {
    if (_expanded) {
      collapse();
      return true;
    }
    return false;
  }

  // ───────────────────────── listening loop ─────────────────────────

  bool get _canListen => _a11y.handsFree && _appActive && !_disposed;

  void _setPhase(VoicePhase p) {
    if (_phase == p) return;
    _phase = p;
    if (!_disposed) notifyListeners();
  }

  void _startLoop() {
    if (_loopRunning || !_canListen) return;
    unawaited(_runLoop());
  }

  Future<void> _runLoop() async {
    _loopRunning = true;
    try {
      while (_canListen) {
        // Wait while we are answering, speaking (barge-in watch is listening
        // meanwhile) or running a demo.
        while (_canListen &&
            (_busy || _chat.isSpeaking || _chat.isProcessing || _capturing)) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
        if (!_canListen) break;

        final interrupted = _queuedAudio;
        if (interrupted != null) {
          _queuedAudio = null;
          await _processAudio(interrupted, sleeping: false);
          continue;
        }

        final sleeping = _phase == VoicePhase.sleeping;
        if (!sleeping) _setPhase(VoicePhase.listening);

        final path = await _capture(
          sleeping: sleeping,
          noSpeechTimeout: Duration(seconds: sleeping ? 12 : 9),
        );
        if (!_canListen) {
          _deleteQuietly(path);
          break;
        }
        if (path == null) {
          if (_captureFailed) {
            _failures++;
            await Future.delayed(Duration(seconds: math.min(20, 1 << _failures)));
          } else if (!sleeping &&
              _a11y.autoSleep &&
              _auth.isAuthenticated &&
              DateTime.now().difference(_lastActivity) > _sleepAfter) {
            _goToSleep();
          }
          continue;
        }
        await _processAudio(path, sleeping: sleeping);
      }
    } finally {
      _loopRunning = false;
      if (!_disposed && _phase == VoicePhase.listening) _setPhase(VoicePhase.idle);
    }
  }

  Future<void> _listenOnce() async {
    if (_capturing || _busy) return;
    _announceListening = true;
    _setPhase(VoicePhase.listening);
    final path = await _capture(
      sleeping: false,
      noSpeechTimeout: const Duration(seconds: 8),
    );
    if (path == null) {
      if (!_captureFailed) _hint = 'لم أسمع شيئاً. المس الدائرة وحاول مجدداً';
      _setPhase(VoicePhase.idle);
      notifyListeners();
      return;
    }
    await _processAudio(path, sleeping: false);
    if (_phase != VoicePhase.sleeping) _setPhase(VoicePhase.idle);
    if (_listenAfterSpeaking && !handsFree) {
      _listenAfterSpeaking = false;
      await _listenOnce();
    }
  }

  void _finishCaptureNow() {
    final r = _captureResult;
    if (r != null && !r.isCompleted) r.complete(true);
  }

  void _abortCapture() {
    final r = _captureResult;
    if (r != null && !r.isCompleted) r.complete(false);
  }

  /// Records until the user stops talking. Returns the WAV path, or null
  /// when nothing was said (or recording failed).
  ///
  /// With [bargeIn] it runs while the assistant is speaking: it first learns
  /// how loud our own voice comes back through the mic, stops the speech once
  /// the user is clearly louder, and drops the audio recorded before that.
  Future<String?> _capture({
    required bool sleeping,
    required Duration noSpeechTimeout,
    bool bargeIn = false,
  }) async {
    if (_capturing) return null;
    _capturing = true;
    _captureFailed = false;
    final result = Completer<bool>();
    _captureResult = result;
    StreamSubscription<Amplitude>? sub;
    String? path;
    try {
      if (!await _recorder.hasPermission()) {
        _hint = 'يجب السماح للتطبيق باستخدام الميكروفون';
        _captureFailed = true;
        notifyListeners();
        return null;
      }
      if (_announceListening && !sleeping && !bargeIn) {
        _announceListening = false;
        await _earcon('listen_start');
      }
      if (result.isCompleted) return null;

      final dir = await getTemporaryDirectory();
      path = '${dir.path}/voice_${DateTime.now().microsecondsSinceEpoch}.wav';
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
          // Android/iOS: removes our own TTS from the mic signal.
          echoCancel: true,
        ),
        path: path,
      );

      var elapsed = 0;
      var speechMs = 0;
      var silenceMs = 0;
      var calibration = 0;
      var floor = -55.0;
      var started = false;
      // Barge-in state.
      var echo = -60.0;
      double? quiet;
      var startedAt = 0;
      var trimMs = 0;

      sub = _recorder
          .onAmplitudeChanged(const Duration(milliseconds: _frameMs))
          .listen((amp) {
        if (result.isCompleted) return;
        final raw = amp.current;
        final db = raw.isFinite ? raw.clamp(-90.0, 0.0) : -90.0;
        elapsed += _frameMs;

        final visual = ((db - floor - 3) / 28).clamp(0.0, 1.0);
        level.value = level.value * 0.55 + visual * 0.45;

        if (bargeIn && !started) {
          if (!_chat.isSpeaking) {
            result.complete(false);
            return;
          }
          final audioAt = _chat.speechAudioAt;
          if (audioAt == null) {
            // Reply audio not playing yet: this is the room's quiet level.
            quiet = quiet == null ? db : quiet! * 0.8 + db * 0.2;
          }
          final warm = audioAt != null &&
              DateTime.now().difference(audioAt) > _chat.speechAudioWarmup;
          final threshold = math.max(echo + 9, -38.0);
          if (!warm || db <= threshold) {
            // Follow the loudness peaks of our own voice coming back.
            echo = math.max(db, echo - 0.4);
            speechMs = math.max(0, speechMs - _frameMs);
            return;
          }
          speechMs += _frameMs;
          if (speechMs < 320) return;
          started = true;
          startedAt = elapsed;
          trimMs = math.max(0, elapsed - speechMs - 250);
          floor = math.min(quiet ?? -50.0, -30);
          calibration = 4;
          unawaited(_chat.stopSpeaking());
          HapticFeedback.lightImpact();
          _hint = null;
          notifyListeners();
          return;
        }

        // First ~320ms: learn the room's background noise.
        if (calibration < 4) {
          floor = calibration == 0 ? db : (floor * calibration + db) / (calibration + 1);
          floor = math.min(floor, -30);
          calibration++;
          return;
        }

        final threshold = math.max(floor + (sleeping ? 15 : 11), sleeping ? -40.0 : -48.0);
        if (db > threshold) {
          speechMs += _frameMs;
          silenceMs = 0;
          if (!started && speechMs >= (sleeping ? 320 : 200)) {
            started = true;
            if (!sleeping) {
              _hint = null;
              notifyListeners();
            }
          }
        } else if (started) {
          silenceMs += _frameMs;
        } else {
          speechMs = math.max(0, speechMs - _frameMs);
          floor = math.min(floor * 0.92 + db * 0.08, -30);
        }

        if (started && silenceMs >= (sleeping ? 900 : 1200)) {
          result.complete(true);
        } else if (elapsed - startedAt >= 15000) {
          result.complete(started);
        } else if (!started && elapsed >= noSpeechTimeout.inMilliseconds) {
          result.complete(false);
        }
      }, onError: (_) {});

      // Safety net if the platform never reports amplitude.
      final got = await result.future.timeout(
        Duration(seconds: bargeIn ? 300 : 20),
        onTimeout: () => false,
      );
      await sub.cancel();
      sub = null;
      final out = await _recorder.stop();
      if (!got) {
        _deleteQuietly(out ?? path);
        return null;
      }
      final file = out ?? path;
      if (bargeIn) await trimWavStart(file, trimMs);
      if (!sleeping) unawaited(_earcon('listen_end'));
      return file;
    } catch (e) {
      debugPrint('Voice capture failed: $e');
      _captureFailed = true;
      _hint = 'تعذّر تشغيل الميكروفون';
      try {
        await _recorder.stop();
      } catch (_) {}
      _deleteQuietly(path);
      return null;
    } finally {
      await sub?.cancel();
      _capturing = false;
      if (identical(_captureResult, result)) _captureResult = null;
      level.value = 0;
    }
  }

  Future<void> _processAudio(String path, {required bool sleeping}) async {
    if (!sleeping) _setPhase(VoicePhase.thinking);
    Map<String, dynamic> stt;
    try {
      stt = await _chat.transcribe(path);
      _failures = 0;
    } catch (e) {
      _failures++;
      _deleteQuietly(path);
      if (!sleeping) {
        _hint = 'تعذّر الوصول لخدمة الصوت. تأكد من تشغيل الخادم.';
        await _earcon('error');
        if (_failures == 1) {
          await _chat.speakNow('لا أستطيع الوصول إلى خدمة الصوت حالياً');
        }
        _setPhase(handsFree ? VoicePhase.listening : VoicePhase.idle);
      }
      await Future.delayed(Duration(seconds: math.min(20, 1 << _failures)));
      return;
    }
    _deleteQuietly(path);

    final text = (stt['text'] as String? ?? '').trim();
    final norm = ArabicText.normalize(text);
    if (norm.isEmpty || ArabicText.isLikelyNoise(norm)) {
      if (!sleeping) {
        _hint = 'لم أفهم جيداً، أعد من فضلك';
        _setPhase(handsFree ? VoicePhase.listening : VoicePhase.idle);
        notifyListeners();
      }
      return;
    }

    if (sleeping) {
      final rest = VoiceCommandRouter.afterWakeWord(norm);
      if (rest == null) return;
      await _wake(greet: rest.isEmpty);
      if (rest.isNotEmpty) await handleText(rest);
      return;
    }

    await handleText(
      text,
      speakerGender: stt['gender']?.toString(),
      speakerGenderAr: stt['gender_ar']?.toString(),
      confidence: (stt['confidence'] as num?)?.toDouble(),
    );
  }

  // ───────────────────────── understanding ─────────────────────────

  Future<void> handleText(
    String text, {
    String? speakerGender,
    String? speakerGenderAr,
    double? confidence,
  }) async {
    if (_busy) return;
    _busy = true;
    _lastActivity = DateTime.now();
    _hint = null;
    _heard = text;
    _announceListening = true;
    notifyListeners();
    try {
      final norm = ArabicText.normalize(text);

      final pending = _pending;
      _pending = null;
      if (pending != null) {
        final answer = VoiceCommandRouter.parseConfirmation(norm);
        if (answer == true) {
          await pending.onYes();
          return;
        }
        if (answer == false) {
          await _say('حسناً، ألغيت العملية.', userText: text);
          return;
        }
      }

      final sequence = VoiceCommandRouter.parseSequence(text);
      if (sequence != null) {
        await _executeSequence(sequence, text);
        return;
      }

      final action = VoiceCommandRouter.parse(norm);
      if (action != null) {
        await _execute(action, text);
        return;
      }

      if (!_auth.isAuthenticated) {
        await _say('يجب تسجيل الدخول أولاً. قل: ادخل', userText: text, force: true);
        return;
      }

      _setPhase(VoicePhase.thinking);
      final mutated = await _chat.sendTextMessage(
        text,
        speakerGender: speakerGender,
        speakerGenderAr: speakerGenderAr,
        confidence: confidence,
      );
      if (mutated) unawaited(_data.loadAll());
      _followTool(_chat.lastToolUsed);
    } finally {
      _busy = false;
      _lastActivity = DateTime.now();
      if (_phase == VoicePhase.thinking) {
        _setPhase(handsFree ? VoicePhase.listening : VoicePhase.idle);
      }
      notifyListeners();
    }
  }

  /// Shows the matching screen behind the assistant after an AI answer.
  void _followTool(String? tool) {
    if (tool == null) return;
    final int? tab = switch (tool) {
      'list_customers' || 'search_customers' || 'create_customer' || 'update_customer' => 1,
      'list_products' || 'create_product' || 'update_product_stock' => 2,
      'get_accounting_summary' => 0,
      _ when tool.contains('invoice') || tool == 'generate_report' => 3,
      _ => null,
    };
    if (tab != null) _nav.goTab(tab);
  }

  Future<void> _say(String reply, {String? userText, bool force = false}) async {
    if (_muteReplies) return;
    await _chat.say(reply, userText: userText, force: force);
  }

  /// Runs "افتح الفواتير المدفوعة، وانزل للاخير" step by step; only the last
  /// step speaks, so the user hears one answer.
  Future<void> _executeSequence(List<VoiceAction> actions, String userText) async {
    for (var i = 0; i < actions.length; i++) {
      final last = i == actions.length - 1;
      _muteReplies = !last;
      try {
        await _execute(actions[i], last ? userText : '');
      } finally {
        _muteReplies = false;
      }
      // Let a newly opened screen build before scrolling it.
      if (!last) await Future.delayed(const Duration(milliseconds: 400));
    }
  }

  Future<void> _confirm(String question, String userText, Future<void> Function() onYes) async {
    _pending = _PendingConfirmation(onYes);
    _listenAfterSpeaking = true;
    await _say(question, userText: userText, force: true);
  }

  bool _requireAuth(String userText) {
    if (_auth.isAuthenticated) return true;
    unawaited(_say('سجّل الدخول أولاً. قل: ادخل', userText: userText, force: true));
    return false;
  }

  Future<void> _execute(VoiceAction action, String userText) async {
    switch (action.type) {
      case VoiceActionType.navigate:
        if (!_requireAuth(userText)) return;
        await _openDestination(action.destination!, userText);

      case VoiceActionType.back:
        if (_expanded) {
          collapse();
        } else if (!await _nav.back()) {
          await _say('أنت في الصفحة الرئيسية.', userText: userText);
        }

      case VoiceActionType.scrollDown:
      case VoiceActionType.scrollUp:
      case VoiceActionType.scrollTop:
      case VoiceActionType.scrollBottom:
        collapse();
        final dir = switch (action.type) {
          VoiceActionType.scrollDown => 1,
          VoiceActionType.scrollUp => -1,
          VoiceActionType.scrollBottom => 2,
          _ => 0,
        };
        if (!await _nav.scroll(dir)) {
          await _say(dir > 0 ? 'وصلت إلى نهاية الصفحة.' : 'أنت في أعلى الصفحة.', userText: userText);
        }

      case VoiceActionType.filterInvoices:
        if (!_requireAuth(userText)) return;
        collapse();
        _nav.goTab(3);
        await _data.setInvoiceFilter(action.arg);
        final label = switch (action.arg) {
          'PAID' => 'المدفوعة',
          'PENDING' => 'المعلقة',
          'DRAFT' => 'المسودات',
          'CANCELLED' => 'الملغاة',
          _ => 'كل الفواتير',
        };
        final list = _data.invoices;
        final names = list.take(4).map((i) => i.customerName).toSet().join('، ');
        await _say(
          list.isEmpty
              ? 'لا توجد فواتير $label.'
              : '$label: ${list.length} ${list.length == 1 ? 'فاتورة' : 'فواتير'}، لعملاء مثل: $names.',
          userText: userText,
        );

      case VoiceActionType.readScreen:
        await _say(_describeScreen(), userText: userText, force: true);

      case VoiceActionType.stopSpeaking:
        await _chat.stopSpeaking();
        _hint = 'توقفت عن الكلام';

      case VoiceActionType.repeat:
        final last = _chat.lastAssistantReply;
        if (last == null) {
          await _say('لا يوجد ما أعيده بعد.', userText: userText);
        } else {
          await _chat.speakNow(last);
        }

      case VoiceActionType.sleep:
        if (handsFree) {
          await _say('حسناً، سأرتاح. قل «يا مساعد» عندما تحتاجني.', userText: userText, force: true);
          _goToSleep();
        } else {
          await _say('حسناً.', userText: userText);
        }

      case VoiceActionType.wake:
        await _say('نعم، تفضّل.', userText: userText, force: true);

      case VoiceActionType.collapse:
        collapse();
        await _say('حاضر، أنا هنا عند الحاجة.', userText: userText);

      case VoiceActionType.expand:
        expand();
        await _say('تفضّل.', userText: userText);

      case VoiceActionType.largerText:
        await _a11y.setLargeControls(true);
        await _say('كبّرت الخط والأزرار.', userText: userText);

      case VoiceActionType.smallerText:
        await _a11y.setLargeControls(false);
        await _say('صغّرت الخط والأزرار.', userText: userText);

      case VoiceActionType.highContrastOn:
        await _a11y.setHighContrast(true);
        await _say('فعّلت التباين العالي.', userText: userText);

      case VoiceActionType.highContrastOff:
        await _a11y.setHighContrast(false);
        await _say('أعدت الألوان العادية.', userText: userText);

      case VoiceActionType.slower:
        await _a11y.setSpeechRate(_a11y.speechRate - 0.1);
        await _say('هكذا أتكلم أبطأ. هل هذا أفضل؟', userText: userText, force: true);

      case VoiceActionType.faster:
        await _a11y.setSpeechRate(_a11y.speechRate + 0.1);
        await _say('هكذا أتكلم أسرع.', userText: userText, force: true);

      case VoiceActionType.autoSpeakOff:
        await _say('حسناً، سأكتب الردود دون قراءتها.', userText: userText, force: true);
        await _a11y.setAutoSpeak(false);

      case VoiceActionType.autoSpeakOn:
        await _a11y.setAutoSpeak(true);
        await _say('عدت لقراءة الردود بصوت مسموع.', userText: userText);

      case VoiceActionType.clearChat:
        if (!_requireAuth(userText)) return;
        await _confirm('هل تريد حذف كل المحادثة؟ قل نعم أو لا.', userText, () async {
          final ok = await _chat.clearHistory();
          await _say(ok ? 'تم حذف المحادثة.' : 'تعذّر حذف المحادثة.');
        });

      case VoiceActionType.logout:
        if (!_auth.isAuthenticated) {
          await _say('أنت لم تسجل الدخول بعد.', userText: userText);
          return;
        }
        await _confirm('هل تريد تسجيل الخروج؟ قل نعم أو لا.', userText, () async {
          await _say('مع السلامة.', force: true);
          collapse();
          _nav.reset();
          await _auth.logout();
        });

      case VoiceActionType.login:
        if (_auth.isAuthenticated) {
          await _say('أنت مسجل الدخول باسم ${_auth.user?.name ?? ''}.', userText: userText);
          return;
        }
        final handler = loginHandler;
        if (handler == null) {
          await _say('شاشة تسجيل الدخول غير ظاهرة.', userText: userText);
          return;
        }
        _setPhase(VoicePhase.thinking);
        final ok = await handler(action.arg);
        await _say(
          ok
              ? 'أهلاً ${_auth.user?.name ?? ''}. تم تسجيل الدخول. كيف أساعدك؟'
              : 'تعذّر تسجيل الدخول. ${_auth.error ?? ''}',
          userText: userText,
          force: true,
        );

      case VoiceActionType.refresh:
        if (!_requireAuth(userText)) return;
        await _data.loadAll();
        await _say('تم تحديث البيانات.', userText: userText);

      case VoiceActionType.pdfReport:
        if (!_requireAuth(userText)) return;
        final ctx = _nav.context;
        if (ctx == null) return;
        collapse();
        unawaited(generateAndOpenInvoiceReportPdf(ctx, status: action.arg));
        await _say('أجهّز تقرير PDF الآن.', userText: userText);

      case VoiceActionType.demo:
        if (!_requireAuth(userText)) return;
        expand();
        await _demo.runDemo(_chat, _data);

      case VoiceActionType.time:
        await _say(_timeText(), userText: userText, force: true);

      case VoiceActionType.date:
        await _say(_dateText(), userText: userText, force: true);

      case VoiceActionType.help:
        await _say(_helpText, userText: userText, force: true);

      case VoiceActionType.typeText:
        setTyping(true);
        await _say('اكتب طلبك في الحقل.', userText: userText);
    }
  }

  Future<void> _openDestination(AppDestination d, String userText) async {
    final isAdmin = _auth.user?.isAdmin == true;
    if ((d == AppDestination.users || d == AppDestination.audit) && !isAdmin) {
      await _say('هذا القسم متاح للمدير فقط.', userText: userText);
      return;
    }
    collapse();
    switch (d) {
      case AppDestination.home:
        _nav.goTab(0);
      case AppDestination.customers:
        _nav.goTab(1);
      case AppDestination.products:
        _nav.goTab(2);
      case AppDestination.invoices:
        _nav.goTab(3);
      case AppDestination.settings:
        _nav.goTab(NavigationProvider.settingsTab);
      case AppDestination.help:
        _nav.popToRoot();
        unawaited(_nav.push(const HelpScreen()));
      case AppDestination.users:
        _nav.popToRoot();
        unawaited(_nav.push(const UsersScreen()));
      case AppDestination.audit:
        _nav.popToRoot();
        unawaited(_nav.push(const AuditScreen()));
      case AppDestination.newInvoice:
        _nav.popToRoot();
        unawaited(_nav.push(const CreateInvoiceScreen()));
    }
    final spoken = switch (d) {
      AppDestination.home => 'الصفحة الرئيسية. ${_homeSummary()}',
      AppDestination.customers => 'العملاء. ${_customersSummary()}',
      AppDestination.products => 'المنتجات. ${_productsSummary()}',
      AppDestination.invoices => 'الفواتير. ${_invoicesSummary()}',
      AppDestination.settings => 'الإعدادات.',
      AppDestination.help => 'دليل الأوامر.',
      AppDestination.users => 'إدارة المستخدمين.',
      AppDestination.audit => 'سجل العمليات.',
      AppDestination.newInvoice =>
        'شاشة فاتورة جديدة. يمكنك أيضاً أن تقول: أنشئ فاتورة لفلان بمنتج كذا.',
    };
    await _say(spoken, userText: userText);
  }

  Future<void> _wake({required bool greet}) async {
    _abortCapture();
    _lastActivity = DateTime.now();
    _announceListening = false;
    _setPhase(VoicePhase.listening);
    HapticFeedback.heavyImpact();
    await _earcon('wake');
    if (greet) await _say('نعم، تفضّل.', force: true);
    _startLoop();
  }

  void _goToSleep() {
    _abortCapture();
    _setPhase(VoicePhase.sleeping);
  }

  // ───────────────────────── speech text ─────────────────────────

  static String _num(num v) => v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(2);

  String _homeSummary() {
    final s = _data.summary;
    if (s == null) return '';
    num n(String k) => num.tryParse('${s[k] ?? 0}') ?? 0;
    return 'لديك ${_num(n('totalInvoices'))} فاتورة، منها ${_num(n('pendingCount'))} معلقة. '
        'المبلغ المدفوع ${_num(n('paidAmount'))} ليرة، والمعلق ${_num(n('pendingAmount'))} ليرة. '
        'عدد العملاء ${_num(n('customersCount'))}، والمنتجات ${_num(n('productsCount'))}.';
  }

  String _customersSummary() {
    final list = _data.customers;
    if (list.isEmpty) return 'لا يوجد عملاء بعد.';
    final names = list.take(5).map((c) => c.name).join('، ');
    return 'عدد العملاء ${list.length}. منهم: $names.';
  }

  String _productsSummary() {
    final list = _data.products;
    if (list.isEmpty) return 'لا توجد منتجات بعد.';
    final low = list.where((p) => p.lowStock || p.outOfStock).length;
    final names = list.take(5).map((p) => p.name).join('، ');
    return 'عدد المنتجات ${list.length}${low > 0 ? '، منها $low مخزونها منخفض' : ''}. منها: $names.';
  }

  String _invoicesSummary() {
    final list = _data.invoices;
    if (list.isEmpty) return 'لا توجد فواتير بعد.';
    final pending = list.where((i) => i.status == 'PENDING').length;
    final last = list.first;
    return 'عدد الفواتير ${list.length}، منها $pending معلقة. '
        'آخر فاتورة للعميل ${last.customerName} بقيمة ${_num(last.total)} ليرة، وحالتها ${last.statusAr}.';
  }

  String _describeScreen() {
    if (!_auth.isAuthenticated) {
      return 'أنت في شاشة تسجيل الدخول. قل: ادخل، لتسجيل الدخول.';
    }
    if (_nav.hasPushedRoute) {
      return 'أنت في صفحة فرعية. قل: انزل أو اطلع للتصفح، أو ارجع للعودة.';
    }
    return switch (_nav.tab) {
      0 => 'أنت في الصفحة الرئيسية. ${_homeSummary()}',
      1 => 'أنت في صفحة العملاء. ${_customersSummary()}',
      2 => 'أنت في صفحة المنتجات. ${_productsSummary()}',
      3 => 'أنت في صفحة الفواتير. ${_invoicesSummary()}',
      _ => 'أنت في الإعدادات. الاستماع الدائم ${_a11y.handsFree ? 'مفعّل' : 'متوقف'}، '
          'والخط الكبير ${_a11y.largeControls ? 'مفعّل' : 'متوقف'}، '
          'والتباين العالي ${_a11y.highContrast ? 'مفعّل' : 'متوقف'}.',
    };
  }

  static const _weekdays = [
    'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد',
  ];
  static const _months = [
    'كانون الثاني', 'شباط', 'آذار', 'نيسان', 'أيار', 'حزيران',
    'تموز', 'آب', 'أيلول', 'تشرين الأول', 'تشرين الثاني', 'كانون الأول',
  ];

  String _timeText() {
    final now = DateTime.now();
    final h = now.hour % 12 == 0 ? 12 : now.hour % 12;
    final period = now.hour < 12 ? 'صباحاً' : (now.hour < 18 ? 'بعد الظهر' : 'مساءً');
    final minutes = now.minute == 0 ? 'تماماً' : 'و ${now.minute} دقيقة';
    return 'الساعة الآن $h $minutes $period.';
  }

  String _dateText() {
    final now = DateTime.now();
    return 'اليوم ${_weekdays[now.weekday - 1]}، ${now.day} ${_months[now.month - 1]} ${now.year}.';
  }

  static const _helpText =
      'يمكنك أن تقول مثلاً: افتح العملاء، أو اعرض فواتير محمد الأحمد، أو أضف عميلاً اسمه سارة، '
      'أو ما ملخص المحاسبة. وللتنقل قل: انزل، اطلع، ارجع، أو اقرأ الشاشة. '
      'لإيقاف كلامي قل: اسكت، وللراحة قل: نام، ولإيقاظي قل: يا مساعد.';

  // ───────────────────────── helpers ─────────────────────────

  Future<void> _earcon(String name) async {
    final sfx = _sfx;
    if (sfx == null) return;
    try {
      await sfx.stop();
      await sfx.play(AssetSource('sounds/$name.wav'), volume: 0.6);
      await sfx.onPlayerComplete.first.timeout(const Duration(milliseconds: 700));
    } catch (_) {}
  }

  void _deleteQuietly(String? path) {
    if (path == null) return;
    try {
      final f = File(path);
      if (f.existsSync()) f.deleteSync();
    } catch (_) {}
  }

  @override
  void dispose() {
    _disposed = true;
    _abortCapture();
    WidgetsBinding.instance.removeObserver(this);
    _chat.removeListener(_onChatChanged);
    _a11y.removeListener(_onSettingsChanged);
    _auth.removeListener(_onAuthChanged);
    WakelockPlus.disable().catchError((_) {});
    _recorder.dispose();
    _sfx?.dispose();
    level.dispose();
    super.dispose();
  }
}

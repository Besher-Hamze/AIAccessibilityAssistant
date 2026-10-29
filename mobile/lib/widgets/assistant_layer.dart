import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/accessibility_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/voice_assistant_provider.dart';
import '../theme/app_theme.dart';
import 'message_bubble.dart';
import 'voice_orb.dart';

/// Sits above the whole app (above the Navigator) so the assistant is
/// reachable from every screen: a floating mini orb, or full screen.
class AssistantLayer extends StatefulWidget {
  final Widget child;

  const AssistantLayer({super.key, required this.child});

  @override
  State<AssistantLayer> createState() => _AssistantLayerState();
}

class _AssistantLayerState extends State<AssistantLayer> {
  late final OverlayEntry _entry = OverlayEntry(builder: (_) => const _AssistantUi());

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  /// Keyboard / single-switch access: Space or F2 talks, F1 opens/closes
  /// the assistant, Escape minimizes.
  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    final voice = context.read<VoiceAssistantProvider>();
    final focusCtx = FocusManager.instance.primaryFocus?.context;
    final inTextField = focusCtx?.findAncestorStateOfType<EditableTextState>() != null;
    if (event.logicalKey == LogicalKeyboardKey.escape && voice.expanded) {
      voice.collapse();
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.f1) {
      voice.expanded ? voice.collapse() : voice.expand();
      return true;
    }
    if (!inTextField &&
        (event.logicalKey == LogicalKeyboardKey.space ||
            event.logicalKey == LogicalKeyboardKey.f2)) {
      voice.onOrbTap();
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned.fill(child: Overlay(initialEntries: [_entry])),
      ],
    );
  }
}

class _AssistantUi extends StatelessWidget {
  const _AssistantUi();

  @override
  Widget build(BuildContext context) {
    final voice = context.watch<VoiceAssistantProvider>();
    final authed = context.select<AuthProvider, bool>((a) => a.isAuthenticated);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Stack(
        children: [
          // The login screen shows its own large orb.
          if (!voice.expanded && authed) const _MiniAssistant(),
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !voice.expanded,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 380),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: ScaleTransition(
                    scale: Tween(begin: 0.96, end: 1.0).animate(anim),
                    child: child,
                  ),
                ),
                child: voice.expanded
                    ? const _ExpandedAssistant(key: ValueKey('expanded'))
                    : const SizedBox.shrink(key: ValueKey('collapsed')),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── collapsed ─────────────────────────

class _MiniAssistant extends StatelessWidget {
  const _MiniAssistant();

  static const orbSize = 104.0;

  @override
  Widget build(BuildContext context) {
    final voice = context.watch<VoiceAssistantProvider>();
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final phase = voice.phase;
    final active = phase == VoicePhase.listening ||
        phase == VoicePhase.thinking ||
        phase == VoicePhase.speaking;
    final caption = switch (phase) {
      VoicePhase.speaking => voice.reply,
      VoicePhase.thinking => voice.heard,
      _ => voice.hint,
    };

    return Stack(
      children: [
        Positioned(
          left: 20,
          right: 20,
          bottom: bottomInset + orbSize - 4,
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: (active || voice.hint != null || phase == VoicePhase.sleeping)
                  ? _CaptionBubble(
                      key: ValueKey('${phase.name}${caption ?? ''}'),
                      title: voice.statusLabel,
                      text: caption,
                      onTap: voice.expand,
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ),
        Positioned(
          bottom: bottomInset - 14,
          left: 0,
          right: 0,
          child: Center(
            child: Semantics(
              button: true,
              label: 'المساعد الصوتي. ${voice.statusLabel}',
              hint: 'اضغط للتحدث، أو اضغط مطولاً لفتح المساعد',
              child: GestureDetector(
                onTap: voice.onOrbTap,
                onLongPress: voice.expand,
                onDoubleTap: voice.expand,
                child: VoiceOrb(phase: phase, level: voice.level, size: orbSize),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CaptionBubble extends StatelessWidget {
  final String title;
  final String? text;
  final VoidCallback onTap;

  const _CaptionBubble({super.key, required this.title, this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xF20B1437),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.35),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF99E9F2),
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            if (text != null && text!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                text!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.45),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── expanded ─────────────────────────

class _ExpandedAssistant extends StatelessWidget {
  const _ExpandedAssistant({super.key});

  static const _suggestions = [
    'ما ملخص المحاسبة؟',
    'افتح العملاء',
    'اعرض قائمة المنتجات',
    'اعرض فواتير محمد الأحمد',
    'اقرأ الشاشة',
    'شو بتقدر تعمل؟',
  ];

  @override
  Widget build(BuildContext context) {
    final voice = context.watch<VoiceAssistantProvider>();
    final a11y = context.watch<AccessibilityProvider>();
    final authed = context.select<AuthProvider, bool>((a) => a.isAuthenticated);

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF070B1E), Color(0xFF0D1640), Color(0xFF13204F)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Row(
                  children: [
                    _CircleAction(
                      icon: Icons.keyboard_arrow_down_rounded,
                      label: 'تصغير',
                      onTap: voice.collapse,
                    ),
                    const Spacer(),
                    _HandsFreePill(
                      on: a11y.handsFree,
                      onTap: () => a11y.setHandsFree(!a11y.handsFree),
                    ),
                    const Spacer(),
                    _CircleAction(
                      icon: voice.showTranscript
                          ? Icons.graphic_eq_rounded
                          : Icons.forum_outlined,
                      label: voice.showTranscript ? 'المساعد' : 'المحادثة',
                      onTap: voice.toggleTranscript,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: voice.showTranscript
                      ? const _Transcript(key: ValueKey('t'))
                      : const _Stage(key: ValueKey('s')),
                ),
              ),
              if (voice.typing) const _TypeBar(),
              if (!voice.typing && authed)
                SizedBox(
                  height: 54,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      for (final s in _suggestions)
                        Padding(
                          padding: const EdgeInsets.only(left: 8, top: 4, bottom: 4),
                          child: _SuggestionChip(
                            text: s,
                            onTap: () => voice.submitText(s),
                          ),
                        ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 10, 24, 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _CircleAction(
                      icon: Icons.keyboard_rounded,
                      label: 'كتابة',
                      big: true,
                      onTap: () => voice.setTyping(!voice.typing),
                    ),
                    _CircleAction(
                      icon: voice.phase == VoicePhase.speaking
                          ? Icons.stop_rounded
                          : (voice.phase == VoicePhase.listening
                              ? Icons.send_rounded
                              : Icons.mic_rounded),
                      label: voice.phase == VoicePhase.speaking
                          ? 'إيقاف'
                          : (voice.phase == VoicePhase.listening ? 'إرسال الآن' : 'تحدّث'),
                      big: true,
                      accent: true,
                      onTap: voice.onOrbTap,
                    ),
                    _CircleAction(
                      icon: a11y.autoSpeak
                          ? Icons.volume_up_rounded
                          : Icons.volume_off_rounded,
                      label: a11y.autoSpeak ? 'الصوت مفعّل' : 'الصوت مكتوم',
                      big: true,
                      onTap: () => a11y.setAutoSpeak(!a11y.autoSpeak),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stage extends StatelessWidget {
  const _Stage({super.key});

  @override
  Widget build(BuildContext context) {
    final voice = context.watch<VoiceAssistantProvider>();
    final size = MediaQuery.sizeOf(context);
    final orbSize = math.min(size.width * 0.82, math.min(size.height * 0.42, 380.0));
    final reply = voice.phase == VoicePhase.listening && voice.heard == null ? null : voice.reply;

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Text(
                  voice.statusLabel,
                  key: ValueKey(voice.statusLabel),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (voice.hint != null) ...[
                const SizedBox(height: 8),
                Text(
                  voice.hint!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFFFC9C9), fontSize: 15),
                ),
              ],
              Semantics(
                button: true,
                label: voice.statusLabel,
                child: GestureDetector(
                  onTap: voice.onOrbTap,
                  child: VoiceOrb(phase: voice.phase, level: voice.level, size: orbSize),
                ),
              ),
              if (voice.heard != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Text(
                    '«${voice.heard}»',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 18,
                      fontStyle: FontStyle.italic,
                      height: 1.5,
                    ),
                  ),
                ),
              if (reply != null) ...[
                const SizedBox(height: 14),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(18),
                  constraints: const BoxConstraints(maxWidth: 640),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Text(
                    reply,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 19, height: 1.6),
                  ),
                ),
              ],
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _Transcript extends StatelessWidget {
  const _Transcript({super.key});

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final messages = chat.messages.reversed.toList();
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(26),
      ),
      clipBehavior: Clip.antiAlias,
      child: messages.isEmpty
          ? const Center(
              child: Text(
                'لا توجد رسائل بعد',
                style: TextStyle(color: AppColors.muted, fontSize: 16),
              ),
            )
          : ListView.builder(
              reverse: true,
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              itemBuilder: (context, i) {
                final msg = messages[i];
                return MessageBubble(
                  message: msg,
                  onSpeak: msg.isAssistant && !msg.isLoading
                      ? () => chat.speakMessage(msg.content)
                      : null,
                  isSpeaking: chat.isSpeaking && chat.speakingText == msg.content,
                );
              },
            ),
    );
  }
}

class _TypeBar extends StatefulWidget {
  const _TypeBar();

  @override
  State<_TypeBar> createState() => _TypeBarState();
}

class _TypeBarState extends State<_TypeBar> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text;
    _controller.clear();
    context.read<VoiceAssistantProvider>().submitText(text);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.send,
              style: const TextStyle(fontSize: 18),
              decoration: InputDecoration(
                hintText: 'اكتب طلبك هنا…',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(28)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _send(),
            ),
          ),
          const SizedBox(width: 10),
          IconButton.filled(
            tooltip: 'إرسال',
            iconSize: 28,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.rose,
              minimumSize: const Size(58, 58),
            ),
            onPressed: _send,
            icon: const Icon(Icons.send_rounded),
          ),
        ],
      ),
    );
  }
}

class _HandsFreePill extends StatelessWidget {
  final bool on;
  final VoidCallback onTap;

  const _HandsFreePill({required this.on, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: on,
      button: true,
      label: 'الاستماع الدائم',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            color: on
                ? const Color(0xFF22B8CF).withValues(alpha: 0.18)
                : Colors.white.withValues(alpha: 0.06),
            border: Border.all(
              color: on ? const Color(0xFF66D9E8) : Colors.white24,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                on ? Icons.hearing_rounded : Icons.hearing_disabled_rounded,
                color: on ? const Color(0xFF99E9F2) : Colors.white60,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                on ? 'استماع دائم' : 'استماع يدوي',
                style: TextStyle(
                  color: on ? Colors.white : Colors.white70,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool big;
  final bool accent;

  const _CircleAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.big = false,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    final d = big ? (accent ? 74.0 : 62.0) : 52.0;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            shape: const CircleBorder(),
            color: accent ? null : Colors.white.withValues(alpha: 0.08),
            child: Ink(
              decoration: accent
                  ? const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [AppColors.rose, Color(0xFF9775FA)],
                      ),
                    )
                  : null,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onTap,
                child: SizedBox.square(
                  dimension: d,
                  child: Icon(icon, color: Colors.white, size: d * 0.46),
                ),
              ),
            ),
          ),
          if (big) ...[
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _SuggestionChip({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          color: Colors.white.withValues(alpha: 0.05),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_awesome_rounded, size: 16, color: Color(0xFF99E9F2)),
            const SizedBox(width: 6),
            Text(text, style: const TextStyle(color: Colors.white, fontSize: 15)),
          ],
        ),
      ),
    );
  }
}

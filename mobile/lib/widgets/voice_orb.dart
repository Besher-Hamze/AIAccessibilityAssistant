import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../providers/voice_assistant_provider.dart';

/// Animated "living" orb: breathes when idle, reacts to the microphone level
/// while listening, swirls while thinking and pulses while speaking.
class VoiceOrb extends StatefulWidget {
  final VoicePhase phase;
  final ValueListenable<double> level;
  final double size;

  const VoiceOrb({
    super.key,
    required this.phase,
    required this.level,
    this.size = 240,
  });

  @override
  State<VoiceOrb> createState() => _VoiceOrbState();
}

class _OrbStyle {
  final List<Color> colors;
  final double wobble;
  final double speed;
  final double glow;

  const _OrbStyle(this.colors, this.wobble, this.speed, this.glow);

  static const idle = _OrbStyle(
    [Color(0xFF22B8CF), Color(0xFF5C7CFA), Color(0xFF9775FA)], 0.035, 0.8, 0.55);
  static const listening = _OrbStyle(
    [Color(0xFF3BC9DB), Color(0xFF4DABF7), Color(0xFF63E6BE)], 0.05, 1.4, 0.85);
  static const thinking = _OrbStyle(
    [Color(0xFF9775FA), Color(0xFF5C7CFA), Color(0xFFF783AC)], 0.06, 2.6, 0.75);
  static const speaking = _OrbStyle(
    [Color(0xFFF783AC), Color(0xFF9775FA), Color(0xFF22B8CF)], 0.07, 1.8, 0.9);
  static const sleeping = _OrbStyle(
    [Color(0xFF4C5A80), Color(0xFF3B4A6B), Color(0xFF6A5A90)], 0.02, 0.35, 0.25);

  static _OrbStyle of(VoicePhase p) => switch (p) {
        VoicePhase.idle => idle,
        VoicePhase.listening => listening,
        VoicePhase.thinking => thinking,
        VoicePhase.speaking => speaking,
        VoicePhase.sleeping => sleeping,
      };
}

class _OrbState {
  double time = 0;
  double level = 0;
  double wobble = _OrbStyle.idle.wobble;
  double speed = _OrbStyle.idle.speed;
  double glow = _OrbStyle.idle.glow;
  List<Color> colors = List.of(_OrbStyle.idle.colors);
  double thinking = 0;
  double listening = 0;
  VoicePhase phase = VoicePhase.idle;
}

class _VoiceOrbState extends State<VoiceOrb> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _state = _OrbState();
  final _repaint = ValueNotifier<int>(0);
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
  }

  void _tick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = elapsed;
    final s = _state;
    final target = _OrbStyle.of(widget.phase);
    final k = 1 - math.exp(-dt * 5);

    s.phase = widget.phase;
    s.time += dt * (0.6 + s.speed);
    s.wobble += (target.wobble - s.wobble) * k;
    s.speed += (target.speed - s.speed) * k;
    s.glow += (target.glow - s.glow) * k;
    for (var i = 0; i < 3; i++) {
      s.colors[i] = Color.lerp(s.colors[i], target.colors[i], k)!;
    }
    s.thinking += ((widget.phase == VoicePhase.thinking ? 1 : 0) - s.thinking) * k;
    s.listening += ((widget.phase == VoicePhase.listening ? 1 : 0) - s.listening) * k;

    double lvl;
    if (widget.phase == VoicePhase.speaking) {
      final t = s.time;
      lvl = 0.35 + 0.25 * math.sin(t * 5.3) * math.sin(t * 2.1) + 0.15 * math.sin(t * 11.7);
    } else if (widget.phase == VoicePhase.listening) {
      lvl = widget.level.value;
    } else {
      lvl = 0;
    }
    s.level += (lvl.clamp(0.0, 1.0) - s.level) * (1 - math.exp(-dt * 12));
    _repaint.value++;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _repaint.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox.square(
        dimension: widget.size,
        child: CustomPaint(painter: _OrbPainter(_state, _repaint)),
      ),
    );
  }
}

class _OrbPainter extends CustomPainter {
  final _OrbState s;

  _OrbPainter(this.s, Listenable repaint) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide * 0.30;
    final t = s.time;
    final lvl = s.level;
    final breathe = 1 + 0.025 * math.sin(t * 1.3);

    // Outer glow.
    final glowR = r * (1.65 + 0.45 * lvl) * breathe;
    canvas.drawCircle(
      c,
      glowR,
      Paint()
        ..shader = RadialGradient(
          colors: [
            s.colors[0].withValues(alpha: 0.55 * s.glow),
            s.colors[1].withValues(alpha: 0.18 * s.glow),
            s.colors[1].withValues(alpha: 0),
          ],
          stops: const [0.35, 0.7, 1],
        ).createShader(Rect.fromCircle(center: c, radius: glowR)),
    );

    // Listening ripples.
    if (s.listening > 0.01) {
      for (var i = 0; i < 3; i++) {
        final p = (t * 0.35 + i / 3) % 1.0;
        canvas.drawCircle(
          c,
          r * (1.08 + p * (0.55 + lvl * 0.4)),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.025
            ..color = s.colors[0].withValues(alpha: (1 - p) * 0.45 * s.listening),
        );
      }
    }

    final bounds = Rect.fromCircle(center: c, radius: r * 2);
    canvas.saveLayer(bounds, Paint());

    // Deep tinted core so the orb glows on any background.
    canvas.drawCircle(
      c,
      r * 0.97 * breathe,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Color.lerp(const Color(0xFF0A1030), s.colors[1], 0.55)!,
            Color.lerp(const Color(0xFF0A1030), s.colors[2], 0.35)!,
          ],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );

    for (var i = 0; i < 3; i++) {
      final path = _blob(c, r * breathe * (0.98 + 0.12 * lvl), t, i, lvl);
      final drift = Offset(
            math.cos(t * 0.7 + i * 2.1),
            math.sin(t * 0.9 + i * 1.7),
          ) *
          r *
          0.35;
      canvas.drawPath(
        path,
        Paint()
          ..blendMode = BlendMode.screen
          ..shader = RadialGradient(
            colors: [
              s.colors[i].withValues(alpha: 0.95),
              s.colors[i].withValues(alpha: 0.35),
              s.colors[i].withValues(alpha: 0),
            ],
            stops: const [0, 0.55, 1],
          ).createShader(Rect.fromCircle(center: c + drift, radius: r * 1.25)),
      );
    }

    // Glassy highlight.
    final hl = c + Offset(-r * 0.32, -r * 0.38);
    canvas.drawCircle(
      hl,
      r * 0.55,
      Paint()
        ..blendMode = BlendMode.screen
        ..shader = RadialGradient(
          colors: [Colors.white.withValues(alpha: 0.45), Colors.white.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: hl, radius: r * 0.55)),
    );
    canvas.restore();

    // Thinking: rotating comet ring.
    if (s.thinking > 0.01) {
      final ringR = r * 1.18;
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(t * 2.2);
      canvas.drawCircle(
        Offset.zero,
        ringR,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.07
          ..strokeCap = StrokeCap.round
          ..shader = SweepGradient(
            colors: [
              s.colors[2].withValues(alpha: 0),
              s.colors[0].withValues(alpha: 0.9 * s.thinking),
              Colors.white.withValues(alpha: s.thinking),
            ],
            stops: const [0.4, 0.92, 1],
          ).createShader(Rect.fromCircle(center: Offset.zero, radius: ringR)),
      );
      canvas.restore();
    }
  }

  Path _blob(Offset c, double radius, double t, int i, double lvl) {
    const n = 72;
    final path = Path();
    final phase = i * 2.09;
    final dir = i.isEven ? 1 : -1;
    for (var k = 0; k <= n; k++) {
      final a = k / n * math.pi * 2;
      final w = s.wobble *
              (math.sin(3 * a + t * (1 + i * 0.3) * dir + phase) * 0.6 +
                  math.sin(5 * a - t * 0.7 + phase) * 0.4) +
          lvl * 0.13 * math.sin(4 * a + t * 6 + phase);
      final rr = radius * (1 + w);
      final p = c + Offset(math.cos(a), math.sin(a)) * rr;
      if (k == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    return path..close();
  }

  @override
  bool shouldRepaint(covariant _OrbPainter old) => false;
}

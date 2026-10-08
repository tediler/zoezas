import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/fina.dart';

/// Fina als kleine Figur: ein rosa Tröpfchen mit Sprössling auf dem Kopf.
/// Atmet sanft und blinzelt ab und zu. Rein dekorativ.
class FinaAvatar extends StatefulWidget {
  const FinaAvatar({super.key, this.mood = FinaMood.happy, this.size = 64, this.animate = true});

  final FinaMood mood;
  final double size;
  final bool animate;

  @override
  State<FinaAvatar> createState() => _FinaAvatarState();
}

class _FinaAvatarState extends State<FinaAvatar> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 4200));

  @override
  void initState() {
    super.initState();
    if (widget.animate) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        width: widget.size,
        height: widget.size * 1.12,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = _c.value;
            final breath = math.sin(t * 2 * math.pi);
            // Blinzeln kurz vor Ende jedes Zyklus.
            final blink = t > 0.92 && t < 0.97;
            return CustomPaint(
              painter: _FinaPainter(mood: widget.mood, breath: breath, blink: blink),
            );
          },
        ),
      ),
    );
  }
}

class _FinaPainter extends CustomPainter {
  _FinaPainter({required this.mood, required this.breath, required this.blink});

  final FinaMood mood;
  final double breath;
  final bool blink;

  static const _ink = Color(0xFF3A2F38);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final bob = breath * w * 0.015;
    final squash = 1 + breath * 0.025;

    canvas.save();
    canvas.translate(0, bob);

    // Schatten am Boden
    final shadow = Paint()..color = const Color(0x1A8E4A78);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w / 2, h * 0.95 - bob), width: w * 0.62 / squash, height: h * 0.06),
      shadow,
    );

    // Körper
    final bodyRect = Rect.fromCenter(
      center: Offset(w / 2, h * 0.58),
      width: w * 0.84 * squash,
      height: h * 0.70 / squash,
    );
    final body = Path()
      ..moveTo(bodyRect.center.dx, bodyRect.top)
      ..cubicTo(
        bodyRect.right - w * 0.06,
        bodyRect.top,
        bodyRect.right,
        bodyRect.center.dy - h * 0.08,
        bodyRect.right,
        bodyRect.center.dy + h * 0.04,
      )
      ..cubicTo(
        bodyRect.right,
        bodyRect.bottom - h * 0.02,
        bodyRect.center.dx + w * 0.2,
        bodyRect.bottom,
        bodyRect.center.dx,
        bodyRect.bottom,
      )
      ..cubicTo(
        bodyRect.center.dx - w * 0.2,
        bodyRect.bottom,
        bodyRect.left,
        bodyRect.bottom - h * 0.02,
        bodyRect.left,
        bodyRect.center.dy + h * 0.04,
      )
      ..cubicTo(
        bodyRect.left,
        bodyRect.center.dy - h * 0.08,
        bodyRect.left + w * 0.06,
        bodyRect.top,
        bodyRect.center.dx,
        bodyRect.top,
      )
      ..close();
    final bodyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFAD3E6), Color(0xFFE9A2CF)],
      ).createShader(bodyRect);
    canvas.drawPath(body, bodyPaint);

    // Glanzlicht
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.33, h * 0.38), width: w * 0.16, height: h * 0.09),
      Paint()..color = Colors.white.withValues(alpha: 0.55),
    );

    // Sprössling
    final stemTop = Offset(w / 2, bodyRect.top - h * 0.1);
    final stem = Paint()
      ..color = const Color(0xFF7DBF98)
      ..strokeWidth = w * 0.035
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(w / 2, bodyRect.top + h * 0.01), stemTop, stem);
    final leaf = Paint()..color = const Color(0xFF9ED3B5);
    canvas.save();
    canvas.translate(stemTop.dx, stemTop.dy);
    canvas.rotate(-0.6 + breath * 0.06);
    canvas.drawOval(Rect.fromLTWH(-w * 0.15, -h * 0.045, w * 0.15, h * 0.07), leaf);
    canvas.restore();
    canvas.save();
    canvas.translate(stemTop.dx, stemTop.dy);
    canvas.rotate(0.6 - breath * 0.06);
    canvas.drawOval(Rect.fromLTWH(0, -h * 0.045, w * 0.15, h * 0.07), leaf);
    canvas.restore();

    // Gesicht
    final eyeY = h * 0.56;
    final eyeDx = w * 0.15;
    final ink = Paint()
      ..color = _ink
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.035;
    final inkFill = Paint()..color = _ink;

    final closedHappy = mood == FinaMood.proud;
    final closedSleepy = mood == FinaMood.sleepy || blink;
    for (final dx in [-eyeDx, eyeDx]) {
      final c = Offset(w / 2 + dx, eyeY);
      if (closedHappy && !blink) {
        final r = Rect.fromCenter(center: c.translate(0, h * 0.012), width: w * 0.1, height: h * 0.07);
        canvas.drawArc(r, math.pi, math.pi, false, ink);
      } else if (closedSleepy) {
        final r = Rect.fromCenter(center: c.translate(0, -h * 0.01), width: w * 0.1, height: h * 0.05);
        canvas.drawArc(r, 0, math.pi, false, ink);
      } else {
        canvas.drawOval(Rect.fromCenter(center: c, width: w * 0.075, height: h * 0.085), inkFill);
        canvas.drawCircle(c.translate(-w * 0.012, -h * 0.018), w * 0.014, Paint()..color = Colors.white);
      }
      if (mood == FinaMood.concerned) {
        final browY = eyeY - h * 0.075;
        final inner = dx < 0 ? 1 : -1;
        canvas.drawLine(
          Offset(c.dx - w * 0.04 * inner, browY + h * 0.012),
          Offset(c.dx + w * 0.035 * inner, browY - h * 0.012),
          ink..strokeWidth = w * 0.025,
        );
        ink.strokeWidth = w * 0.035;
      }
    }

    // Wangen
    final cheek = Paint()..color = const Color(0xFFF07FAE).withValues(alpha: 0.45);
    for (final dx in [-w * 0.25, w * 0.25]) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(w / 2 + dx, eyeY + h * 0.07), width: w * 0.12, height: h * 0.055),
        cheek,
      );
    }

    // Mund
    final mouthC = Offset(w / 2, eyeY + h * 0.085);
    switch (mood) {
      case FinaMood.happy:
        canvas.drawArc(
          Rect.fromCenter(center: mouthC, width: w * 0.13, height: h * 0.07),
          0.15,
          math.pi - 0.3,
          false,
          ink,
        );
      case FinaMood.proud:
        final p = Path()
          ..moveTo(mouthC.dx - w * 0.075, mouthC.dy - h * 0.012)
          ..quadraticBezierTo(mouthC.dx, mouthC.dy + h * 0.08, mouthC.dx + w * 0.075, mouthC.dy - h * 0.012)
          ..close();
        canvas.drawPath(p, inkFill);
        canvas.drawOval(
          Rect.fromCenter(center: mouthC.translate(0, h * 0.025), width: w * 0.06, height: h * 0.022),
          Paint()..color = const Color(0xFFF07FAE),
        );
      case FinaMood.calm:
        canvas.drawArc(
          Rect.fromCenter(center: mouthC, width: w * 0.09, height: h * 0.04),
          0.2,
          math.pi - 0.4,
          false,
          ink,
        );
      case FinaMood.concerned:
        canvas.drawOval(
          Rect.fromCenter(center: mouthC.translate(0, h * 0.01), width: w * 0.06, height: h * 0.05),
          inkFill,
        );
      case FinaMood.sleepy:
        canvas.drawOval(
          Rect.fromCenter(center: mouthC.translate(0, h * 0.01), width: w * 0.045, height: h * 0.035),
          inkFill,
        );
        final tp = TextPainter(
          text: TextSpan(
            text: 'z',
            style: TextStyle(fontSize: w * 0.18, color: const Color(0xFFB98AAE), fontWeight: FontWeight.w600),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(w * 0.8, h * 0.18 - breath * h * 0.02));
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_FinaPainter old) => old.breath != breath || old.blink != blink || old.mood != mood;
}

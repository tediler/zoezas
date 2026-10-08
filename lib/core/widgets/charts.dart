import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../format/money.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

class DonutSegment {
  const DonutSegment(this.value, this.color);
  final double value;
  final Color color;
}

/// Ringdiagramm mit runden Segmentenden und kleinen Lücken.
class DonutChart extends StatelessWidget {
  const DonutChart({super.key, required this.segments, this.size = 180, this.thickness = 22, this.center});

  final List<DonutSegment> segments;
  final double size;
  final double thickness;
  final Widget? center;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (_, t, child) => CustomPaint(painter: _DonutPainter(segments, thickness, t), child: child),
        child: Center(child: center),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.segments, this.thickness, this.progress);

  final List<DonutSegment> segments;
  final double thickness;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(thickness / 2, thickness / 2, size.width - thickness, size.height - thickness);
    final bg = Paint()
      ..color = ZColors.accentSoft
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness;
    canvas.drawArc(rect, 0, math.pi * 2, false, bg);

    final total = segments.fold<double>(0, (s, e) => s + e.value);
    if (total <= 0) return;
    final gap = segments.length > 1 ? 0.06 : 0.0;
    var start = -math.pi / 2;
    final sweepTotal = math.pi * 2 * progress;
    for (final s in segments) {
      final sweep = s.value / total * sweepTotal;
      final drawn = math.max(0.0, sweep - gap);
      if (drawn > 0.001) {
        canvas.drawArc(
          rect,
          start + gap / 2,
          drawn,
          false,
          Paint()
            ..color = s.color
            ..style = PaintingStyle.stroke
            ..strokeWidth = thickness
            ..strokeCap = segments.length > 1 && drawn > 0.12 ? StrokeCap.round : StrokeCap.butt,
        );
      }
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) => old.progress != progress || old.segments != segments;
}

class BarGroup {
  const BarGroup({required this.label, required this.values, this.highlight = false});
  final String label;
  final List<int> values;
  final bool highlight;
}

/// Säulendiagramm mit einer oder mehreren Säulen je Gruppe (z. B. Einnahmen
/// und Ausgaben je Monat). Negative Werte wachsen nach unten.
class BarChart extends StatelessWidget {
  const BarChart({super.key, required this.groups, required this.colors, this.height = 160, this.negativeColor});

  final List<BarGroup> groups;
  final List<Color> colors;
  final double height;
  final Color? negativeColor;

  @override
  Widget build(BuildContext context) {
    final maxPos = groups.expand((g) => g.values).fold<int>(0, (m, v) => math.max(m, v));
    final maxNeg = groups.expand((g) => g.values).fold<int>(0, (m, v) => math.max(m, -v));
    final range = math.max(1, maxPos + maxNeg);
    final zeroFrac = maxPos / range;
    return SizedBox(
      height: height + 26,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOutCubic,
        builder: (_, t, _) => Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final g in groups)
              Expanded(
                child: Column(
                  children: [
                    SizedBox(
                      height: height,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = 0; i < g.values.length; i++)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              child: _Bar(
                                value: g.values[i],
                                range: range,
                                zeroFrac: zeroFrac,
                                height: height,
                                t: t,
                                color: g.values[i] < 0
                                    ? (negativeColor ?? ZColors.negative)
                                    : colors[i % colors.length],
                                width: g.values.length > 1 ? 9 : 16,
                                faded: !g.highlight && groups.any((x) => x.highlight),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      g.label,
                      style: ZText.small.copyWith(
                        fontSize: 11,
                        color: g.highlight ? ZColors.text : ZColors.textSecondary,
                        fontWeight: g.highlight ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.value,
    required this.range,
    required this.zeroFrac,
    required this.height,
    required this.t,
    required this.color,
    required this.width,
    required this.faded,
  });

  final int value;
  final int range;
  final double zeroFrac;
  final double height;
  final double t;
  final Color color;
  final double width;
  final bool faded;

  @override
  Widget build(BuildContext context) {
    final zeroY = height * zeroFrac;
    final h = (value.abs() / range * height * t);
    final top = value >= 0 ? zeroY - h : zeroY;
    return SizedBox(
      width: width,
      child: Stack(
        children: [
          Positioned(
            top: top,
            left: 0,
            right: 0,
            height: math.max(value == 0 ? 0 : 3, h),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: faded ? color.withValues(alpha: 0.45) : color,
                borderRadius: BorderRadius.circular(width / 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Legende für Diagramme.
class ChartLegend extends StatelessWidget {
  const ChartLegend({super.key, required this.items});
  final List<(String, Color)> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 6,
      children: [
        for (final (label, color) in items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(label, style: ZText.small),
            ],
          ),
      ],
    );
  }
}

/// Kompakter Betrag für Achsen und Legenden („1,2 Tsd. €“).
String compactMoney(int cents) {
  final euros = cents.abs() / 100;
  if (euros >= 10000) return '${cents < 0 ? '−' : ''}${(euros / 1000).toStringAsFixed(0)} Tsd. €';
  return Money.format(cents, compact: true);
}

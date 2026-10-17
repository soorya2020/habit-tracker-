import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/models.dart';
import '../ui/theme.dart';

/// The balance avatar. Each line fills with one area:
/// head = Intellect, body = Social, arms = Craft, legs = Physical,
/// halo = Mind, ground = Wealth.
class CharacterFigure extends StatelessWidget {
  const CharacterFigure({super.key, required this.strengths, this.size = 160, this.tokens});

  final Map<Area, int> strengths;
  final double size;
  final Tokens? tokens;

  @override
  Widget build(BuildContext context) {
    final t = tokens ?? Tokens.night;
    return Semantics(
      label: 'Avatar. ${[for (final a in Area.values) '${a.label} ${strengths[a]}'].join(', ')}',
      child: SizedBox(
        width: size * 240 / 296,
        height: size,
        child: CustomPaint(painter: _FigurePainter(strengths, t)),
      ),
    );
  }
}

/// The neon hero: a line figure, hands on hips. Each line fills with its
/// area's colour like a progress bar, growing out from the body, and glows.
class _FigurePainter extends CustomPainter {
  _FigurePainter(this.v, this.t);

  final Map<Area, int> v;
  final Tokens t;

  bool get _dark => t.screen.computeLuminance() < .5;
  Color get _track => _dark ? const Color(0xFF262C52) : const Color(0xFFDDE1EA);

  static Path _body() => Path()
    ..moveTo(120, 56)
    ..lineTo(120, 66)
    ..moveTo(120, 66)
    ..quadraticBezierTo(96, 66, 88, 76)
    ..quadraticBezierTo(92, 108, 102, 132)
    ..quadraticBezierTo(100, 146, 104, 156)
    ..lineTo(136, 156)
    ..quadraticBezierTo(140, 146, 138, 132)
    ..quadraticBezierTo(148, 108, 152, 76)
    ..quadraticBezierTo(144, 66, 120, 66);

  static Path _line(List<Offset> p) {
    final path = Path()..moveTo(p.first.dx, p.first.dy);
    for (final x in p.skip(1)) {
      path.lineTo(x.dx, x.dy);
    }
    return path;
  }

  static Path _ring(Offset c, double r) =>
      Path()..addArc(Rect.fromCircle(center: c, radius: r), -math.pi / 2, 2 * math.pi - .001);

  static final _parts = <(Area, Path, double)>[
    (Area.mind, _ring(const Offset(120, 38), 28), 2),
    (Area.wealth, _line(const [Offset(60, 280), Offset(180, 280)]), 3),
    (Area.social, _body(), 4.5),
    (Area.craft, _line(const [Offset(90, 80), Offset(66, 112), Offset(98, 136)]), 4.5),
    (Area.craft, _line(const [Offset(150, 80), Offset(174, 112), Offset(142, 136)]), 4.5),
    (Area.physical, _line(const [Offset(110, 158), Offset(96, 212), Offset(84, 262), Offset(72, 266)]), 4.5),
    (Area.physical, _line(const [Offset(130, 158), Offset(144, 212), Offset(156, 262), Offset(168, 266)]), 4.5),
    (Area.intellect, _ring(const Offset(120, 38), 17), 4.5),
  ];

  static const _joints = <(Offset, Area)>[
    (Offset(90, 80), Area.craft),
    (Offset(66, 112), Area.craft),
    (Offset(150, 80), Area.craft),
    (Offset(174, 112), Area.craft),
    (Offset(96, 212), Area.physical),
    (Offset(144, 212), Area.physical),
    (Offset(84, 262), Area.physical),
    (Offset(156, 262), Area.physical),
  ];

  /// The first [f] of [path], across all of its pieces in order.
  static Path _portion(Path path, double f) {
    final metrics = path.computeMetrics().toList();
    var left = metrics.fold(0.0, (n, m) => n + m.length) * f;
    final out = Path();
    for (final m in metrics) {
      if (left <= 0) break;
      out.addPath(m.extractPath(0, math.min(left, m.length)), Offset.zero);
      left -= m.length;
    }
    return out;
  }

  Paint _stroke(Color c, double w) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = c;

  @override
  void paint(Canvas canvas, Size size) {
    // Drawn on a 240×296 grid.
    final s = math.min(size.width / 240, size.height / 296);
    canvas.translate((size.width - 240 * s) / 2, (size.height - 296 * s) / 2 + 4 * s);
    canvas.scale(s);

    final blur = MaskFilter.blur(BlurStyle.normal, _dark ? 3.2 : 1.6);
    for (final (a, path, w) in _parts) {
      canvas.drawPath(path, _stroke(a == Area.mind ? _track.withValues(alpha: .7) : _track, w));
      final f = ((v[a] ?? 0) / 100).clamp(0.0, 1.0);
      if (f == 0) continue;
      final lit = _portion(path, f);
      canvas.drawPath(lit, _stroke(t.area(a), w)..maskFilter = blur);
      canvas.drawPath(lit, _stroke(t.area(a), w));
    }
    for (final (p, a) in _joints) {
      final on = (v[a] ?? 0) > 0;
      if (on) canvas.drawCircle(p, 3.4, Paint()..color = t.area(a)..maskFilter = blur);
      canvas.drawCircle(p, 3.4, Paint()..color = on ? t.area(a) : _track);
    }
  }

  @override
  bool shouldRepaint(_FigurePainter old) => old.v != v || old.t != t;
}

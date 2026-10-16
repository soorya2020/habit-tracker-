import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/models.dart';
import '../ui/theme.dart';

/// The balance avatar. Each body part glows with one area:
/// head = Intellect, torso = Social, arms = Craft, legs = Physical,
/// aura = Mind, ground ring = Wealth.
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
        width: size * .8,
        height: size,
        child: CustomPaint(painter: _FigurePainter(strengths, t)),
      ),
    );
  }
}

class _FigurePainter extends CustomPainter {
  _FigurePainter(this.v, this.t);

  final Map<Area, int> v;
  final Tokens t;

  double _op(Area a) => .12 + .88 * (v[a] ?? 0) / 100;

  @override
  void paint(Canvas canvas, Size size) {
    // Drawn on a 240×300 grid, like the design.
    final s = math.min(size.width / 240, size.height / 300);
    canvas.translate((size.width - 240 * s) / 2, (size.height - 300 * s) / 2);
    canvas.scale(s);

    final mind = (v[Area.mind] ?? 0) / 100;
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(120, 140), width: 192, height: 264),
      Paint()
        ..shader = RadialGradient(colors: [
          t.area(Area.mind).withValues(alpha: mind * .7),
          t.area(Area.mind).withValues(alpha: 0),
        ]).createShader(Rect.fromCenter(center: const Offset(120, 140), width: 192, height: 264)),
    );

    // Wealth: ground ring.
    final ground = Rect.fromCenter(center: const Offset(120, 280), width: 116, height: 18);
    canvas.drawOval(ground, Paint()..color = t.heat0);
    final w = (v[Area.wealth] ?? 0) / 100;
    if (w > 0) {
      canvas.drawOval(
          Rect.fromCenter(center: const Offset(120, 280), width: 116 * w, height: 18),
          Paint()..color = t.area(Area.wealth));
    }

    void limb(List<Offset> pts, double width, Area a) {
      final path = Path()..moveTo(pts[0].dx, pts[0].dy);
      for (final p in pts.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      final base = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(path, base..color = t.heat0);
      _glow(canvas, a, (p) => canvas.drawPath(path, p..style = PaintingStyle.stroke..strokeWidth = width..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round));
    }

    limb(const [Offset(84, 86), Offset(72, 132), Offset(68, 172)], 13, Area.craft);
    limb(const [Offset(156, 86), Offset(168, 132), Offset(172, 172)], 13, Area.craft);
    limb(const [Offset(107, 158), Offset(103, 212), Offset(101, 264)], 17, Area.physical);
    limb(const [Offset(133, 158), Offset(137, 212), Offset(139, 264)], 17, Area.physical);

    final torso = Path()
      ..moveTo(84, 80)
      ..quadraticBezierTo(120, 70, 156, 80)
      ..lineTo(148, 156)
      ..quadraticBezierTo(120, 166, 92, 156)
      ..close();
    canvas.drawPath(torso, Paint()..color = t.heat0);
    _glow(canvas, Area.social, (p) => canvas.drawPath(torso, p));

    canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(113, 60, 14, 14), const Radius.circular(4)),
        Paint()..color = t.heat0);
    canvas.drawCircle(const Offset(120, 40), 22, Paint()..color = t.heat0);
    _glow(canvas, Area.intellect, (p) => canvas.drawCircle(const Offset(120, 40), 22, p));
  }

  void _glow(Canvas canvas, Area a, void Function(Paint) draw) {
    final c = t.area(a).withValues(alpha: _op(a));
    if ((v[a] ?? 0) >= 50) {
      draw(Paint()
        ..color = t.area(a).withValues(alpha: .55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    }
    draw(Paint()..color = c);
  }

  @override
  bool shouldRepaint(_FigurePainter old) => old.v != v || old.t != t;
}

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/motivation.dart';
import '../../domain/scoring.dart';
import '../../state/person_view.dart';
import '../../ui/theme.dart';
import '../../widgets/character_figure.dart';
import '../../ui/haptics.dart';

/// Something worth a moment of celebration.
class Win {
  const Win(this.emoji, this.title, this.body);
  final String emoji, title, body;
}

/// Finds wins since the last look and shows them once each. The first time
/// it runs for a member it only remembers where they are, so old progress
/// doesn't pop up on a new phone.
class Celebrations {
  static bool _showing = false;

  /// Titles in the order they are earned, for spotting a step up.
  static int _rank(String title) => switch (title) {
        Titles.starting => 0,
        Titles.polymath => 2,
        Titles.complete => 3,
        _ => 1,
      };

  static List<Win> wins(PersonView me, {required int level, required String title, required int streak}) {
    final out = <Win>[];
    if (_rank(me.title) > _rank(title) || (_rank(me.title) == 1 && _rank(title) == 1 && me.title != title)) {
      out.add(Win('🏆', 'New title: ${me.title}', 'Your areas earned it. ${me.nextStep}'));
    }
    if (me.level.level > level) {
      out.add(Win('⭐', 'Level ${me.level.level}!', 'Every logged day got you here. ${me.level.toNext} XP to the next one.'));
    }
    final passed = Milestones.all.where((m) => m > streak && m <= me.streak.current).toList();
    if (passed.isNotEmpty) {
      out.add(Win('🔥', '${passed.last}-day streak!',
          '${passed.last} days in a row. Next milestone: ${Milestones.next(me.streak.current)} days.'));
    }
    return out;
  }

  static Future<void> check(BuildContext context, PersonView me) async {
    if (_showing) return;
    final prefs = await SharedPreferences.getInstance();
    final k = 'celebrated.${me.uid}';
    final level = prefs.getInt('$k.level');
    final title = prefs.getString('$k.title');
    final streak = prefs.getInt('$k.streak');
    Future<void> remember() async {
      await prefs.setInt('$k.level', me.level.level);
      await prefs.setString('$k.title', me.title);
      await prefs.setInt('$k.streak', me.streak.current);
    }

    if (level == null || title == null || streak == null) return remember();
    final found = wins(me, level: level, title: title, streak: streak);
    await remember();
    if (found.isEmpty || !context.mounted) return;
    _showing = true;
    try {
      for (final w in found) {
        if (!context.mounted) break;
        Haptics.celebrate();
        await showDialog<void>(
          context: context,
          useRootNavigator: true,
          builder: (_) => _WinDialog(win: w, me: me),
        );
      }
    } finally {
      _showing = false;
    }
  }
}

class _WinDialog extends StatelessWidget {
  const _WinDialog({required this.win, required this.me});
  final Win win;
  final PersonView me;

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      _card(context),
      const Positioned.fill(child: IgnorePointer(child: Confetti())),
    ]);
  }

  Widget _card(BuildContext context) {
    final t = context.tk;
    final light = Theme.of(context).brightness == Brightness.light;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: .85, end: 1),
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutBack,
        builder: (_, s, child) => Transform.scale(scale: s, child: child),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: t.line),
            gradient: RadialGradient(
              center: Alignment.topCenter,
              radius: 1.2,
              colors: light ? const [Color(0xFFE3E8FC), Color(0xFFFFFFFF)] : const [Color(0xFF1B2050), Color(0xFF0A0D1C)],
              stops: const [0, .75],
            ),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(win.emoji, style: const TextStyle(fontSize: 44)),
            const SizedBox(height: 4),
            CharacterFigure(strengths: me.strengths, size: 130, tokens: light ? Tokens.light : Tokens.night),
            const SizedBox(height: 12),
            Text(win.title, textAlign: TextAlign.center, style: display(24, t.ink)),
            const SizedBox(height: 8),
            Text(win.body, textAlign: TextAlign.center, style: context.tx.bodyMedium?.copyWith(color: t.muted)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Keep going')),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Party-popper burst: two cannons at the bottom corners fire coloured
/// paper that tumbles and falls.
class Confetti extends StatefulWidget {
  const Confetti({super.key});

  @override
  State<Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<Confetti> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));
  final _bits = <_Bit>[];

  @override
  void initState() {
    super.initState();
    final r = math.Random();
    const colors = [Color(0xFFF08A70), Color(0xFFA991F0), Color(0xFF7C90FF), Color(0xFFE8B04A), Color(0xFF4CC4AC), Color(0xFFA3C55A)];
    for (var i = 0; i < 90; i++) {
      final left = i.isEven;
      // Aim up and towards the middle, with some spread.
      final angle = (left ? -math.pi / 3 : -2 * math.pi / 3) + (r.nextDouble() - .5) * .8;
      final speed = 1.1 + r.nextDouble() * .9;
      _bits.add(_Bit(
        left: left,
        vx: math.cos(angle) * speed,
        vy: math.sin(angle) * speed,
        spin: (r.nextDouble() - .5) * 18,
        size: 6 + r.nextDouble() * 6,
        color: colors[i % colors.length],
        round: r.nextDouble() < .3,
      ));
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (!still && !_c.isAnimating && _c.value == 0) _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, _) => CustomPaint(painter: _ConfettiPainter(_bits, _c.value)),
      );
}

class _Bit {
  _Bit({required this.left, required this.vx, required this.vy, required this.spin, required this.size, required this.color, required this.round});
  final bool left, round;
  final double vx, vy, spin, size;
  final Color color;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.bits, this.t);
  final List<_Bit> bits;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    if (t == 0 || t == 1) return;
    final s = t * 2.6; // seconds
    const gravity = .9;
    for (final b in bits) {
      final x = (b.left ? 0 : size.width) + b.vx * s * size.width * .55;
      final y = size.height + (b.vy * s + gravity * s * s / 2) * size.height * .55;
      final fade = t > .75 ? (1 - t) / .25 : 1.0;
      final p = Paint()..color = b.color.withValues(alpha: fade);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(b.spin * s);
      if (b.round) {
        canvas.drawCircle(Offset.zero, b.size / 2.4, p);
      } else {
        // Flutters by squashing one side as it turns.
        canvas.scale(1, math.cos(b.spin * s * 1.3).abs() * .8 + .2);
        canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: b.size, height: b.size * .55), p);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}

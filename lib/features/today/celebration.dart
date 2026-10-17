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

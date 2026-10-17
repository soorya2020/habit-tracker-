import 'package:flutter/material.dart';

import '../../domain/models.dart';
import '../../state/person_view.dart';
import '../../ui/theme.dart';
import '../../widgets/character_figure.dart';
import '../../widgets/common.dart';

/// Avatar, level, title, XP and area bars: a deep-blue panel in the dark
/// theme, a soft blue one in the light theme.
class CharacterCard extends StatelessWidget {
  const CharacterCard({super.key, required this.me, this.strengths, this.caption});

  final PersonView me;

  /// Shown instead of the current strengths (used by Future).
  final Map<Area, int>? strengths;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    final n = light ? Tokens.light : Tokens.night;
    final v = strengths ?? me.strengths;
    final lv = me.level;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: light ? Border.all(color: n.line) : null,
        gradient: RadialGradient(
          center: Alignment.topCenter,
          radius: 1.2,
          colors: light ? const [Color(0xFFE3E8FC), Color(0xFFFFFFFF)] : const [Color(0xFF1B2050), Color(0xFF0A0D1C)],
          stops: const [0, .7],
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          CharacterFigure(strengths: v, size: 170, tokens: n),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Eyebrow('Level ${lv.level} · ${me.profile.name}', color: n.muted),
              const SizedBox(height: 6),
              Text(me.title, style: display(26, n.ink)),
              const SizedBox(height: 12),
              Bar(value: lv.progress, color: n.accent, track: n.heat0),
              const SizedBox(height: 6),
              Text('${lv.into} / ${lv.cost} XP to level ${lv.level + 1}', style: mono(11, n.muted)),
              if (caption != null) ...[
                const SizedBox(height: 8),
                Text(caption!, style: TextStyle(color: n.muted, fontSize: 12.5)),
              ],
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        for (final a in Area.values) ...[
          _AreaRow(area: a, value: v[a] ?? 0, resting: me.profile.resting.contains(a), tokens: n),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: light ? n.screen : Colors.white.withValues(alpha: .05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: n.line),
          ),
          child: Text(
            v.values.every((x) => x == 0)
                ? 'Your areas fill up as you log habits. They show the last four weeks, so they grow '
                    'back quickly once you are logging again.'
                : me.nextStep,
            style: TextStyle(color: n.ink, fontSize: 13.5),
          ),
        ),
      ]),
    );
  }
}

class _AreaRow extends StatelessWidget {
  const _AreaRow({required this.area, required this.value, required this.resting, required this.tokens});
  final Tokens tokens;
  final Area area;
  final int value;
  final bool resting;

  @override
  Widget build(BuildContext context) {
    final n = tokens;
    return Opacity(
      opacity: resting ? .45 : 1,
      child: Row(children: [
        SizedBox(width: 74, child: Text(area.label, style: TextStyle(color: n.ink, fontSize: 13))),
        Expanded(child: SegmentBar(value: value, color: n.area(area), track: n.heat0)),
        SizedBox(
          width: 52,
          child: Text(resting ? 'rest' : '$value', textAlign: TextAlign.right, style: mono(12, n.muted)),
        ),
      ]),
    );
  }
}

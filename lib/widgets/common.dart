import 'package:flutter/material.dart';

import '../domain/models.dart';
import '../ui/theme.dart';
import '../ui/haptics.dart';

class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.color, this.onTap});

  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Material(
      color: color ?? t.surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: color == null ? t.line : Colors.transparent)),
      clipBehavior: Clip.antiAlias,
      child: Semantics(
        button: onTap != null,
        child: InkWell(
          onTap: onTap == null ? null : () {
            Haptics.tap();
            onTap!();
          },
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Small uppercase mono label.
class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key, this.color});
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) =>
      Text(text.toUpperCase(), style: mono(11, color ?? context.tk.muted));
}

class AreaDot extends StatelessWidget {
  const AreaDot(this.area, {super.key, this.size = 8});
  final Area area;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: context.tk.area(area), shape: BoxShape.circle),
      );
}

class Callout extends StatelessWidget {
  const Callout({super.key, required this.title, required this.body, this.actions = const [], this.tone});

  final String title;
  final String body;
  final List<Widget> actions;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    final c = tone ?? t.warn;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.withValues(alpha: .35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: context.tx.titleMedium),
          const SizedBox(height: 4),
          Text(body, style: context.tx.bodyMedium?.copyWith(color: t.muted)),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: actions),
          ],
        ],
      ),
    );
  }
}

/// A thin progress bar with rounded ends.
class Bar extends StatelessWidget {
  const Bar({super.key, required this.value, this.color, this.height = 6, this.track});

  final double value;
  final Color? color;
  final Color? track;
  final double height;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        child: Stack(children: [
          Positioned.fill(child: ColoredBox(color: track ?? t.heat0)),
          Positioned.fill(
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: value.clamp(0, 1).toDouble(),
              child: ColoredBox(color: color ?? t.accent),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Ten segments, used for area strength.
class SegmentBar extends StatelessWidget {
  const SegmentBar({super.key, required this.value, required this.color, this.track});

  final int value; // 0..100
  final Color color;
  final Color? track;

  @override
  Widget build(BuildContext context) {
    final filled = value / 10;
    return Row(
      children: [
        for (var i = 0; i < 10; i++) ...[
          if (i > 0) const SizedBox(width: 2),
          Expanded(
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: Color.lerp(track ?? context.tk.heat0, color,
                    (filled - i).clamp(0, 1).toDouble()),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class ChoiceChips<T> extends StatelessWidget {
  const ChoiceChips({super.key, required this.values, required this.selected, required this.label, required this.onSelect, this.leading});

  final List<T> values;
  final bool Function(T) selected;
  final String Function(T) label;
  final void Function(T) onSelect;
  final Widget Function(T)? leading;

  @override
  Widget build(BuildContext context) {
    final t = context.tk;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final v in values)
          ChoiceChip(
            label: Row(mainAxisSize: MainAxisSize.min, children: [
              if (leading != null) ...[leading!(v), const SizedBox(width: 6)],
              Text(label(v)),
            ]),
            selected: selected(v),
            onSelected: (_) => onSelect(v),
            showCheckmark: false,
            selectedColor: t.accentSoft,
            backgroundColor: t.surface,
            side: BorderSide(color: selected(v) ? t.accent : t.line),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            labelStyle: TextStyle(color: selected(v) ? t.accent : t.ink, fontWeight: FontWeight.w500),
          ),
      ],
    );
  }
}

const weekdayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
const weekdayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String fmtMinutes(int m) =>
    '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';

/// "Mon–Fri", "Tue, Fri", "Every day" or "3× a week".
String scheduleText(HabitRule r) {
  if (r.mode == HabitMode.maintain) return '${r.perWeek}× a week, any days';
  final d = r.days.toList()..sort();
  if (d.length == 7) return 'Every day';
  if (d.join() == '12345') return 'Mon–Fri';
  if (d.join() == '123456') return 'Mon–Sat';
  if (d.join() == '67') return 'Weekends';
  return d.map((x) => weekdayShort[x - 1]).join(', ');
}

String fmtNumber(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

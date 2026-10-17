import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/day.dart';
import '../../domain/models.dart';
import '../../domain/scoring.dart';
import '../../state/providers.dart';
import '../../ui/haptics.dart';

/// One-tap done, or clears the log if it was already done.
Future<void> quickToggle(BuildContext context, WidgetRef ref, Habit h, Day day) async {
  final me = ref.read(meProvider);
  final before = me.logOn(h, day);
  final actions = ref.read(actionsProvider);
  if (before != null && before.status != LogStatus.missed) {
    Haptics.tap();
    await actions.restore(h, day, null);
    if (context.mounted) showUndo(context, ref, h, day, before, '${h.name} cleared');
    return;
  }
  final xp = Xp.shareOf(me.schedule, h, day, LogStatus.done);
  Haptics.success();
  await actions.log(h, day, LogStatus.done,
      value: h.kind == TrackKind.amount ? h.ruleOn(day).target : null);
  if (context.mounted) showUndo(context, ref, h, day, before, '${h.name} · +$xp XP');
}

void showUndo(BuildContext context, WidgetRef ref, Habit h, Day day, LogEntry? before, String text) {
  final actions = ref.read(actionsProvider);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(text),
      duration: const Duration(seconds: 4),
      action: SnackBarAction(label: 'Undo', onPressed: () {
        Haptics.tap();
        actions.restore(h, day, before);
      }),
    ));
}

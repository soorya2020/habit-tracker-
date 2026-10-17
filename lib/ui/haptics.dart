import 'package:flutter/services.dart';

/// Small vibrations so taps feel physical.
class Haptics {
  /// Opening something, pressing a button.
  static void tap() => HapticFeedback.lightImpact();

  /// Switching tabs or choices.
  static void select() => HapticFeedback.selectionClick();

  /// Logging a habit as done.
  static void success() => HapticFeedback.mediumImpact();

  /// A new title, level or streak milestone.
  static Future<void> celebrate() async {
    await HapticFeedback.heavyImpact();
    await Future<void>.delayed(const Duration(milliseconds: 120));
    await HapticFeedback.heavyImpact();
  }
}

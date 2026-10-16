import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../domain/models.dart';

/// The "Clean" design tokens.
@immutable
class Tokens extends ThemeExtension<Tokens> {
  const Tokens({
    required this.screen,
    required this.surface,
    required this.ink,
    required this.muted,
    required this.line,
    required this.accent,
    required this.accentSoft,
    required this.warn,
    required this.ok,
    required this.miss,
    required this.heat0,
    required this.areas,
  });

  final Color screen, surface, ink, muted, line, accent, accentSoft;
  final Color warn, ok, miss, heat0;
  final Map<Area, Color> areas;

  static const light = Tokens(
    screen: Color(0xFFFBFBFC),
    surface: Color(0xFFFFFFFF),
    ink: Color(0xFF111318),
    muted: Color(0xFF626774),
    line: Color(0xFFE2E4EA),
    accent: Color(0xFF2F49D1),
    accentSoft: Color(0xFFE6EAFB),
    warn: Color(0xFFB86E00),
    ok: Color(0xFF1F8F5F),
    miss: Color(0xFFC2414B),
    heat0: Color(0xFFE7E9EE),
    areas: {
      Area.physical: Color(0xFFC8553D),
      Area.mind: Color(0xFF7A5BC7),
      Area.intellect: Color(0xFF2F49D1),
      Area.social: Color(0xFFB87A06),
      Area.craft: Color(0xFF1F8F7A),
      Area.wealth: Color(0xFF5B7A1A),
    },
  );

  static const dark = Tokens(
    screen: Color(0xFF111318),
    surface: Color(0xFF181B21),
    ink: Color(0xFFECEDF1),
    muted: Color(0xFF9298A6),
    line: Color(0xFF262A33),
    accent: Color(0xFF7C90FF),
    accentSoft: Color(0xFF1E2550),
    warn: Color(0xFFE8B04A),
    ok: Color(0xFF4CC48D),
    miss: Color(0xFFF07C85),
    heat0: Color(0xFF22262E),
    areas: _brightAreas,
  );

  /// The deep-blue "character" panel used on Insights and Future.
  static const night = Tokens(
    screen: Color(0xFF0A0D1C),
    surface: Color(0xFF12162B),
    ink: Color(0xFFEEF0FF),
    muted: Color(0xFF8D93B8),
    line: Color(0xFF2C335A),
    accent: Color(0xFF7C90FF),
    accentSoft: Color(0xFF1E2550),
    warn: Color(0xFFE8B04A),
    ok: Color(0xFF4CC48D),
    miss: Color(0xFFF07C85),
    heat0: Color(0xFF1B2040),
    areas: _brightAreas,
  );

  static const _brightAreas = {
    Area.physical: Color(0xFFF08A70),
    Area.mind: Color(0xFFA991F0),
    Area.intellect: Color(0xFF7C90FF),
    Area.social: Color(0xFFE8B04A),
    Area.craft: Color(0xFF4CC4AC),
    Area.wealth: Color(0xFFA3C55A),
  };

  Color area(Area a) => areas[a]!;

  @override
  Tokens copyWith() => this;

  @override
  Tokens lerp(Tokens? other, double t) => t < .5 ? this : (other ?? this);
}

extension TokensX on BuildContext {
  Tokens get tk => Theme.of(this).extension<Tokens>()!;
  TextTheme get tx => Theme.of(this).textTheme;
}

TextStyle display(double size, Color color) => GoogleFonts.bricolageGrotesque(
    fontSize: size,
    fontWeight: FontWeight.w600,
    letterSpacing: -size * .03,
    height: 1.1,
    color: color);

TextStyle mono(double size, Color color, {FontWeight w = FontWeight.w500}) =>
    GoogleFonts.geistMono(
        fontSize: size, fontWeight: w, color: color, letterSpacing: .4);

ThemeData buildTheme(Brightness b) {
  final t = b == Brightness.light ? Tokens.light : Tokens.dark;
  final base = ThemeData(
    brightness: b,
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: t.accent,
      brightness: b,
      primary: t.accent,
      surface: t.screen,
      onSurface: t.ink,
      error: t.miss,
    ),
    scaffoldBackgroundColor: t.screen,
    fontFamily: GoogleFonts.geist().fontFamily,
    extensions: [t],
  );
  final body = base.textTheme.apply(bodyColor: t.ink, displayColor: t.ink);
  return base.copyWith(
    textTheme: body.copyWith(
      headlineMedium: display(26, t.ink),
      headlineSmall: display(22, t.ink),
      titleLarge: display(19, t.ink),
      titleMedium: body.titleMedium?.copyWith(fontWeight: FontWeight.w600, fontSize: 15),
      bodyMedium: body.bodyMedium?.copyWith(fontSize: 14, height: 1.45),
      bodySmall: body.bodySmall?.copyWith(fontSize: 12.5, color: t.muted),
      labelSmall: mono(11, t.muted),
    ),
    dividerTheme: DividerThemeData(color: t.line, thickness: 1, space: 1),
    appBarTheme: AppBarTheme(
      backgroundColor: t.screen,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: display(19, t.ink),
      foregroundColor: t.ink,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: t.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: t.accentSoft,
      height: 64,
      labelTextStyle: WidgetStatePropertyAll(
          GoogleFonts.geist(fontSize: 11.5, fontWeight: FontWeight.w500, color: t.ink)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: t.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: t.ink,
        foregroundColor: t.screen,
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: GoogleFonts.geist(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: t.ink,
        side: BorderSide(color: t.line),
        minimumSize: const Size(0, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: t.screen,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: t.line)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: t.line)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: t.accent, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: t.ink,
      contentTextStyle: GoogleFonts.geist(color: t.screen, fontSize: 14),
      actionTextColor: b == Brightness.light ? const Color(0xFFAFC0FF) : t.accent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}

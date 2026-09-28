import 'package:flutter/material.dart';

// Brand & status accents (shared across light / dark)
// Token contract (mobile/web):
// - Page bg:        kBg            = 0xFFF7F9FC
// - Card surface:   kSurface       = 0xFFFFFFFF
// - Primary blue:   kAccent        = 0xFF0052D4 (logo royal blue — buttons, active nav, selected)
// - ACCESS cyan:    kCyan          = 0xFF00C4E8 (logo bright cyan — branding, icons, highlights)
// - Inactive nav:   kIconInactive  = 0xFF64748B
// - Main text:      kTextPrimary   = 0xFF172033
const kBg          = Color(0xFFF7F9FC);
const kSurface     = Color(0xFFFFFFFF);
const kSurfaceAlt  = Color(0xFFF1F5F9);
const kSidebar     = Color(0xFF1A2B4A);
const kSidebarText = Color(0xFFCBD5E1);
const kAccent      = Color(0xFF0052D4);
const kIconInactive = Color(0xFF64748B);
const kCyan        = Color(0xFF00C4E8);
const kCyanDim     = Color(0xFFE6F4FF);
const kPurple      = Color(0xFF6B21E8);
const kPurpleDim   = Color(0xFFF3E8FF);
const kBlue        = Color(0xFF0066FF);
const kBlueDim     = Color(0xFFE8F2FF);
const kGreen       = Color(0xFF22C55E);
const kGreenDim    = Color(0xFFF0FDF4);
const kRed         = Color(0xFFEF4444);
const kRedDim      = Color(0xFFFEF2F2);
const kYellow      = Color(0xFFF59E0B);
const kYellowDim   = Color(0xFFFFFBEB);
const kOrange      = Color(0xFFF97316);
const kTextPrimary   = Color(0xFF172033);
const kTextSecondary = Color(0xFF64748B);
const kBorder      = Color(0xFFE2E8F0);

/// Semantic UI colors that follow light / dark [ThemeData].
@immutable
class AccessColors extends ThemeExtension<AccessColors> {
  final Color bg;
  final Color surface;
  final Color surfaceAlt;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;
  final Color sidebar;
  final Color sidebarText;
  final Color purpleDim;
  final Color cyanDim;

  const AccessColors({
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
    required this.sidebar,
    required this.sidebarText,
    required this.purpleDim,
    required this.cyanDim,
  });

  static const light = AccessColors(
    bg: kBg,
    surface: kSurface,
    surfaceAlt: kSurfaceAlt,
    textPrimary: kTextPrimary,
    textSecondary: kTextSecondary,
    border: kBorder,
    sidebar: kSidebar,
    sidebarText: kSidebarText,
    purpleDim: kPurpleDim,
    cyanDim: kCyanDim,
  );

  /// Mobile dark palette (web admin / system dark).
  static const dark = AccessColors(
    bg: Color(0xFF0F172A),
    surface: Color(0xFF1E293B),
    surfaceAlt: Color(0xFF334155),
    textPrimary: Color(0xFFF8FAFC),
    textSecondary: Color(0xFF94A3B8),
    border: Color(0xFF334155),
    sidebar: Color(0xFF020617),
    sidebarText: Color(0xFFCBD5E1),
    purpleDim: Color(0xFF3B0764),
    cyanDim: Color(0xFF164E63),
  );

  static AccessColors of(BuildContext context) =>
      Theme.of(context).extension<AccessColors>() ?? AccessColors.light;

  @override
  AccessColors copyWith({
    Color? bg,
    Color? surface,
    Color? surfaceAlt,
    Color? textPrimary,
    Color? textSecondary,
    Color? border,
    Color? sidebar,
    Color? sidebarText,
    Color? purpleDim,
    Color? cyanDim,
  }) {
    return AccessColors(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      border: border ?? this.border,
      sidebar: sidebar ?? this.sidebar,
      sidebarText: sidebarText ?? this.sidebarText,
      purpleDim: purpleDim ?? this.purpleDim,
      cyanDim: cyanDim ?? this.cyanDim,
    );
  }

  @override
  AccessColors lerp(ThemeExtension<AccessColors>? other, double t) {
    if (other is! AccessColors) return this;
    return AccessColors(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      border: Color.lerp(border, other.border, t)!,
      sidebar: Color.lerp(sidebar, other.sidebar, t)!,
      sidebarText: Color.lerp(sidebarText, other.sidebarText, t)!,
      purpleDim: Color.lerp(purpleDim, other.purpleDim, t)!,
      cyanDim: Color.lerp(cyanDim, other.cyanDim, t)!,
    );
  }
}

extension AccessThemeContext on BuildContext {
  AccessColors get colors => AccessColors.of(this);
}

ThemeData buildAccessLightTheme() {
  const c = AccessColors.light;
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    extensions: const [AccessColors.light],
    scaffoldBackgroundColor: c.bg,
    colorScheme: ColorScheme.light(
      primary: kAccent,
      onPrimary: Colors.white,
      surface: c.surface,
      onSurface: c.textPrimary,
      onSurfaceVariant: c.textSecondary,
      outline: c.border,
      surfaceContainerHighest: c.surfaceAlt,
    ),
    dividerColor: c.border,
    cardTheme: CardThemeData(
      color: c.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: c.border),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: c.surface,
      foregroundColor: c.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      backgroundColor: c.surface,
      indicatorColor: kAccent.withValues(alpha: 0.12),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 11,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? kAccent : kTextSecondary,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? kAccent : kTextSecondary,
          size: selected ? 24 : 22,
        );
      }),
    ),
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      minVerticalPadding: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kAccent,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: kAccent,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: kAccent,
        side: BorderSide(color: kAccent.withValues(alpha: 0.45)),
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: kAccent,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.surfaceAlt,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: c.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: c.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: kAccent),
      ),
      labelStyle: TextStyle(color: c.textSecondary),
    ),
  );
}

ThemeData buildAccessDarkTheme() {
  const c = AccessColors.dark;
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    extensions: const [AccessColors.dark],
    scaffoldBackgroundColor: c.bg,
    colorScheme: ColorScheme.dark(
      primary: kAccent,
      onPrimary: Colors.white,
      surface: c.surface,
      onSurface: c.textPrimary,
      onSurfaceVariant: c.textSecondary,
      outline: c.border,
      surfaceContainerHighest: c.surfaceAlt,
    ),
    dividerColor: c.border,
    cardTheme: CardThemeData(
      color: c.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: c.border),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kAccent,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.surfaceAlt,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: c.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: c.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: kAccent),
      ),
      labelStyle: TextStyle(color: c.textSecondary),
    ),
  );
}

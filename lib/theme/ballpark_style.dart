import 'package:flutter/material.dart';
import 'ballpark_themes.dart';

/// Shared text styles + small widgets for the ballpark art direction:
/// vintage Americana — bold serif-ish display, cream on deep green,
/// chunky beveled cards. No neon, no generic Material look.
class Ballpark {
  static TextStyle display(double size, {required BallparkTheme theme}) =>
      TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w900,
        color: theme.text,
        letterSpacing: 1.2,
        shadows: const [
          Shadow(color: Colors.black54, offset: Offset(0, 3), blurRadius: 6),
        ],
      );

  static TextStyle heading(double size, {required BallparkTheme theme}) =>
      TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w800,
        color: theme.text,
        letterSpacing: 0.6,
      );

  static TextStyle body(double size,
          {required BallparkTheme theme, Color? color}) =>
      TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w600,
        color: color ?? theme.text,
        height: 1.45,
      );

  static TextStyle label(double size, {required BallparkTheme theme}) =>
      TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: theme.accent,
        letterSpacing: 2.0,
      );

  static BorderRadius get radius => BorderRadius.circular(16);

  static BoxDecoration card(BallparkTheme theme) => BoxDecoration(
        color: theme.surface,
        borderRadius: radius,
        border: Border.all(color: theme.accent.withValues(alpha: 0.45)),
        boxShadow: const [
          BoxShadow(
              color: Colors.black45, offset: Offset(0, 4), blurRadius: 10),
        ],
      );

  static ThemeData appTheme(BallparkTheme theme) {
    final scheme = ColorScheme.dark(
      primary: theme.accent,
      secondary: theme.accent,
      surface: theme.surface,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFF101408),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: theme.text,
        elevation: 0,
        centerTitle: true,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: theme.surface,
        contentTextStyle: body(15, theme: theme),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
    );
  }
}

/// Wooden-sign backdrop: deep warm backdrop with subtle vignette.
class FieldBackdrop extends StatelessWidget {
  final BallparkTheme theme;
  final Widget child;
  const FieldBackdrop({super.key, required this.theme, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            theme.night ? const Color(0xFF0B0E14) : const Color(0xFF1A2418),
            const Color(0xFF0D1008),
          ],
        ),
      ),
      child: child,
    );
  }
}

/// Big wooden-sign button.
class SluggerButton extends StatelessWidget {
  final String label;
  final String emoji;
  final bool primary;
  final bool locked;
  final VoidCallback? onTap;
  final BallparkTheme theme;

  const SluggerButton({
    super.key,
    required this.label,
    required this.emoji,
    required this.theme,
    this.primary = false,
    this.locked = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = primary ? theme.accent : theme.surface;
    final fg = primary ? const Color(0xFF241A08) : theme.text;
    return Opacity(
      opacity: locked ? 0.55 : 1.0,
      child: Material(
        color: bg,
        borderRadius: Ballpark.radius,
        elevation: primary ? 6 : 2,
        child: InkWell(
          borderRadius: Ballpark.radius,
          onTap: locked ? null : onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: Ballpark.radius,
              border: Border.all(
                color: primary
                    ? theme.accentDark
                    : theme.accent.withValues(alpha: 0.5),
                width: 2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Text(
                  locked ? '$label  🔒' : label,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: fg,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

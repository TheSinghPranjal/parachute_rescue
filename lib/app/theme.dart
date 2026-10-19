import 'package:flutter/material.dart';

/// Shared colours and type for the doodle look.
abstract final class AppColors {
  static const ink = Color(0xFF22252B);
  static const paper = Color(0xFFFFF8E7);
  static const sky = Color(0xFFBFE6FA);
  static const yellow = Color(0xFFFFD23F);
  static const red = Color(0xFFE8504F);
  static const green = Color(0xFF5DBB63);
  static const blue = Color(0xFF3FA7D6);
  static const purple = Color(0xFF8E7CC3);
  static const orange = Color(0xFFFF9F43);
}

abstract final class AppFonts {
  static const display = 'Lilita';
  static const hand = 'PatrickHand';
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.blue,
      surface: AppColors.paper,
    ),
    scaffoldBackgroundColor: AppColors.sky,
    fontFamily: AppFonts.hand,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.ink,
      displayColor: AppColors.ink,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) =>
            s.contains(WidgetState.selected) ? Colors.white : AppColors.paper,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) =>
            s.contains(WidgetState.selected) ? AppColors.green : Colors.black26,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(AppColors.ink),
    ),
  );
}

/// A display-font text with an ink outline, like the mockup's titles.
class OutlinedLabel extends StatelessWidget {
  const OutlinedLabel(
    this.text, {
    super.key,
    this.size = 28,
    this.color = Colors.white,
    this.stroke = 5,
    this.textAlign = TextAlign.center,
  });

  final String text;
  final double size;
  final Color color;
  final double stroke;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFamily: AppFonts.display,
      fontSize: size,
      height: 1.05,
      letterSpacing: 0.5,
    );
    // Scale down rather than wrap/overflow on narrow screens.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Stack(
        children: [
          ExcludeSemantics(
            child: Text(
              text,
              textAlign: textAlign,
              style: style.copyWith(
                foreground: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = stroke
                  ..strokeJoin = StrokeJoin.round
                  ..color = AppColors.ink,
              ),
            ),
          ),
          Text(
            text,
            textAlign: textAlign,
            style: style.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

/// Chunky cartoon button with an ink outline and a drop "shadow" that
/// squashes when pressed.
class DoodleButton extends StatefulWidget {
  const DoodleButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = AppColors.yellow,
    this.icon,
    this.fontSize = 26,
    this.height = 64,
    this.expand = false,
    this.textColor = AppColors.ink,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final IconData? icon;
  final double fontSize;
  final double height;
  final bool expand;
  final Color textColor;

  @override
  State<DoodleButton> createState() => _DoodleButtonState();
}

class _DoodleButtonState extends State<DoodleButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final depth = _down ? 1.0 : 5.0;
    final content = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.icon != null) ...[
          Icon(
            widget.icon,
            color: widget.textColor,
            size: widget.fontSize * 1.15,
          ),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            widget.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppFonts.display,
              fontSize: widget.fontSize,
              color: widget.textColor,
              letterSpacing: 0.6,
            ),
          ),
        ),
      ],
    );
    return Semantics(
      button: true,
      label: widget.label,
      enabled: enabled,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapCancel: enabled ? () => setState(() => _down = false) : null,
        onTapUp: enabled ? (_) => setState(() => _down = false) : null,
        onTap: widget.onPressed,
        child: Opacity(
          opacity: enabled ? 1 : 0.5,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 70),
            height: widget.height,
            margin: EdgeInsets.only(top: 5 - depth),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: widget.color,
              borderRadius: BorderRadius.circular(widget.height * 0.32),
              border: Border.all(color: AppColors.ink, width: 3),
              boxShadow: [
                BoxShadow(color: AppColors.ink, offset: Offset(0, depth)),
              ],
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}

/// Small square icon button in the HUD style.
class DoodleIconButton extends StatelessWidget {
  const DoodleIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.color = AppColors.paper,
    this.size = 52,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: GestureDetector(
          onTap: onPressed,
          child: Container(
            width: size,
            height: size,
            decoration: doodleBox(color: color),
            child: Icon(icon, color: AppColors.ink, size: size * 0.58),
          ),
        ),
      ),
    );
  }
}

/// Rounded cream card with an ink border, used across the HUD and menus.
BoxDecoration doodleBox({Color color = AppColors.paper, double radius = 14}) =>
    BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: AppColors.ink, width: 3),
      boxShadow: const [BoxShadow(color: AppColors.ink, offset: Offset(0, 3))],
    );

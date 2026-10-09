import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// One round control: an icon in a circle with its name underneath.
class FocusControl {
  final IconData icon;
  final String label;

  /// Null when the control is refused rather than merely unavailable — deep
  /// focus cannot pause, and the button says so instead of being live and
  /// refused by the engine underneath.
  final VoidCallback? onPressed;

  /// The one control this screen is for. Design 04 draws it larger and in the
  /// solid brand green; the rest are a pale tint of it.
  final bool primary;

  const FocusControl({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.primary = false,
  });
}

/// The round controls design 04 draws under the timer.
///
/// ## Why this replaced full-width buttons
///
/// The screen used to draw a full-width 记一下 button above two full-width
/// buttons, so every control was the same size and the same shape and nothing
/// said which one the screen was for. The board draws a row of circles with the
/// names underneath and makes 暂停 the largest and the only filled one — the
/// hierarchy is carried by size and weight rather than by position.
///
/// ## What is deliberately absent
///
/// The board draws four: 白噪音 / 暂停 / 记一下 / 完成. There are three here.
/// 白噪音 has no audio behind it anywhere in the repo, and a round button that
/// plays nothing is exactly the control the brief forbids — the same reason the
/// capture sheet has no sound sources. The row is three controls and a recorded
/// gap rather than four and a lie.
class FocusControlRow extends StatelessWidget {
  final List<FocusControl> controls;

  const FocusControlRow({super.key, required this.controls});

  /// The circle's diameter, and how much larger the primary one is.
  static const double secondaryDiameter = 52;
  static const double primaryDiameter = 64;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final control in controls) _Control(control: control),
      ],
    );
  }
}

class _Control extends StatelessWidget {
  final FocusControl control;

  const _Control({required this.control});

  @override
  Widget build(BuildContext context) {
    final diameter = control.primary
        ? FocusControlRow.primaryDiameter
        : FocusControlRow.secondaryDiameter;
    final enabled = control.onPressed != null;

    // The primary is the filled one; the others are a pale tint of the same
    // green. A disabled control keeps its shape and loses its colour, so a
    // refused control reads as refused rather than as missing.
    final fill = !enabled
        ? AppColors.surfaceMuted
        : control.primary
            ? AppColors.primarySage
            : AppColors.primaryLight;
    final ink = !enabled
        ? AppColors.textTertiary
        : control.primary
            ? AppColors.textLight
            : AppColors.primaryDark;

    return Semantics(
      excludeSemantics: true,
      button: true,
      enabled: enabled,
      label: control.label,
      child: GestureDetector(
        onTap: control.onPressed,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: diameter,
              height: diameter,
              decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Icon(control.icon,
                  size: control.primary ? 30 : 24, color: ink),
            ),
            const SizedBox(height: 8),
            Text(
              control.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: control.primary ? FontWeight.w700 : FontWeight.w500,
                color: enabled ? AppColors.textPrimary : AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

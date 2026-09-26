import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';

/// The Mochi / 房间 / 装扮 / 图鉴 segmented navigation.
///
/// The approved V4.1 references show this control on all four pages of the
/// companion section (10 成长, 10A 装扮, 10B 图鉴, 09 房间), because those pages
/// are four views of one thing. Before this widget existed only the collection
/// page rendered it, so the same section had two different navigations
/// depending on which page you were on.
///
/// It is a plain router control: it owns no state and reads no business data.
class GrowthSubNav extends StatelessWidget {
  /// Which entry is the page currently being shown.
  final GrowthSection active;

  const GrowthSubNav({super.key, required this.active});

  @override
  Widget build(BuildContext context) {
    // Deliberately transparent: the section's pages sit on different
    // backgrounds (09 uses `backgroundWarm`, the rest use `background`), so
    // painting a colour here would draw a visible band on one of them.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          for (final section in GrowthSection.values)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: section == GrowthSection.values.last ? 0 : 8,
                ),
                child: _Pill(
                  section: section,
                  active: section == active,
                  onTap: () => context.go(section.route),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The four views of the companion section, in reference order.
enum GrowthSection {
  mochi('Mochi', '/growth'),
  room('房间', '/room'),
  dress('装扮', '/growth/dress'),
  collection('图鉴', '/growth/collection');

  const GrowthSection(this.label, this.route);

  final String label;
  final String route;
}

class _Pill extends StatelessWidget {
  final GrowthSection section;
  final bool active;
  final VoidCallback onTap;

  const _Pill({
    required this.section,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: active,
      button: true,
      label: section.label,
      child: Material(
        color: active ? AppColors.primarySage : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: InkWell(
          onTap: active ? null : onTap,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: Container(
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(
                color: active ? AppColors.primarySage : AppColors.border,
              ),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                section.label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: active ? FontWeight.bold : FontWeight.w500,
                  color: active ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

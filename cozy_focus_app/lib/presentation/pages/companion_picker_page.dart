import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../companion/companion_avatar.dart';
import '../companion/companion_selection.dart';
import '../companion/runtime/companion_id.dart';
import '../companion/runtime/companion_profile.dart';
import '../theme/app_theme.dart';

/// Screen 08: Companion Picker (08 伙伴选择).
///
/// ## What it can and cannot do
///
/// It changes which companion is *presented*. It cannot change XP, coins,
/// happiness, a session, a craft job or inventory, because the selection is a
/// presentation preference and the shared `PetProgress` is the same for every
/// companion. That is the whole point of the shared-growth rule: choosing a
/// different companion must not look like starting over, and must not create a
/// second economy.
///
/// The list is built from the catalog, so a companion added to the manifest
/// appears here with no change to this file.
class CompanionPickerPage extends ConsumerWidget {
  const CompanionPickerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(companionCatalogProvider);
    final selected = ref.watch(companionSelectionProvider);
    final ids = catalog.companionIds;

    return Scaffold(
      backgroundColor: AppColors.backgroundWarm,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundWarm,
        elevation: 0,
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            const _Header(),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                itemCount: ids.length,
                separatorBuilder: (_, __) => const SizedBox(height: 14),
                itemBuilder: (context, index) {
                  final id = ids[index];
                  return _CompanionCard(
                    profile: catalog.profileFor(id),
                    companionId: id,
                    selected: id == selected,
                    onTap: () => ref
                        .read(companionSelectionProvider.notifier)
                        .select(id),
                  );
                },
              ),
            ),
            _ConfirmBar(
              onConfirm: () => context.pop(),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '选择你的伙伴 🌱',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '找到最合拍的伙伴，\n一起开启专注又温暖的时光吧！',
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompanionCard extends StatelessWidget {
  final CompanionProfile profile;
  final CompanionId companionId;
  final bool selected;
  final VoidCallback onTap;

  const _CompanionCard({
    required this.profile,
    required this.companionId,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${profile.displayName}${selected ? '，已选择' : ''}',
      child: Material(
        color: selected ? AppColors.primaryLight : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: selected ? AppColors.primarySage : AppColors.border,
                width: selected ? 1.6 : 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 84,
                  height: 84,
                  child: Center(
                    child: CompanionAvatar(
                      companionId: companionId,
                      size: 78,
                      showStateBadge: false,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              profile.displayName,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          _SelectionMark(selected: selected),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        profile.tagline,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.45,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final trait in profile.traits)
                            _TraitChip(label: trait),
                        ],
                      ),
                    ],
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

class _SelectionMark extends StatelessWidget {
  final bool selected;

  const _SelectionMark({required this.selected});

  @override
  Widget build(BuildContext context) {
    if (selected) {
      return const Icon(
        Icons.check_circle,
        size: 22,
        color: AppColors.primarySage,
      );
    }
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.textTertiary, width: 1.4),
      ),
    );
  }
}

class _TraitChip extends StatelessWidget {
  final String label;

  const _TraitChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _ConfirmBar extends StatelessWidget {
  final VoidCallback onConfirm;

  const _ConfirmBar({required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: FilledButton(
          onPressed: onConfirm,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primarySage,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          child: const Text(
            '确定伙伴',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

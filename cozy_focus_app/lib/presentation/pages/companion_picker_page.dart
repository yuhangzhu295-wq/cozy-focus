import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../companion/companion_avatar.dart';
import '../companion/companion_selection.dart';
import '../companion/pack/companion_availability_provider.dart';
import '../companion/pack/companion_pack_completeness.dart';
import '../companion/pack/companion_pack_exporter.dart';
import '../companion/pack/companion_pack_picker.dart';
import '../companion/pack/companion_pack_removal.dart';
import '../companion/pack/companion_pack_root.dart';
import '../companion/pack/installed_packs_provider.dart';
import '../companion/runtime/companion_id.dart';
import '../companion/runtime/companion_manifest_data.dart';
import '../companion/runtime/companion_profile.dart';
import '../theme/app_theme.dart';
import '../widgets/companion_completeness.dart';

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
/// appears here with no change to this file. That now includes a companion the
/// user installed while the app was running: the catalog watches the installed
/// set, so the list grows without a restart.
///
/// ## Why the export and delete actions live here
///
/// Because this is the only screen that lists companions, and a pack the user
/// cannot find is a pack they cannot take out or remove. Export and delete act on
/// the *installed* ones only: the built-in three are part of the app, and
/// offering to delete them would promise something the app does not do.
class CompanionPickerPage extends ConsumerWidget {
  const CompanionPickerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(companionCatalogProvider);
    final selected = ref.watch(companionSelectionProvider);
    final ids = catalog.companionIds;

    // Watched, not read: installing or removing a pack must re-render this list
    // and the per-card actions. The revision itself is not used - the set is.
    ref.watch(installedPacksProvider);
    final installedIds = ref.read(installedPacksProvider.notifier).installedIds;
    final completenessOf = ref.watch(companionCompletenessProvider);

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
            _ImportBar(
              onImport: () => context.push('/companions/import'),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                itemCount: ids.length,
                separatorBuilder: (_, __) => const SizedBox(height: 14),
                itemBuilder: (context, index) {
                  final id = ids[index];
                  final installed = installedIds.contains(id.value);
                  return _CompanionCard(
                    profile: catalog.profileFor(id),
                    companionId: id,
                    selected: id == selected,
                    installed: installed,
                    completeness: installed ? completenessOf(id.value) : null,
                    onTap: () => ref
                        .read(companionSelectionProvider.notifier)
                        .select(id),
                    onExport: installed
                        ? () => _export(context, ref, id.value)
                        : null,
                    onDelete: installed
                        ? () => _delete(context, ref, id.value,
                            catalog.profileFor(id).displayName)
                        : null,
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

  /// Writes the installed pack out as a `.cozy_pet` and hands it to the share
  /// sheet, so the user chooses where it goes.
  Future<void> _export(
      BuildContext context, WidgetRef ref, String packId) async {
    final root = ref.read(companionPackRootProvider);
    if (root == null) {
      _tell(context, '现在还不能导出，请稍后再试。');
      return;
    }

    final result = CompanionPackExporter.export(
      packDirectory: '$root/$packId',
      packId: packId,
    );
    if (!result.ok) {
      // The exporter refuses rather than throws, so a pack whose files have gone
      // missing is reported instead of crashing the list.
      _tell(context, '导出失败：${result.refusal}');
      return;
    }

    try {
      await ref.read(companionPackSinkProvider).deliver(
            fileName: companionPackExportFileName(packId),
            bytes: result.bytes!,
          );
    } catch (error) {
      if (context.mounted) _tell(context, '导出失败：$error');
    }
  }

  /// Removes an installed pack, after asking.
  ///
  /// The confirmation is not decoration: removal cannot be undone, and the pack
  /// may be the only copy the user has. The order the removal itself uses — repair
  /// the selection, then forget the metadata, then delete the files — is
  /// `CompanionPackRemoval`'s, not this page's.
  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    String packId,
    String displayName,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('删除 $displayName？'),
        content: const Text('删除之后这个伙伴就从列表里消失了。如果你还没导出过，它就找不回来了。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('先留着'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('删除',
                style: TextStyle(color: AppColors.accentPeach)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final root = ref.read(companionPackRootProvider);
    if (root == null) {
      if (context.mounted) _tell(context, '现在还不能删除，请稍后再试。');
      return;
    }

    final report = await CompanionPackRemoval.remove(
      packId: packId,
      packs: ref.read(installedPacksProvider.notifier),
      selection: ref.read(companionSelectionProvider.notifier),
      installRoot: Directory(root),
      builtInIds:
          CompanionManifestData.profiles.keys.map((id) => id.value).toSet(),
      defaultId: CompanionManifestData.defaultProfileId.value,
    );

    if (!context.mounted) return;
    if (!report.removed) {
      _tell(context, '没有找到这个伙伴，可能已经被删掉了。');
      return;
    }
    _tell(
      context,
      report.selectionAfter == null
          ? '$displayName 已经删掉了。'
          : '$displayName 已经删掉了，现在换成别的伙伴陪你。',
    );
  }

  void _tell(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 14),
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

/// The way in to the import flow.
///
/// Above the list rather than in an overflow menu, because a feature a user
/// cannot find is a feature that does not exist, and this one is the only way a
/// custom companion can arrive.
class _ImportBar extends StatelessWidget {
  final VoidCallback onImport;

  const _ImportBar({required this.onImport});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Semantics(
        button: true,
        label: '导入宠物包',
        child: Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: InkWell(
            onTap: onImport,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.border),
              ),
              child: const Row(
                children: [
                  Icon(Icons.add_circle_outline_rounded,
                      size: 20, color: AppColors.primarySage),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '导入宠物包',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    '用 .cozy_pet 文件带一个新伙伴进来',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CompanionCard extends StatelessWidget {
  final CompanionProfile profile;
  final CompanionId companionId;
  final bool selected;
  final bool installed;
  final CompanionPackCompleteness? completeness;
  final VoidCallback onTap;
  final VoidCallback? onExport;
  final VoidCallback? onDelete;

  const _CompanionCard({
    required this.profile,
    required this.companionId,
    required this.selected,
    required this.installed,
    required this.onTap,
    this.completeness,
    this.onExport,
    this.onDelete,
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
                          if (onExport != null || onDelete != null)
                            _PackMenu(
                              displayName: profile.displayName,
                              onExport: onExport,
                              onDelete: onDelete,
                            ),
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
                          if (installed) const _TraitChip(label: '导入的'),
                          // What this companion can actually do, against the
                          // app's own action vocabulary. On the card rather than
                          // only at import, because this list is where a user
                          // decides which companion to live with.
                          if (completeness != null)
                            CompanionCompletenessBadge(
                                completeness: completeness!),
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

/// Export and delete, for an installed companion.
///
/// A menu rather than two buttons, because both actions are rare and one of them
/// is destructive; a delete button sitting permanently next to a companion the
/// user is fond of is an invitation to a mis-tap.
class _PackMenu extends StatelessWidget {
  final String displayName;
  final VoidCallback? onExport;
  final VoidCallback? onDelete;

  const _PackMenu({
    required this.displayName,
    this.onExport,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: '$displayName 的更多操作',
      icon: const Icon(Icons.more_horiz_rounded,
          size: 20, color: AppColors.textTertiary),
      onSelected: (value) {
        if (value == 'export') onExport?.call();
        if (value == 'delete') onDelete?.call();
      },
      itemBuilder: (context) => [
        if (onExport != null)
          const PopupMenuItem(
            value: 'export',
            child: Text('导出为 .cozy_pet'),
          ),
        if (onDelete != null)
          const PopupMenuItem(
            value: 'delete',
            child: Text('删除这个伙伴'),
          ),
      ],
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

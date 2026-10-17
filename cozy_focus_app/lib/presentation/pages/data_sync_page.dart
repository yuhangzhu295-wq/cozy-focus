import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/backup/backup_file_service.dart';
import '../../data/backup/backup_format.dart';
import '../../data/backup/backup_service.dart';
import '../companion/companion_avatar.dart';
import '../companion/pack/companion_pack_root.dart';
import '../companion/pack/installed_pack_profiles.dart';
import '../companion/pack/installed_packs_provider.dart';
import '../companion/companion_selection.dart';
import '../companion/room/room_simulation.dart';
import '../controllers/analytics_controller.dart';
import '../controllers/app_preferences_controller.dart';
import '../controllers/craft_controller.dart';
import '../controllers/distraction_controller.dart';
import '../controllers/growth_controller.dart';
import '../controllers/home_controller.dart';
import '../controllers/providers.dart';
import '../controllers/records_controller.dart';
import '../controllers/rest_controller.dart';
import '../controllers/timeline_controller.dart';
import '../controllers/today_plan_controller.dart';
import '../theme/app_theme.dart';

class DataSyncPage extends ConsumerStatefulWidget {
  const DataSyncPage({super.key});

  @override
  ConsumerState<DataSyncPage> createState() => _DataSyncPageState();
}

class _DataSyncPageState extends ConsumerState<DataSyncPage> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          '数据与同步',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back,
              semanticLabel: '返回', color: AppColors.textPrimary),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/settings');
            }
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            const _DataSyncHero(),
            const SizedBox(height: 20),
            const _SectionLabel('本地备份'),
            const SizedBox(height: 8),
            _BackupActionCard(
              title: '导出备份',
              subtitle: '把任务、专注记录、成长与房间数据写成一个文件，由你选择保存位置',
              icon: Icons.save_alt_outlined,
              iconColor: AppColors.primarySage,
              iconBgColor: AppColors.primaryLight,
              busy: _busy,
              onTap: _busy ? null : _export,
            ),
            _BackupActionCard(
              title: '从备份恢复',
              subtitle: '选择一个备份文件，确认后完整替换当前数据',
              icon: Icons.settings_backup_restore_outlined,
              iconColor: AppColors.catWork,
              iconBgColor: AppColors.accentPeachLight,
              busy: _busy,
              onTap: _busy ? null : _restore,
            ),
            if (_busy)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(minHeight: 2),
              ),
            const SizedBox(height: 12),
            const _BackupNote(),
            const SizedBox(height: 20),
            const _SectionLabel('数据状态'),
            const SizedBox(height: 8),
            const _DataStatusCard(
              title: '本地数据已保存',
              subtitle: '你的专注数据已安全保存在本机',
              icon: Icons.check_circle_outline,
              iconColor: AppColors.primarySage,
              iconBgColor: AppColors.primaryLight,
            ),
            const _DataStatusCard(
              title: '当前处于离线状态',
              subtitle: '当前版本为本地离线模式，网络状态不影响本地使用',
              icon: Icons.cloud_off_outlined,
              iconColor: AppColors.catWork,
              iconBgColor: AppColors.accentPeachLight,
            ),
            const _DataStatusCard(
              title: '云端同步',
              subtitle: '当前版本暂不支持云端同步',
              icon: Icons.cloud_outlined,
              iconColor: AppColors.catStudy,
              iconBgColor: Color(0xFFEBF1F9),
            ),
            const _PrivacyNote(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Directory? get _packRoot {
    final path = ref.read(companionPackRootProvider);
    return path == null ? null : Directory(path);
  }

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final bytes = await BackupService.export(
        db: ref.read(appDatabaseProvider),
        packRoot: _packRoot,
      );
      final name =
          'cozyfocus-${DateFormat('yyyyMMdd-HHmm').format(DateTime.now())}'
          '.${BackupFormat.extension}';
      final location = await BackupFileService.save(bytes, suggestedName: name);
      if (!mounted) return;
      if (location == null) {
        _toast('已取消，没有写入文件。');
        return;
      }
      await _showResult(
        title: '备份已保存',
        body: '共 ${(bytes.length / 1024).ceil()} KB。\n\n$location',
      );
    } on BackupException catch (error) {
      if (mounted) await _showResult(title: '导出失败', body: error.message);
    } on BackupFileException catch (error) {
      if (mounted) await _showResult(title: '导出失败', body: error.message);
    } catch (error) {
      if (mounted) await _showResult(title: '导出失败', body: '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    setState(() => _busy = true);
    try {
      final bytes = await BackupFileService.pick();
      if (!mounted) return;
      if (bytes == null) {
        _toast('已取消，没有选择文件。');
        return;
      }

      final db = ref.read(appDatabaseProvider);
      final read = BackupReader.read(bytes, currentSchema: db.schemaVersion);
      if (!read.ok) {
        await _showResult(title: '无法恢复', body: read.refusal!);
        return;
      }

      // Checked before the confirmation so the user is not asked to approve
      // something that is going to be refused a moment later.
      if (await BackupService.hasLiveSession(db)) {
        if (!mounted) return;
        await _showResult(
          title: '无法恢复',
          body: '正在专注中。请先结束或暂停并保存当前专注，再恢复备份。',
        );
        return;
      }
      if (!mounted) return;

      final confirmed = await _confirm(read.preview!);
      if (confirmed != true) {
        _toast('已取消，数据没有改动。');
        return;
      }

      final report = await BackupService.restore(
        db: db,
        payload: read.payload!,
        packRoot: _packRoot,
      );
      if (!mounted) return;
      _refreshAfterRestore();
      await _showResult(
        title: '恢复完成',
        body: '已写入 ${report.rowsRestored} 条记录'
            '${report.packsRestored > 0 ? '，${report.packsRestored} 个伙伴包文件' : ''}。\n\n'
            '页面上的数据已重新读取。',
      );
    } on BackupException catch (error) {
      if (mounted) await _showResult(title: '恢复失败', body: error.message);
    } on BackupFileException catch (error) {
      if (mounted) await _showResult(title: '恢复失败', body: error.message);
    } catch (error) {
      if (mounted) await _showResult(title: '恢复失败', body: '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Drops every controller that read the old rows.
  ///
  /// Invalidating is the honest mechanism: the controllers own their state, and
  /// there is no partial-update path that could leave one page showing the old
  /// totals while another shows the new ones. Each one reloads from the database
  /// on the next read.
  void _refreshAfterRestore() {
    ref.invalidate(homeControllerProvider);
    ref.invalidate(craftControllerProvider);
    ref.invalidate(growthControllerProvider);
    ref.invalidate(recordsControllerProvider);
    ref.invalidate(analyticsSummaryProvider);
    ref.invalidate(dayTimelineProvider);
    ref.invalidate(todayPlanControllerProvider);
    ref.invalidate(distractionInboxControllerProvider);
    ref.invalidate(restControllerProvider);
    ref.invalidate(taskListControllerProvider);
    ref.invalidate(appPreferencesProvider);
    ref.invalidate(installedPacksProvider);
    ref.invalidate(installedPackProfilesProvider);
    ref.invalidate(companionSelectionProvider);
    ref.invalidate(roomSimulationProvider);
  }

  Future<bool?> _confirm(BackupPreview preview) {
    final exported = preview.exportedAt?.toLocal();
    final counts = preview.rowCounts;
    final rows = <String>[
      '任务 ${counts['tasks'] ?? 0} 条',
      '专注记录 ${counts['focus_records'] ?? 0} 条',
      '专注会话 ${counts['focus_sessions'] ?? 0} 条',
      '制作与库存 ${(counts['craft_jobs'] ?? 0) + (counts['inventory_items'] ?? 0)} 条',
      '房间摆放 ${counts['room_items'] ?? 0} 条',
    ].join(' · ');

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('替换当前数据？'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              exported == null
                  ? '备份时间未知'
                  : '备份时间：${DateFormat('yyyy-MM-dd HH:mm').format(exported)}',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 8),
            Text(
              '共 ${preview.totalRows} 条记录'
              '${preview.packIds.isEmpty ? '' : '、${preview.packIds.length} 个自定义伙伴包'}。',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(rows, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 12),
            const Text(
              '当前数据会被完整替换，且无法撤销。',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accentPeach,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('替换并恢复'),
          ),
        ],
      ),
    );
  }

  Future<void> _showResult({required String title, required String body}) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SelectableText(body, style: const TextStyle(fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
    );
  }
}

class _BackupActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final bool busy;
  final VoidCallback? onTap;

  const _BackupActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // No explicit label: the card's own title and subtitle are its name. A
    // `label:` here merged with them and the device read "导出备份 导出备份" -
    // the same double-announcement class fixed elsewhere in the app.
    return Semantics(
      button: true,
      enabled: onTap != null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.md),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                        color: iconBgColor, shape: BoxShape.circle),
                    child: Icon(icon, color: iconColor, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: onTap == null
                        ? AppColors.textTertiary.withValues(alpha: 0.4)
                        : AppColors.textTertiary,
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

class _BackupNote extends StatelessWidget {
  const _BackupNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 16, color: AppColors.textTertiary),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              '备份只保存在你选择的位置，不会上传到任何服务器。'
              '恢复是完整替换，不合并两份记录；恢复过程中出错时，原数据保持不变。',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DataSyncHero extends StatelessWidget {
  const _DataSyncHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Row(
        children: [
          CompanionAvatar(
            size: 72,
            showStateBadge: false,
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '没关系～',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  '你的专注数据已安全保存在本机。',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DataStatusCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;

  const _DataStatusCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration:
                BoxDecoration(color: iconBgColor, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 16, color: AppColors.textTertiary),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              '当前版本以本地存储方式运行，不会执行云端同步。',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

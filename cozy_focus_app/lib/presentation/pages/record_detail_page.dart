import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../domain/models/focus_record.dart';
import '../controllers/providers.dart';
import '../controllers/records_controller.dart';
import '../theme/app_theme.dart';

/// Screen 05C: Record Detail Page (05C 记录详情)
/// Shows:
/// - Task name, duration, date & time range
/// - Category, Mood, Note
/// - Real reward settlement summary (focusCoinsEarned & experienceEarned from RewardLedger)
/// - Secondary confirmation delete dialog (calls IFocusRecordRepository.deleteById)
/// - Edit dialog for task name, category, mood, note (calls IFocusRecordRepository.update)
class RecordDetailPage extends ConsumerStatefulWidget {
  final String recordId;

  const RecordDetailPage({
    super.key,
    required this.recordId,
  });

  @override
  ConsumerState<RecordDetailPage> createState() => _RecordDetailPageState();
}

class _RecordDetailPageState extends ConsumerState<RecordDetailPage> {
  bool _isLoading = true;
  FocusRecord? _record;
  int _rewardCoins = 0;
  int _rewardXp = 0;

  @override
  void initState() {
    super.initState();
    _loadRecord();
  }

  Future<void> _loadRecord() async {
    setState(() => _isLoading = true);
    final recordRepo = ref.read(focusRecordRepositoryProvider);
    final ledgerRepo = ref.read(rewardLedgerRepositoryProvider);

    final record = await recordRepo.findById(widget.recordId);
    int coins = 0;
    int xp = 0;

    if (record != null) {
      final ledger = await ledgerRepo.findBySessionId(record.sessionId);
      if (ledger != null) {
        coins = ledger.focusCoinsEarned;
        xp = ledger.experienceEarned;
      }
    }

    if (mounted) {
      setState(() {
        _record = record;
        _rewardCoins = coins;
        _rewardXp = xp;
        _isLoading = false;
      });
    }
  }

  Future<void> _showEditDialog() async {
    if (_record == null) return;
    final r = _record!;

    final taskController = TextEditingController(text: r.taskName ?? '');
    final noteController = TextEditingController(text: r.note ?? '');
    String selectedCategory = r.categoryId ?? 'default';
    String selectedMood = r.mood ?? '😊';

    final categories = [
      {'id': 'study', 'name': '学习', 'icon': Icons.school_rounded},
      {'id': 'work', 'name': '工作', 'icon': Icons.work_outline_rounded},
      {'id': 'reading', 'name': '阅读', 'icon': Icons.menu_book_rounded},
      {'id': 'life', 'name': '生活', 'icon': Icons.spa_rounded},
      {'id': 'other', 'name': '其他', 'icon': Icons.more_horiz_rounded},
    ];

    final moods = ['😊', '😄', '🌿', '😌', '💪', '😴'];

    final updated = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              title: const Text(
                '编辑记录',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('任务名称',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: taskController,
                      decoration: InputDecoration(
                        hintText: '输入任务名称...',
                        filled: true,
                        fillColor: AppColors.backgroundWarm,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text('分类',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: categories.map((cat) {
                        final isSel = selectedCategory == cat['id'];
                        return ChoiceChip(
                          label: Text(cat['name'] as String),
                          selected: isSel,
                          selectedColor: AppColors.primaryLight,
                          backgroundColor: AppColors.backgroundWarm,
                          labelStyle: TextStyle(
                            color: isSel
                                ? AppColors.primarySage
                                : AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight:
                                isSel ? FontWeight.bold : FontWeight.normal,
                          ),
                          onSelected: (val) {
                            if (val) {
                              setDialogState(() {
                                selectedCategory = cat['id'] as String;
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                    const Text('专注心情',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary)),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: moods.map((m) {
                        final isSel = selectedMood == m;
                        return GestureDetector(
                          onTap: () => setDialogState(() => selectedMood = m),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isSel
                                  ? AppColors.accentPeachLight
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              border: Border.all(
                                color: isSel
                                    ? AppColors.accentPeach
                                    : Colors.transparent,
                              ),
                            ),
                            child:
                                Text(m, style: const TextStyle(fontSize: 22)),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                    const Text('专注心得 / 备注',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: noteController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: '记录此刻的收获...',
                        filled: true,
                        fillColor: AppColors.backgroundWarm,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('取消',
                      style: TextStyle(color: AppColors.textTertiary)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primarySage,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('保存修改'),
                ),
              ],
            );
          },
        );
      },
    );

    if (updated == true && mounted) {
      final newRecord = r.copyWith(
        taskName: taskController.text.trim().isEmpty
            ? null
            : taskController.text.trim(),
        categoryId: selectedCategory,
        mood: selectedMood,
        note: noteController.text.trim().isEmpty
            ? null
            : noteController.text.trim(),
      );

      await ref
          .read(recordsControllerProvider.notifier)
          .updateRecord(newRecord);
      if (mounted) {
        setState(() => _record = newRecord);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('记录已更新 ♡'),
            backgroundColor: AppColors.primarySage,
          ),
        );
      }
    }
  }

  Future<void> _showDeleteConfirmDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          title: const Text('确认删除记录？',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              )),
          content: const Text(
            '删除此记录后，相关的统计数据与图表将被重新计算。此操作不可恢复。',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('取消',
                  style: TextStyle(color: AppColors.textTertiary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('确认删除'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      await ref
          .read(recordsControllerProvider.notifier)
          .deleteRecord(widget.recordId);
      if (mounted) {
        context.pop();
      }
    }
  }

  String _formatDateTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}年${dt.month}月${dt.day}日';
  }

  String _categoryLabel(String? id) {
    switch (id) {
      case 'work':
        return '工作';
      case 'study':
        return '学习';
      case 'reading':
        return '阅读';
      case 'life':
        return '生活';
      default:
        return '其他';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primarySage),
        ),
      );
    }

    if (_record == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded,
                color: AppColors.textPrimary),
            onPressed: () => context.pop(),
          ),
          title: const Text('记录详情',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 17)),
        ),
        body: const Center(
          child: Text('未找到该专注记录',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
      );
    }

    final r = _record!;
    final minutes = (r.durationSeconds / 60).floor();
    final timeStr =
        '${_formatDateTime(r.startAt)} - ${_formatDateTime(r.endAt)}';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          '记录详情',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Main Hero Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            r.taskName ?? '无特定任务',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Text(
                            _categoryLabel(r.categoryId),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primarySage,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatDate(r.startAt),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const Divider(height: 24, color: AppColors.borderLight),
                    Row(
                      children: [
                        const Icon(Icons.access_time_rounded,
                            size: 20, color: AppColors.primarySage),
                        const SizedBox(width: 8),
                        Text(
                          timeStr,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '$minutes 分钟',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primarySage,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Mood & Notes Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('专注心情：',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            )),
                        Text(
                          r.mood != null && r.mood!.isNotEmpty ? r.mood! : '😊',
                          style: const TextStyle(fontSize: 24),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Text('专注心得 / 备注：',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        )),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundWarm,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Text(
                        r.note != null && r.note!.isNotEmpty
                            ? r.note!
                            : '未留下备注。每一分专注都有它的价值 ♡',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Rewards Settled Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.card_giftcard_rounded,
                            size: 18, color: AppColors.accentPeach),
                        SizedBox(width: 8),
                        Text(
                          '结算奖励',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.backgroundWarm,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            child: Row(
                              children: [
                                const Text('🪙',
                                    style: TextStyle(fontSize: 20)),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('专注币',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textSecondary)),
                                    Text('+$_rewardCoins',
                                        style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textPrimary)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.backgroundWarm,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            child: Row(
                              children: [
                                const Text('🐾',
                                    style: TextStyle(fontSize: 20)),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Mochi 亲密度',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textSecondary)),
                                    Text('+$_rewardXp XP',
                                        style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textPrimary)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundWarm,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.handyman_outlined,
                              size: 14, color: AppColors.textTertiary),
                          SizedBox(width: 6),
                          Text(
                            '家具制作：Phase 4 尚未解锁，敬请期待',
                            style: TextStyle(
                                fontSize: 11, color: AppColors.textTertiary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Actions (Edit & Delete)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primarySage,
                        side: const BorderSide(color: AppColors.primarySage),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('编辑记录',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: _showEditDialog,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text('删除记录',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: _showDeleteConfirmDialog,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

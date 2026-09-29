import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../companion/companion_selection.dart';
import '../../domain/models/focus_record.dart';
import '../companion/companion_avatar.dart';
import '../controllers/providers.dart';
import '../controllers/records_controller.dart';
import '../theme/app_theme.dart';

/// Screen 05C: Record Detail Page (05C 记录详情)
/// Shows:
/// - Large Mochi hero avatar with peaceful state
/// - Task name, duration, date & time range
/// - Category, Mood, Note (clean structured cards matching V4.1 hierarchy)
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
    // Fix: never coerce null categoryId to 'default' silently — let user choose
    String? selectedCategory = r.categoryId;
    String? selectedMood = r.mood; // null = user never selected

    final categories = [
      {'id': 'study', 'name': '学习', 'icon': Icons.school_rounded},
      {'id': 'work', 'name': '工作', 'icon': Icons.work_outline_rounded},
      {'id': 'reading', 'name': '阅读', 'icon': Icons.menu_book_rounded},
      {'id': 'life', 'name': '生活', 'icon': Icons.spa_rounded},
      {'id': 'other', 'name': '其他', 'icon': Icons.more_horiz_rounded},
    ];

    final moods = [
      {'emoji': '😊', 'label': '开心'},
      {'emoji': '😄', 'label': '愉快'},
      {'emoji': '🌿', 'label': '平静'},
      {'emoji': '😌', 'label': '放松'},
      {'emoji': '💪', 'label': '专注'},
      {'emoji': '😴', 'label': '疲惫'},
    ];

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
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: moods.map((m) {
                        final emoji = m['emoji'] as String;
                        final label = m['label'] as String;
                        final isSel =
                            selectedMood != null && selectedMood == emoji;
                        return GestureDetector(
                          onTap: () =>
                              setDialogState(() => selectedMood = emoji),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSel
                                  ? AppColors.accentPeachLight
                                  : AppColors.backgroundWarm,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              border: Border.all(
                                color: isSel
                                    ? AppColors.accentPeach
                                    : Colors.transparent,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(emoji,
                                    style: const TextStyle(fontSize: 18)),
                                const SizedBox(width: 4),
                                Text(label,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: isSel
                                            ? AppColors.primarySage
                                            : AppColors.textSecondary,
                                        fontWeight: isSel
                                            ? FontWeight.bold
                                            : FontWeight.normal)),
                              ],
                            ),
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
                    const SizedBox(height: 4),
                    const Text(
                      '实际时长不可修改；只允许编辑任务、分类、心情和备注',
                      style: TextStyle(
                          fontSize: 11, color: AppColors.textTertiary),
                    ),
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
        // Fix: only write categoryId when the user explicitly selected one
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

  Color _categoryColor(String? id) {
    switch (id) {
      case 'work':
        return AppColors.catWork;
      case 'study':
        return AppColors.catStudy;
      case 'reading':
        return AppColors.catReading;
      case 'life':
        return AppColors.catLife;
      default:
        return AppColors.catOther;
    }
  }

  /// Returns the label text for a mood emoji, e.g. '😊' → '开心'.
  String _moodLabel(String emoji) {
    const map = {
      '😊': '开心',
      '😄': '愉快',
      '🌿': '平静',
      '😌': '放松',
      '💪': '专注',
      '😴': '疲惫',
    };
    return map[emoji] ?? emoji;
  }

  @override
  Widget build(BuildContext context) {
    final companionName = ref.watch(companionDisplayNameProvider);
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
    // Fix: show '<1 分钟' for sessions under one minute
    final displayMinutes = r.durationSeconds < 60 ? '<1' : '$minutes';
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
            fontSize: 17,
          ),
        ),
        // Fix: AppBar right-side 「编辑」entry per V4.1 05C spec
        actions: [
          TextButton(
            onPressed: _showEditDialog,
            child: const Text(
              '编辑',
              style: TextStyle(
                color: AppColors.primarySage,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Mochi Companion Hero
              const Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 4, bottom: 12),
                  child: CompanionAvatar(
                    size: 140,
                    message: '专注的每一分都算数 ♡',
                  ),
                ),
              ),

              // Main Session Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            r.taskName ?? '无特定任务',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: _categoryColor(r.categoryId)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Text(
                            _categoryLabel(r.categoryId),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _categoryColor(r.categoryId),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded,
                            size: 14, color: AppColors.textTertiary),
                        const SizedBox(width: 6),
                        Text(
                          _formatDate(r.startAt),
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24, color: AppColors.borderLight),
                    Row(
                      children: [
                        const Icon(Icons.access_time_rounded,
                            size: 18, color: AppColors.primarySage),
                        const SizedBox(width: 6),
                        Text(
                          timeStr,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '$displayMinutes 分钟',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primarySage,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

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
                    const Text('专注心情',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        )),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundWarm,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            r.mood != null && r.mood!.isNotEmpty
                                ? r.mood!
                                : '🌱',
                            style: const TextStyle(fontSize: 20),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            r.mood != null && r.mood!.isNotEmpty
                                ? _moodLabel(r.mood!)
                                : '未选择心情',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('专注心得 / 备注',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        )),
                    const SizedBox(height: 8),
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
              const SizedBox(height: 14),

              // Rewards Settled Card — title changed to 「本次成长」
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
                          '本次成长',
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
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text('专注币',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: AppColors.textSecondary)),
                                      Text('+$_rewardCoins',
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.textPrimary)),
                                    ],
                                  ),
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
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('$companionName 亲密度',
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: AppColors.textSecondary)),
                                      Text('+$_rewardXp XP',
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.textPrimary)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Bottom action: single full-width delete button (edit moved to AppBar)
              SizedBox(
                width: double.infinity,
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
        ),
      ),
    );
  }
}

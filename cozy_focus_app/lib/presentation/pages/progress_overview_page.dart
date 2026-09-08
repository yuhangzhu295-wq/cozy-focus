import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../domain/models/focus_record.dart';
import '../controllers/records_controller.dart';
import '../theme/app_theme.dart';

/// Screen 05: Progress Overview Page (05 Progress 总览)
/// Unifies:
/// - Screen 05A: 今日记录 (Today timeline & summary)
/// - Screen 05B: 历史记录 (Searchable & category filtered history)
/// - Screen 05D: 日历视图 (Month calendar heatmap & selected day records)
/// - Quick entries to Screen 06 (周报), Screen 07 (月报), Screen 08 (年报)
class ProgressOverviewPage extends ConsumerStatefulWidget {
  final int initialTabIndex;

  const ProgressOverviewPage({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  ConsumerState<ProgressOverviewPage> createState() =>
      _ProgressOverviewPageState();
}

class _ProgressOverviewPageState extends ConsumerState<ProgressOverviewPage> {
  late int _selectedTab;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTabIndex;
    Future.microtask(() {
      ref.read(recordsControllerProvider.notifier).loadData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _categoryLabel(String? id) {
    switch (id) {
      case 'study':
        return '学习';
      case 'work':
        return '工作';
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
      case 'study':
        return AppColors.catStudy;
      case 'work':
        return AppColors.catWork;
      case 'reading':
        return AppColors.catReading;
      case 'life':
        return AppColors.catLife;
      default:
        return AppColors.catOther;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recordsControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: AppColors.textPrimary),
          onPressed: () => context.go('/'),
        ),
        title: const Text(
          '今日记录',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            tooltip: '周报 / 月报 / 年报',
            icon: const Icon(Icons.insights_rounded,
                color: AppColors.primarySage),
            onPressed: () => context.push('/reports/weekly'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Subtitle
            Container(
              width: double.infinity,
              color: AppColors.surface,
              padding: const EdgeInsets.only(bottom: 12),
              alignment: Alignment.center,
              child: const Text(
                '专注，让生活更温柔。',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ),

            // Segmented Tab Selector (今日 / 历史 / 日历)
            Container(
              color: AppColors.surface,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.backgroundWarm,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Row(
                  children: [
                    _buildTabButton(0, '今日'),
                    _buildTabButton(1, '历史'),
                    _buildTabButton(2, '日历'),
                  ],
                ),
              ),
            ),

            // Body content
            Expanded(
              child: state.isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primarySage),
                    )
                  : RefreshIndicator(
                      color: AppColors.primarySage,
                      onRefresh: () => ref
                          .read(recordsControllerProvider.notifier)
                          .loadData(),
                      child: _buildTabContent(state),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(int index, String title) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color:
                  isSelected ? AppColors.primarySage : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent(RecordsState state) {
    switch (_selectedTab) {
      case 0:
        return _buildTodayTab(state);
      case 1:
        return _buildHistoryTab(state);
      case 2:
        return _buildCalendarTab(state);
      default:
        return _buildTodayTab(state);
    }
  }

  // ==========================================
  // Screen 05A: 今日记录
  // ==========================================
  Widget _buildTodayTab(RecordsState state) {
    final todaySum = state.todaySummary;
    final todaySec = todaySum?.totalSeconds ?? 0;
    final todayCount = todaySum?.sessionCount ?? 0;
    final todayHours = todaySec ~/ 3600;
    final todayMins = (todaySec % 3600) ~/ 60;

    final diffMins = state.todayVsYesterdayMinutes;
    String diffText;
    if (diffMins > 0) {
      diffText = '比昨天多了 $diffMins 分钟 🚀';
    } else if (diffMins < 0) {
      diffText = '比昨天少了 ${diffMins.abs()} 分钟';
    } else {
      diffText = '与昨天持平';
    }

    final todayRecords = state.allRecords.where((r) {
      final now = DateTime.now();
      return r.startAt.year == now.year &&
          r.startAt.month == now.month &&
          r.startAt.day == now.day;
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Mochi Encouragement Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.backgroundWarm,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '干得好！',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '今天也很专注呢！\nMochi 为你开心！ ♡',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                ),
                child: const Text('🐶', style: TextStyle(fontSize: 34)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Summary Badges (Duration & Count)
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.timer_outlined,
                            size: 18, color: AppColors.primarySage),
                        SizedBox(width: 6),
                        Text('今日专注时长',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      todayHours > 0
                          ? '$todayHours时 $todayMins分'
                          : '$todayMins 分钟',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      diffText,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.accentPeach,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.bar_chart_rounded,
                            size: 18, color: AppColors.accentPeach),
                        SizedBox(width: 6),
                        Text('专注次数',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$todayCount 次',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '保持节奏，继续加油！',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Timeline section header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '今日专注记录',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              '共 ${todayRecords.length} 次',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (todayRecords.isEmpty)
          _buildEmptyCard('今日还没有专注记录哦', '和 Mochi 一起开启美好的一天吧！')
        else
          ...todayRecords.map((r) => _buildRecordRow(r)),

        const SizedBox(height: 24),

        // Month Heatmap Entry Banner (05A bottom card)
        InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: () => setState(() => _selectedTab = 2),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: AppColors.primaryLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.calendar_month_rounded,
                      color: AppColors.primarySage, size: 22),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '本月专注日历与热力图',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '查看每一天的专注热度与历史轨迹 >',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded,
                    size: 14, color: AppColors.textTertiary),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // Screen 05B: 历史记录
  // ==========================================
  Widget _buildHistoryTab(RecordsState state) {
    final categories = [
      {'id': null, 'name': '全部'},
      {'id': 'study', 'name': '学习'},
      {'id': 'work', 'name': '工作'},
      {'id': 'reading', 'name': '阅读'},
      {'id': 'life', 'name': '生活'},
      {'id': 'other', 'name': '其他'},
    ];

    final records = state.filteredHistoryRecords;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Search bar
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: '搜索任务名、备注或分类...',
            prefixIcon:
                const Icon(Icons.search_rounded, color: AppColors.textTertiary),
            filled: true,
            fillColor: AppColors.surface,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              borderSide: const BorderSide(color: AppColors.border),
            ),
          ),
          onChanged: (val) {
            ref.read(recordsControllerProvider.notifier).setSearchQuery(val);
          },
        ),
        const SizedBox(height: 12),

        // Category Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: categories.map((cat) {
              final catId = cat['id'];
              final isSel = state.selectedCategoryFilter == catId;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(cat['name']!),
                  selected: isSel,
                  selectedColor: AppColors.primaryLight,
                  backgroundColor: AppColors.surface,
                  labelStyle: TextStyle(
                    color:
                        isSel ? AppColors.primarySage : AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                  ),
                  onSelected: (val) {
                    ref
                        .read(recordsControllerProvider.notifier)
                        .setCategoryFilter(val ? catId : null);
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),

        // Records List
        if (records.isEmpty)
          _buildEmptyCard('未找到符合条件的记录', '尝试更换筛选分类或搜索词')
        else
          ...records.map((r) => _buildRecordRow(r)),
      ],
    );
  }

  // ==========================================
  // Screen 05D: 日历视图
  // ==========================================
  Widget _buildCalendarTab(RecordsState state) {
    final month = state.currentMonth;
    final selDate = state.selectedCalendarDate;
    final selSummary = state.selectedDaySummary;
    final heatmap = state.monthlyHeatmap;

    final selDateRecords = state.allRecords.where((r) {
      return r.startAt.year == selDate.year &&
          r.startAt.month == selDate.month &&
          r.startAt.day == selDate.day;
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Month navigation header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded,
                        color: AppColors.primarySage),
                    onPressed: () => ref
                        .read(recordsControllerProvider.notifier)
                        .changeCalendarMonth(-1),
                  ),
                  Text(
                    '${month.year}年 ${month.month}月',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded,
                        color: AppColors.primarySage),
                    onPressed: () => ref
                        .read(recordsControllerProvider.notifier)
                        .changeCalendarMonth(1),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Weekday labels
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Text('一',
                      style: TextStyle(
                          color: AppColors.textTertiary, fontSize: 12)),
                  Text('二',
                      style: TextStyle(
                          color: AppColors.textTertiary, fontSize: 12)),
                  Text('三',
                      style: TextStyle(
                          color: AppColors.textTertiary, fontSize: 12)),
                  Text('四',
                      style: TextStyle(
                          color: AppColors.textTertiary, fontSize: 12)),
                  Text('五',
                      style: TextStyle(
                          color: AppColors.textTertiary, fontSize: 12)),
                  Text('六',
                      style: TextStyle(
                          color: AppColors.textTertiary, fontSize: 12)),
                  Text('日',
                      style: TextStyle(
                          color: AppColors.textTertiary, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 8),

              // Days grid
              _buildMonthGrid(month, selDate, heatmap),
              const SizedBox(height: 8),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Selected date summary
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${selDate.month}月${selDate.day}日 专注概况',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '${(selSummary?.totalSeconds ?? 0) ~/ 60} 分钟 · ${selSummary?.sessionCount ?? 0} 次',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primarySage,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        if (selDateRecords.isEmpty)
          _buildEmptyCard('该日无专注记录', '选择有热度颜色的日期查看历史记录')
        else
          ...selDateRecords.map((r) => _buildRecordRow(r)),
      ],
    );
  }

  Widget _buildMonthGrid(
      DateTime month, DateTime selectedDate, Map<DateTime, int> heatmap) {
    final firstDayOfMonth = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // weekday: Mon=1, Sun=7
    final startOffset = firstDayOfMonth.weekday - 1;
    final totalCells = ((startOffset + daysInMonth + 6) ~/ 7) * 7;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
      ),
      itemCount: totalCells,
      itemBuilder: (context, index) {
        final dayNum = index - startOffset + 1;
        if (dayNum < 1 || dayNum > daysInMonth) {
          return const SizedBox.shrink();
        }

        final date = DateTime(month.year, month.month, dayNum);
        final isSelected = date.year == selectedDate.year &&
            date.month == selectedDate.month &&
            date.day == selectedDate.day;

        // Find duration from heatmap
        final sec = heatmap[DateTime(date.year, date.month, date.day)] ?? 0;
        Color heatColor = Colors.transparent;
        if (sec > 0) {
          if (sec < 1800) {
            heatColor = const Color(0xFFD4E5D9); // light green
          } else if (sec < 5400) {
            heatColor = const Color(0xFFA3CDB0); // medium green
          } else {
            heatColor = AppColors.primarySage; // deep green
          }
        }

        return GestureDetector(
          onTap: () {
            ref
                .read(recordsControllerProvider.notifier)
                .selectCalendarDate(date);
          },
          child: Container(
            decoration: BoxDecoration(
              color: heatColor,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color:
                    isSelected ? AppColors.primarySage : AppColors.borderLight,
                width: isSelected ? 2 : 1,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              '$dayNum',
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: (sec >= 5400)
                    ? Colors.white
                    : (isSelected
                        ? AppColors.primarySage
                        : AppColors.textPrimary),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecordRow(FocusRecord r) {
    final minutes = (r.durationSeconds / 60).floor();
    final timeStr =
        '${DateFormat('HH:mm').format(r.startAt)} - ${DateFormat('HH:mm').format(r.endAt)}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: _categoryColor(r.categoryId),
            shape: BoxShape.circle,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                r.taskName ?? '无特定任务',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Text(
              '$minutes 分钟',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.primarySage,
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _categoryColor(r.categoryId).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    _categoryLabel(r.categoryId),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _categoryColor(r.categoryId),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  timeStr,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (r.mood != null && r.mood!.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(r.mood!, style: const TextStyle(fontSize: 13)),
                ],
              ],
            ),
            if (r.note != null && r.note!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                r.note!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded,
            size: 14, color: AppColors.textTertiary),
        onTap: () {
          context.push('/records/${r.id}');
        },
      ),
    );
  }

  Widget _buildEmptyCard(String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        children: [
          const Icon(Icons.wb_sunny_outlined,
              size: 40, color: AppColors.accentGold),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

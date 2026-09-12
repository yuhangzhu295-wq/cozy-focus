import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/focus_record.dart';
import '../controllers/records_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/pet_avatar_widget.dart';

/// Screen 05: Records Hub (V4.1)
class ProgressOverviewPage extends ConsumerStatefulWidget {
  final int initialTabIndex;
  const ProgressOverviewPage({super.key, this.initialTabIndex = 0});
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
    Future.microtask(
        () => ref.read(recordsControllerProvider.notifier).loadData());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  int _computeStreak(List<FocusRecord> records) {
    if (records.isEmpty) return 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = <DateTime>{};
    for (final r in records) {
      days.add(DateTime(r.startAt.year, r.startAt.month, r.startAt.day));
    }
    int streak = 0;
    var check = today;
    while (days.contains(check)) {
      streak++;
      check = check.subtract(const Duration(days: 1));
    }
    if (streak == 0) {
      check = today.subtract(const Duration(days: 1));
      while (days.contains(check)) {
        streak++;
        check = check.subtract(const Duration(days: 1));
      }
    }
    return streak;
  }

  String _catLabel(String? id) {
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

  Color _catColor(String? id) {
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

  IconData _catIcon(String? id) {
    switch (id) {
      case 'study':
        return Icons.school_rounded;
      case 'work':
        return Icons.work_outline_rounded;
      case 'reading':
        return Icons.menu_book_rounded;
      case 'life':
        return Icons.spa_rounded;
      default:
        return Icons.more_horiz_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recordsControllerProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHero(),
          _buildTabBar(),
          Expanded(
            child: state.isLoading
                ? const Center(
                    child:
                        CircularProgressIndicator(color: AppColors.primarySage))
                : RefreshIndicator(
                    color: AppColors.primarySage,
                    onRefresh: () =>
                        ref.read(recordsControllerProvider.notifier).loadData(),
                    child: _buildTabContent(state),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildHero() {
    return Container(
      color: AppColors.backgroundWarm,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(children: [
                      Text('记录',
                          style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryDark,
                              height: 1.1)),
                      SizedBox(width: 6),
                      Icon(Icons.eco_rounded,
                          color: AppColors.primarySage, size: 24),
                    ]),
                    SizedBox(height: 4),
                    Text('每一次专注，都是更靠近理想生活的一步。',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                    SizedBox(height: 8),
                  ],
                ),
              ),
              Container(
                width: 100,
                height: 100,
                decoration: const BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.eco_rounded,
                    size: 48, color: AppColors.primarySage),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
            color: AppColors.backgroundWarm,
            borderRadius: BorderRadius.circular(AppRadius.pill)),
        child: Row(children: [
          _tab(0, Icons.eco_outlined, '今日'),
          _tab(1, Icons.history_rounded, '历史'),
          _tab(2, Icons.calendar_month_rounded, '日历'),
          _tab(3, Icons.bar_chart_rounded, '报告'),
        ]),
      ),
    );
  }

  Widget _tab(int index, IconData icon, String label) {
    final sel = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: sel ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            boxShadow: sel
                ? [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 4,
                        offset: const Offset(0, 1))
                  ]
                : null,
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon,
                size: 16,
                color: sel ? AppColors.primarySage : AppColors.textSecondary),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: sel ? FontWeight.bold : FontWeight.w500,
                    color:
                        sel ? AppColors.primarySage : AppColors.textSecondary)),
          ]),
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
      case 3:
        return _buildReportsTab();
      default:
        return _buildTodayTab(state);
    }
  }

  // ===== Screen 05A: Today =====
  Widget _buildTodayTab(RecordsState state) {
    final sec = state.todaySummary?.totalSeconds ?? 0;
    final count = state.todaySummary?.sessionCount ?? 0;
    final mins = sec ~/ 60;
    final streak = _computeStreak(state.allRecords);
    final now = DateTime.now();
    final todayRecs = state.allRecords
        .where((r) =>
            r.startAt.year == now.year &&
            r.startAt.month == now.month &&
            r.startAt.day == now.day)
        .toList();
    final diff = state.todayVsYesterdayMinutes;
    final msg = sec == 0
        ? '和 Mochi 一起开启今天的专注吧！'
        : diff > 0
            ? '今天也很棒呀，和 Mochi 一起继续加油！ ♥'
            : '慢慢来，和 Mochi 一起加油！ ♥';

    return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          _buildStatsCard(mins, count, streak, sec),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(AppRadius.md)),
            child: Row(children: [
              const Icon(Icons.eco_rounded,
                  color: AppColors.primarySage, size: 15),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(msg,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.primaryDark))),
            ]),
          ),
          const SizedBox(height: 20),
          Row(children: [
            const Icon(Icons.schedule_rounded,
                color: AppColors.primarySage, size: 17),
            const SizedBox(width: 6),
            const Text('今日记录',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
            const Spacer(),
            Text('共 ${todayRecs.length} 次',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
          ]),
          const SizedBox(height: 12),
          if (todayRecs.isEmpty) ...[
            _buildEmptyState(),
          ] else ...[
            ...todayRecs.map(_buildRecordRow),
            const SizedBox(height: 16),
            _buildCalendarBanner(),
          ],
        ]);
  }

  Widget _buildStatsCard(int mins, int count, int streak, int sec) {
    final progress = (sec / (120 * 60)).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border)),
      child: Column(children: [
        Row(children: [
          const Icon(Icons.bar_chart_rounded,
              color: AppColors.primarySage, size: 17),
          const SizedBox(width: 6),
          const Text('今天的专注',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          const Spacer(),
          GestureDetector(
              onTap: () => setState(() => _selectedTab = 1),
              child: const Text('查看详情 >',
                  style:
                      TextStyle(fontSize: 12, color: AppColors.primarySage))),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          SizedBox(
            width: 72,
            height: 72,
            child: CustomPaint(
              painter: _RingPainter(progress: progress),
              child: const Center(
                  child: Icon(Icons.eco_rounded,
                      color: AppColors.primarySage, size: 28)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text('$mins',
                          style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary)),
                      const SizedBox(width: 4),
                      const Text('分钟',
                          style: TextStyle(
                              fontSize: 13, color: AppColors.textSecondary)),
                    ]),
                const Text('今日专注时长',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textSecondary)),
                const Text('继续加油！',
                    style:
                        TextStyle(fontSize: 11, color: AppColors.primarySage)),
              ])),
          const SizedBox(width: 8),
          Column(children: [
            _miniStat(Icons.ads_click_rounded, '\$count', '次', '专注次数'),
            const SizedBox(height: 12),
            _miniStat(
                Icons.local_fire_department_rounded, '\$streak', '天', '连续专注',
                iconColor: const Color(0xFFE55B2A)),
          ]),
        ]),
      ]),
    );
  }

  Widget _miniStat(IconData icon, String val, String unit, String lbl,
      {Color iconColor = AppColors.primarySage}) {
    return Column(children: [
      Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Icon(icon, color: iconColor, size: 14),
            const SizedBox(width: 3),
            Text(val,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
            Text(unit,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary)),
          ]),
      Text(lbl,
          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
    ]);
  }

  // ===== Screen 05B: History =====
  Widget _buildHistoryTab(RecordsState state) {
    final cats = [
      <String, dynamic>{'id': null, 'name': '全部'},
      {'id': 'study', 'name': '学习'},
      {'id': 'work', 'name': '工作'},
      {'id': 'reading', 'name': '阅读'},
      {'id': 'life', 'name': '生活'},
      {'id': 'other', 'name': '其他'},
    ];
    final recs = state.filteredHistoryRecords;
    return ListView(padding: const EdgeInsets.all(16), children: [
      GestureDetector(
        onTap: () {
          showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('搜索记录'),
              content: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(hintText: '搜索任务名、备注或分类...'),
                onChanged: (v) => ref
                    .read(recordsControllerProvider.notifier)
                    .setSearchQuery(v),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('完成'))
              ],
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(children: [
            const Icon(Icons.search_rounded,
                color: AppColors.textTertiary, size: 20),
            const SizedBox(width: 8),
            Expanded(
                child: Text(
              _searchController.text.isEmpty
                  ? '搜索任务名、备注或分类...'
                  : _searchController.text,
              style: TextStyle(
                  fontSize: 14,
                  color: _searchController.text.isEmpty
                      ? AppColors.textTertiary
                      : AppColors.textPrimary),
            )),
          ]),
        ),
      ),
      const SizedBox(height: 12),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
            children: cats.map((cat) {
          final id = cat['id'] as String?;
          final sel = state.selectedCategoryFilter == id;
          return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(cat['name'] as String),
                selected: sel,
                selectedColor: AppColors.primaryLight,
                backgroundColor: AppColors.surface,
                labelStyle: TextStyle(
                    color:
                        sel ? AppColors.primarySage : AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: sel ? FontWeight.bold : FontWeight.normal),
                onSelected: (v) => ref
                    .read(recordsControllerProvider.notifier)
                    .setCategoryFilter(v ? id : null),
              ));
        }).toList()),
      ),
      const SizedBox(height: 16),
      if (recs.isEmpty)
        _buildEmptyCard('未找到符合条件的记录', '尝试更换筛选分类或搜索词')
      else
        ...recs.map(_buildRecordRow),
    ]);
  }

  // ===== Screen 05D: Calendar =====
  Widget _buildCalendarTab(RecordsState state) {
    final month = state.currentMonth;
    final sel = state.selectedCalendarDate;
    final selSum = state.selectedDaySummary;
    final heat = state.monthlyHeatmap;
    final selRecs = state.allRecords
        .where((r) =>
            r.startAt.year == sel.year &&
            r.startAt.month == sel.month &&
            r.startAt.day == sel.day)
        .toList();

    return ListView(padding: const EdgeInsets.all(16), children: [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border)),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            IconButton(
                icon: const Icon(Icons.chevron_left_rounded,
                    color: AppColors.textSecondary),
                onPressed: () => ref
                    .read(recordsControllerProvider.notifier)
                    .changeCalendarMonth(-1)),
            Text(DateFormat('yyyy年 M月').format(month),
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
            IconButton(
                icon: const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textSecondary),
                onPressed: () => ref
                    .read(recordsControllerProvider.notifier)
                    .changeCalendarMonth(1)),
          ]),
          const SizedBox(height: 8),
          Row(
              children: ['日', '一', '二', '三', '四', '五', '六']
                  .map((d) => Expanded(
                      child: Center(
                          child: Text(d,
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textTertiary)))))
                  .toList()),
          const SizedBox(height: 8),
          _calGrid(month, sel, heat),
        ]),
      ),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.event_rounded,
                color: AppColors.primarySage, size: 16),
            const SizedBox(width: 6),
            Text(DateFormat('M月d日').format(sel),
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
            const Spacer(),
            Text(
                '共 ${selSum?.totalMinutes ?? 0} 分钟  ${selSum?.sessionCount ?? 0} 次',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
          ]),
          const SizedBox(height: 12),
          if (selRecs.isEmpty)
            const Text('这天还没有专注记录',
                style: TextStyle(fontSize: 13, color: AppColors.textTertiary))
          else
            ...selRecs.map(_buildRecordRow),
        ]),
      ),
    ]);
  }

  Widget _calGrid(DateTime month, DateTime selDate, Map<DateTime, int> heat) {
    final first = DateTime(month.year, month.month, 1);
    final days = DateTime(month.year, month.month + 1, 0).day;
    final offset = first.weekday % 7;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7, mainAxisSpacing: 6, crossAxisSpacing: 6),
      itemCount: offset + days,
      itemBuilder: (ctx, i) {
        final d = i - offset + 1;
        if (d < 1 || d > days) return const SizedBox.shrink();
        final date = DateTime(month.year, month.month, d);
        final isSel = date.year == selDate.year &&
            date.month == selDate.month &&
            date.day == selDate.day;
        final sec = heat[DateTime(date.year, date.month, date.day)] ?? 0;
        Color bg = Colors.transparent;
        if (sec > 0) {
          bg = sec < 1800
              ? const Color(0xFFD4E5D9)
              : sec < 5400
                  ? const Color(0xFFA3CDB0)
                  : AppColors.primarySage;
        }
        return GestureDetector(
          onTap: () => ref
              .read(recordsControllerProvider.notifier)
              .selectCalendarDate(date),
          child: Container(
            decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(
                    color:
                        isSel ? AppColors.primarySage : AppColors.borderLight,
                    width: isSel ? 2 : 1)),
            alignment: Alignment.center,
            child: Text('\$d',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                    color: sec >= 5400
                        ? Colors.white
                        : isSel
                            ? AppColors.primarySage
                            : AppColors.textPrimary)),
          ),
        );
      },
    );
  }

  // ===== Reports tab =====
  Widget _buildReportsTab() {
    return ListView(padding: const EdgeInsets.all(16), children: [
      _reportEntry(Icons.calendar_view_week_rounded, '周报', '过去 7 天的专注概览',
          () => context.push('/reports/weekly')),
      const SizedBox(height: 12),
      _reportEntry(Icons.calendar_month_rounded, '月报', '本月专注分布与趋势',
          () => context.push('/reports/monthly')),
      const SizedBox(height: 12),
      _reportEntry(Icons.auto_graph_rounded, '年报', '全年专注总览与成就',
          () => context.push('/reports/yearly')),
    ]);
  }

  Widget _reportEntry(
      IconData icon, String title, String sub, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border)),
        child: Row(children: [
          Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                  color: AppColors.primaryLight, shape: BoxShape.circle),
              child: Icon(icon, color: AppColors.primarySage, size: 22)),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary)),
                Text(sub,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ])),
          const Icon(Icons.arrow_forward_ios_rounded,
              size: 14, color: AppColors.textTertiary),
        ]),
      ),
    );
  }

  // ===== Record Row =====
  Widget _buildRecordRow(FocusRecord r) {
    final mins = (r.durationSeconds / 60).floor();
    final time =
        '${DateFormat('HH:mm').format(r.startAt)} - ${DateFormat('HH:mm').format(r.endAt)}';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: _catColor(r.categoryId).withValues(alpha: 0.15),
                shape: BoxShape.circle),
            child: Icon(_catIcon(r.categoryId),
                color: _catColor(r.categoryId), size: 20)),
        title: Row(children: [
          Expanded(
              child: Text(r.taskName ?? '无特定任务',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis)),
          Text('$mins 分钟',
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primarySage)),
        ]),
        subtitle: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Row(children: [
              Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: _catColor(r.categoryId).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.pill)),
                  child: Text(_catLabel(r.categoryId),
                      style: TextStyle(
                          fontSize: 11,
                          color: _catColor(r.categoryId),
                          fontWeight: FontWeight.w500))),
              const SizedBox(width: 6),
              Text(time,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textTertiary)),
              if (r.mood != null) ...[
                const SizedBox(width: 4),
                Text(r.mood!, style: const TextStyle(fontSize: 12))
              ],
            ])),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded,
              color: AppColors.textTertiary, size: 18),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md)),
          itemBuilder: (ctx) => [
            const PopupMenuItem(
                value: 'detail',
                child: Row(children: [
                  Icon(Icons.open_in_new_rounded,
                      size: 16, color: AppColors.textSecondary),
                  SizedBox(width: 8),
                  Text('查看详情')
                ])),
          ],
          onSelected: (v) {
            if (v == 'detail') context.push('/records/${r.id}');
          },
        ),
        onTap: () => context.push('/records/${r.id}'),
      ),
    );
  }

  // ===== Empty state (Screen 14) =====
  Widget _buildEmptyState() {
    return Column(children: [
      const SizedBox(height: 20),
      const PetAvatarWidget(visualState: PetVisualState.idle, size: 120),
      const SizedBox(height: 16),
      const Text('今天还没有专注记录',
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary)),
      const SizedBox(height: 8),
      const Text('从一次专注开始，',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          textAlign: TextAlign.center),
      const Text('遇见更专注、更平静的自己。',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          textAlign: TextAlign.center),
      const SizedBox(height: 24),
      SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primarySage,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill))),
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('开始第一次专注',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            onPressed: () => context.go('/focus'),
          )),
      const SizedBox(height: 16),
      _buildCalendarBanner(),
    ]);
  }

  Widget _buildEmptyCard(String title, String sub) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border)),
      child: Column(children: [
        const Icon(Icons.search_off_rounded,
            color: AppColors.textTertiary, size: 40),
        const SizedBox(height: 12),
        Text(title,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        Text(sub,
            style:
                const TextStyle(fontSize: 13, color: AppColors.textTertiary)),
      ]),
    );
  }

  Widget _buildCalendarBanner() {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      onTap: () => setState(() => _selectedTab = 2),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border)),
        child: Row(children: [
          Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                  color: AppColors.primaryLight, shape: BoxShape.circle),
              child: const Icon(Icons.calendar_month_rounded,
                  color: AppColors.primarySage, size: 20)),
          const SizedBox(width: 12),
          const Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('本月专注日历与热力图',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary)),
                Text('查看每一天的专注热度与历史轨迹 >',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textSecondary)),
              ])),
          const Icon(Icons.arrow_forward_ios_rounded,
              size: 12, color: AppColors.textTertiary),
        ]),
      ),
    );
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: 1,
      selectedItemColor: AppColors.primarySage,
      unselectedItemColor: AppColors.textTertiary,
      backgroundColor: AppColors.surface,
      onTap: (i) {
        if (i == 0) {
          context.go('/');
        } else if (i == 2) {
          context.go('/growth');
        }
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: '首页'),
        BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_rounded), label: '记录'),
        BottomNavigationBarItem(icon: Icon(Icons.eco_outlined), label: '成长'),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  const _RingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 5;
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..color = AppColors.primaryLight
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round);
    if (progress > 0) {
      canvas.drawArc(
          Rect.fromCircle(center: c, radius: r),
          -math.pi / 2,
          2 * math.pi * progress,
          false,
          Paint()
            ..color = AppColors.primarySage
            ..style = PaintingStyle.stroke
            ..strokeWidth = 7
            ..strokeCap = StrokeCap.round);
    }
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.progress != progress;
}

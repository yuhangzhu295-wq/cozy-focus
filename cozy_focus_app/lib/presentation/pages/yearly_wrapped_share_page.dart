import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../controllers/reports_controller.dart';
import '../services/wrapped_export_service.dart';
import '../theme/app_theme.dart';

/// Screen 08A: Yearly Wrapped / Share Page
///
/// Real features:
/// - Card preview with actual stats from StatisticsEngine (no hardcoded fake numbers).
/// - RepaintBoundary-based PNG export via WrappedExportService.
/// - Real gallery save with success/failure/permission feedback.
/// - Real share sheet with PNG file (card excludes private notes).
class YearlyWrappedSharePage extends ConsumerStatefulWidget {
  const YearlyWrappedSharePage({super.key});

  @override
  ConsumerState<YearlyWrappedSharePage> createState() =>
      _YearlyWrappedSharePageState();
}

class _YearlyWrappedSharePageState
    extends ConsumerState<YearlyWrappedSharePage> {
  final _cardKey = GlobalKey();
  final _exportService = const WrappedExportService();
  bool _isSaving = false;
  bool _isSharing = false;

  Future<Uint8List?> _captureCard() async {
    // Let the widget finish painting before capture.
    await Future<void>.delayed(const Duration(milliseconds: 100));
    return _exportService.captureCardAsBytes(_cardKey);
  }

  Future<void> _saveToGallery(int year) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final bytes = await _captureCard();
      if (bytes == null) {
        _showMessage('无法生成卡片，请稍后重试');
        return;
      }
      final result = await _exportService.saveToGallery(
        bytes,
        'cozy_focus_${year}_wrapped.png',
      );
      switch (result) {
        case ExportResult.success:
          _showMessage('已保存年度专注卡片到相册 ♡');
        case ExportResult.permissionDenied:
          _showMessage('请在系统设置中允许访问相册');
        case ExportResult.failed:
          _showMessage('保存失败，请重试');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _shareCard(
    int year,
    String hours,
    int days,
    int sessions,
  ) async {
    if (_isSharing) return;
    setState(() => _isSharing = true);
    try {
      final shareText = '✨ My $year Focus Journey with Cozy Focus ✨\n'
          '这一年，我和 Mochi 一起坚持专注了 $hours 小时，'
          '累计 $sessions 次，达成 $days 个专注日！\n'
          '每一次平静专注的时光，都在成为更温暖坚定的自己。♡\n'
          '#CozyFocus #FocusWithMochi';

      final bytes = await _captureCard();
      if (bytes != null) {
        await _exportService.shareAsImage(
          bytes,
          'cozy_focus_${year}_wrapped.png',
          shareText,
        );
      } else {
        // Fallback: share text only when PNG capture is unavailable.
        await SharePlus.instance.share(
          ShareParams(
            text: shareText,
            subject: 'Cozy Focus $year 年度 Wrapped',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  void _showMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reportsControllerProvider);
    final report = state.yearlyReport;
    final petProg = state.petProgress;
    final year = state.yearlyYear;

    final totalHours =
        report != null ? (report.totalSeconds / 3600).toStringAsFixed(0) : '0';
    final activeDays = report?.activeDaysCount ?? 0;
    final sessionCount = report?.sessionCount ?? 0;
    final petLevel = petProg?.level ?? 1;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded,
              color: AppColors.textPrimary, size: 24),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          '年度 Wrapped 分享',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Column(
                  children: [
                    // Only the card is inside RepaintBoundary — AppBar and
                    // buttons are excluded from the exported PNG.
                    RepaintBoundary(
                      key: _cardKey,
                      child: WrappedShareCard(
                        year: year,
                        totalHours: totalHours,
                        activeDays: activeDays,
                        sessionCount: sessionCount,
                        petLevel: petLevel,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.shield_outlined,
                              size: 14, color: AppColors.primarySage),
                          SizedBox(width: 6),
                          Text(
                            '卡片默认不含私人备注，安心分享 ♡',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom action area.
            Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border:
                    Border(top: BorderSide(color: AppColors.border, width: 1)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primarySage,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        elevation: 0,
                      ),
                      onPressed: _isSharing
                          ? null
                          : () => _shareCard(
                              year, totalHours, activeDays, sessionCount),
                      child: _isSharing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.share_rounded, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  '分享到社交平台',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                      ),
                      onPressed: _isSaving ? null : () => _saveToGallery(year),
                      child: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppColors.textPrimary),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.download_rounded, size: 18),
                                SizedBox(width: 6),
                                Text(
                                  '保存卡片到相册',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Stateless card widget placed inside RepaintBoundary.
/// Contains only shareable stats — no private notes, no task names.
class WrappedShareCard extends StatelessWidget {
  const WrappedShareCard({
    super.key,
    required this.year,
    required this.totalHours,
    required this.activeDays,
    required this.sessionCount,
    required this.petLevel,
  });

  final int year;
  final String totalHours;
  final int activeDays;
  final int sessionCount;
  final int petLevel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.borderLight, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'My $year Focus Journey',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                totalHours,
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'hours',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primarySage,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withValues(alpha: 0.6),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.borderLight, width: 2),
            ),
            child: const Center(
              child: Text('🐶', style: TextStyle(fontSize: 72)),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.backgroundWarm,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              'Mochi · Lv.$petLevel 陪伴伙伴',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryDark,
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Key milestone stats — all derived from real data, no hardcoded numbers.
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.backgroundWarm,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('专注天数', '$activeDays 天'),
                Container(width: 1, height: 28, color: AppColors.borderLight),
                _buildStatItem('累计专注', '$sessionCount 次'),
                Container(width: 1, height: 28, color: AppColors.borderLight),
                // Pet level comes from real PetProgress; defaults to Lv.1 when
                // Phase 5 is not yet implemented — never a fake high number.
                _buildStatItem('Mochi 等级', 'Lv.$petLevel'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '"温柔地对待时间，时间也会温柔地回馈你。"',
            style: TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const Divider(color: AppColors.borderLight),
          const SizedBox(height: 8),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.pets_rounded, size: 14, color: AppColors.primarySage),
              SizedBox(width: 6),
              Text(
                'Cozy Focus · 你的温柔专注空间',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textTertiary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

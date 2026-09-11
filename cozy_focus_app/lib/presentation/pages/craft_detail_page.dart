import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../domain/models/craft_models.dart';
import '../controllers/craft_controller.dart';
import '../theme/app_theme.dart';

/// Screen 09B: Craft Detail Page (制作详情)
/// Shows recipe, real progress bar, and Focus Now shortcut.
class CraftDetailPage extends ConsumerStatefulWidget {
  final String recipeId;
  const CraftDetailPage({required this.recipeId, super.key});

  @override
  ConsumerState<CraftDetailPage> createState() => _CraftDetailPageState();
}

class _CraftDetailPageState extends ConsumerState<CraftDetailPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => ref.read(craftControllerProvider.notifier).loadAll());
  }

  @override
  Widget build(BuildContext context) {
    final craft = ref.watch(craftControllerProvider);
    final recipe =
        craft.recipes.where((r) => r.id == widget.recipeId).firstOrNull;

    if (craft.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (recipe == null) {
      return Scaffold(
        appBar: AppBar(leading: BackButton(onPressed: () => context.pop())),
        body: const Center(child: Text('配方不存在')),
      );
    }

    final isActive = craft.activeJob?.recipeId == recipe.id;
    final isCompleted = craft.inventory
        .any((i) => i.itemId == recipe.outputItemId && i.quantity > 0);
    final hasOtherActiveJob =
        craft.activeJob != null && craft.activeJob!.recipeId != recipe.id;

    double progress = 0.0;
    int progressMin = 0;
    if (isActive && craft.activeJob != null) {
      final req = recipe.requiredSeconds;
      progress = req > 0
          ? (craft.activeJob!.progressSeconds / req).clamp(0.0, 1.0)
          : 0.0;
      progressMin = (craft.activeJob!.progressSeconds / 60).floor();
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(recipe.name),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Recipe hero card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    _DetailArtwork(recipe: recipe),
                    const SizedBox(height: 12),
                    Text(
                      recipe.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (recipe.description != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        recipe.description!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _DetailTag(label: '家具', color: AppColors.primaryLight),
                        SizedBox(width: 8),
                        _DetailTag(
                            label: '温馨', color: AppColors.accentPeachLight),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.timer_outlined,
                            size: 16, color: AppColors.primarySage),
                        const SizedBox(width: 6),
                        Text(
                          '需要专注 ${recipe.requiredMinutes} 分钟',
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                '制作材料',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              _MaterialsSummary(recipe: recipe),
              const SizedBox(height: 20),

              // Progress section
              if (isCompleted) ...[
                _statusCard(
                  '🎉 已制作完成',
                  '该家具已加入你的库存，可前往房间摆放',
                  AppColors.primaryLight,
                  AppColors.primarySage,
                ),
              ] else if (isActive) ...[
                const Text(
                  '制作进度',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: AppColors.surfaceMuted,
                    color: AppColors.accentPeach,
                    minHeight: 12,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '已专注 $progressMin 分钟',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      '目标 ${recipe.requiredMinutes} 分钟',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: const Row(
                    children: [
                      Text('☁', style: TextStyle(fontSize: 24)),
                      SizedBox(width: 10),
                      Expanded(
                          child: Text('每一次专注，都会让这件家具离完成更近一点。',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.primaryDark,
                                  height: 1.4))),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.timer_outlined),
                    label: const Text('去专注，加速制作'),
                    onPressed: () => context.go('/focus/setup'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton(
                    onPressed: () async {
                      final router = GoRouter.of(context);
                      final confirmed = await _confirmCancel(context);
                      if (!mounted) return;
                      if (confirmed == true) {
                        await ref
                            .read(craftControllerProvider.notifier)
                            .cancelJob();
                        if (mounted) router.pop();
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                    ),
                    child: const Text('取消制作'),
                  ),
                ),
              ] else if (hasOtherActiveJob) ...[
                _statusCard(
                  '⚙️ 当前有其他制作任务进行中',
                  '每次只能制作一件家具，完成或取消后再开始',
                  AppColors.accentGoldLight,
                  AppColors.accentGold,
                ),
              ] else ...[
                _statusCard(
                  '尚未开始制作',
                  '开始专注后，专注时间将自动转化为制作进度',
                  AppColors.surfaceMuted,
                  AppColors.textSecondary,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      await ref
                          .read(craftControllerProvider.notifier)
                          .startJob(recipe.id);
                      if (!mounted) return;
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('开始制作 ${recipe.name}！去专注吧 ♡'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    child: const Text(
                      '开始制作',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
              const Spacer(),

              // Inventory shortcut
              if (isCompleted)
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.inventory_2_outlined),
                    label: const Text('查看库存'),
                    onPressed: () => context.go('/inventory'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusCard(String title, String body, Color bg, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 4),
          Text(body,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary, height: 1.4)),
        ],
      ),
    );
  }

  Future<bool?> _confirmCancel(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('取消制作'),
        content: const Text('取消后制作进度将会丢失，确认取消？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('继续制作')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('确认取消',
                  style: TextStyle(color: AppColors.accentPeach))),
        ],
      ),
    );
  }
}

class _DetailArtwork extends StatelessWidget {
  final CraftRecipe recipe;
  const _DetailArtwork({required this.recipe});

  @override
  Widget build(BuildContext context) {
    final path = recipe.artworkPath;
    return Container(
      width: 120,
      height: 120,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.accentPeachLight,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.border),
      ),
      child: path == null || path.isEmpty
          ? Text(recipe.icon, style: const TextStyle(fontSize: 56))
          : Image.asset(path,
              width: 78,
              height: 78,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  Text(recipe.icon, style: const TextStyle(fontSize: 56))),
    );
  }
}

class _DetailTag extends StatelessWidget {
  final String label;
  final Color color;
  const _DetailTag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(AppRadius.pill)),
        child: Text(label,
            style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600)),
      );
}

class _MaterialsSummary extends StatelessWidget {
  final CraftRecipe recipe;
  const _MaterialsSummary({required this.recipe});

  @override
  Widget build(BuildContext context) {
    final entries = recipe.ingredientCosts.entries.toList();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border)),
      child: entries.isEmpty
          ? const Row(children: [
              Icon(Icons.auto_awesome, size: 18, color: AppColors.accentGold),
              SizedBox(width: 8),
              Text('材料会在专注中慢慢准备好',
                  style:
                      TextStyle(fontSize: 13, color: AppColors.textSecondary))
            ])
          : Wrap(
              spacing: 16,
              runSpacing: 8,
              children: entries
                  .map(
                      (entry) => Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.circle,
                                size: 7, color: AppColors.accentGold),
                            const SizedBox(width: 6),
                            Text(entry.key),
                            const SizedBox(width: 6),
                            Text('x${entry.value}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryDark))
                          ]))
                  .toList()),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../domain/models/craft_models.dart';
import '../controllers/craft_controller.dart';
import '../theme/app_theme.dart';

/// Screen 09A: Craft Workshop List (制作工坊列表).
/// Presentation only: recipe grouping, job progress, and navigation remain
/// backed by CraftController and the persisted models.
class CraftListPage extends ConsumerStatefulWidget {
  const CraftListPage({super.key});

  @override
  ConsumerState<CraftListPage> createState() => _CraftListPageState();
}

class _CraftListPageState extends ConsumerState<CraftListPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => ref.read(craftControllerProvider.notifier).loadAll());
  }

  @override
  Widget build(BuildContext context) {
    final craft = ref.watch(craftControllerProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: craft.isLoading
            ? const Center(child: CircularProgressIndicator())
            : craft.recipes.isEmpty
                ? _buildEmptyState()
                : _buildList(craft),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          _HeaderIconButton(
            icon: Icons.arrow_back_rounded,
            tooltip: '返回',
            onPressed: () => context.go('/'),
          ),
          const Expanded(
            child: Column(
              children: [
                Text('制作',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                    )),
                SizedBox(height: 3),
                Text('用专注时间慢慢制作',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    )),
              ],
            ),
          ),
          const SizedBox(width: 42),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildHeader()),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      color: AppColors.accentGoldLight,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    alignment: Alignment.center,
                    child: const Text('📦', style: TextStyle(fontSize: 42)),
                  ),
                  const SizedBox(height: 18),
                  const Text('暂无制作配方',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      )),
                  const SizedBox(height: 6),
                  const Text('完成更多专注，解锁新的房间物品。',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        height: 1.45,
                      )),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildList(CraftState craft) {
    final inProgressRecipes = craft.activeJob != null
        ? craft.recipes.where((r) => r.id == craft.activeJob!.recipeId).toList()
        : <CraftRecipe>[];
    final availableRecipes =
        craft.recipes.where((r) => r.id != craft.activeJob?.recipeId).toList();

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        _buildHeader(),
        _buildIntro(),
        if (inProgressRecipes.isNotEmpty)
          _RecipeSection(
            title: '制作中',
            subtitle: '一次只制作一件，让专注慢慢完成它。',
            color: AppColors.accentPeach,
            recipes: inProgressRecipes,
            craft: craft,
          ),
        if (availableRecipes.isNotEmpty)
          _RecipeSection(
            title: '可制作',
            subtitle: '选择一件喜欢的物品，开始你的下一段专注。',
            color: AppColors.primarySage,
            recipes: availableRecipes,
            craft: craft,
          ),
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 18, 24, 28),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lightbulb_outline_rounded,
                  size: 16, color: AppColors.accentGold),
              SizedBox(width: 7),
              Flexible(
                  child: Text('开始后，下一次专注会自动增加进度',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIntro() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        decoration: BoxDecoration(
          color: AppColors.accentGoldLight,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border:
              Border.all(color: AppColors.accentGold.withValues(alpha: .22)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: const Text('🛠️', style: TextStyle(fontSize: 25)),
            ),
            const SizedBox(width: 13),
            const Expanded(
                child: Text(
              '一次只制作一件，让现实中的专注推动房间成长。',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            )),
          ],
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _HeaderIconButton(
      {required this.icon, required this.tooltip, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon),
      color: AppColors.textPrimary,
      style: IconButton.styleFrom(
        backgroundColor: AppColors.surface,
        side: const BorderSide(color: AppColors.border),
        fixedSize: const Size(42, 42),
      ),
    );
  }
}

class _RecipeSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  final List<CraftRecipe> recipes;
  final CraftState craft;

  const _RecipeSection(
      {required this.title,
      required this.subtitle,
      required this.color,
      required this.recipes,
      required this.craft});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                  width: 5,
                  height: 38,
                  decoration: BoxDecoration(
                      color: color, borderRadius: BorderRadius.circular(3))),
              const SizedBox(width: 10),
              Expanded(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      )),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        height: 1.3,
                      )),
                ],
              )),
              Text('${recipes.length} 件',
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  )),
            ],
          ),
        ),
        ...recipes.map((recipe) {
          final inventoryItem = craft.inventory
              .where((i) => i.itemId == recipe.outputItemId)
              .firstOrNull;
          return _RecipeCard(
            recipe: recipe,
            activeJob: craft.activeJob,
            inventoryItem: inventoryItem,
          );
        }),
      ],
    );
  }
}

class _RecipeCard extends StatelessWidget {
  final CraftRecipe recipe;
  final CraftJob? activeJob;
  final InventoryItem? inventoryItem;

  const _RecipeCard(
      {required this.recipe,
      required this.activeJob,
      required this.inventoryItem});

  bool get _isActive => activeJob != null && activeJob!.recipeId == recipe.id;
  int get _ownedQuantity => inventoryItem != null && inventoryItem!.quantity > 0
      ? inventoryItem!.quantity
      : 0;

  @override
  Widget build(BuildContext context) {
    final progress = _isActive &&
            activeJob != null &&
            recipe.requiredSeconds > 0
        ? (activeJob!.progressSeconds / recipe.requiredSeconds).clamp(0.0, 1.0)
        : 0.0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/craft/detail/${recipe.id}'),
          child: Container(
            constraints: const BoxConstraints(minHeight: 166),
            decoration: BoxDecoration(
              border: Border.all(
                  color: _isActive
                      ? AppColors.accentPeach.withValues(alpha: .65)
                      : AppColors.border),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: _ArtworkPreview(recipe: recipe, isActive: _isActive),
                ),
                Expanded(
                    child: Padding(
                  padding: const EdgeInsets.fromLTRB(2, 16, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                              child: Text(recipe.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    height: 1.2,
                                  ))),
                          const SizedBox(width: 8),
                          _StatusChip(
                              label: _statusLabel,
                              foreground: _statusForeground,
                              background: _statusBackground),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Text(
                        recipe.description?.trim().isNotEmpty == true
                            ? recipe.description!
                            : '需要专注 ${recipe.requiredMinutes} 分钟，慢慢把它带回房间。',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_isActive)
                        _ProgressRow(
                            progress: progress,
                            currentSeconds: activeJob!.progressSeconds,
                            totalSeconds: recipe.requiredSeconds)
                      else
                        Row(
                          children: [
                            const Icon(Icons.schedule_rounded,
                                size: 15, color: AppColors.textTertiary),
                            const SizedBox(width: 5),
                            Text('${recipe.requiredMinutes} 分钟专注',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                )),
                            const Spacer(),
                            const Icon(Icons.arrow_forward_rounded,
                                size: 18, color: AppColors.primarySage),
                          ],
                        ),
                    ],
                  ),
                )),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String get _statusLabel {
    if (_isActive) return '制作中';
    if (_ownedQuantity > 0) return '已拥有 x$_ownedQuantity';
    return '可制作';
  }

  Color get _statusForeground {
    if (_isActive) return AppColors.accentPeach;
    if (_ownedQuantity > 0) return AppColors.primaryDark;
    return AppColors.primaryDark;
  }

  Color get _statusBackground {
    if (_isActive) return AppColors.accentPeachLight;
    if (_ownedQuantity > 0) return AppColors.primaryLight;
    return AppColors.primaryLight;
  }
}

class _ArtworkPreview extends StatelessWidget {
  final CraftRecipe recipe;
  final bool isActive;

  const _ArtworkPreview({required this.recipe, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 112,
      height: 140,
      decoration: BoxDecoration(
        color: isActive ? AppColors.accentPeachLight : AppColors.backgroundWarm,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      alignment: Alignment.center,
      child: recipe.artworkPath?.trim().isNotEmpty == true
          ? Image.asset(recipe.artworkPath!,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) =>
                  _FallbackArtwork(icon: recipe.icon))
          : _FallbackArtwork(icon: recipe.icon),
    );
  }
}

class _FallbackArtwork extends StatelessWidget {
  final String icon;
  const _FallbackArtwork({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          color: AppColors.surface,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.primarySage.withValues(alpha: .12),
              blurRadius: 14,
              offset: const Offset(0, 5),
            )
          ],
        ),
        alignment: Alignment.center,
        child: Text(icon, style: const TextStyle(fontSize: 30)),
      ),
      const SizedBox(height: 9),
      const Text('家具草图',
          style: TextStyle(
            color: AppColors.textTertiary,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          )),
    ]);
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color foreground;
  final Color background;

  const _StatusChip(
      {required this.label,
      required this.foreground,
      required this.background});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(label,
          style: TextStyle(
            color: foreground,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          )),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  final double progress;
  final int currentSeconds;
  final int totalSeconds;

  const _ProgressRow(
      {required this.progress,
      required this.currentSeconds,
      required this.totalSeconds});

  @override
  Widget build(BuildContext context) {
    final currentMinutes = (currentSeconds / 60).floor();
    final totalMinutes = (totalSeconds / 60).ceil();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: LinearProgressIndicator(
          value: progress,
          backgroundColor: AppColors.surfaceMuted,
          color: AppColors.accentPeach,
          minHeight: 7,
        ),
      ),
      const SizedBox(height: 6),
      Row(children: [
        Text('$currentMinutes / $totalMinutes 分钟',
            style: const TextStyle(
              color: AppColors.accentPeach,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            )),
        const Spacer(),
        const Text('继续专注',
            style: TextStyle(
              color: AppColors.textTertiary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            )),
      ]),
    ]);
  }
}

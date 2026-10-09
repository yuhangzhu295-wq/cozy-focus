import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../domain/models/enums.dart';
import '../companion/collection/collection_acquisition.dart';
import '../companion/collection_unlock.dart';
import '../controllers/craft_controller.dart';
import '../controllers/growth_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/cozy_furniture_artwork.dart';
import '../widgets/growth_sub_nav.dart';
import '../companion/companion_avatar.dart';
import '../widgets/app_bottom_nav.dart';

/// Catalog item definition for collection items.
/// Bounded preview catalog mapping to real craft inventory items when available,
/// and display categories matching design reference 10B_collection.png.
class CollectionCatalogItem {
  final String id;
  final String name;
  final String category;
  final IconData icon;
  final String description;

  /// Whether the loop can actually deliver this item.
  ///
  /// `false` marks a preview entry: it has no craft recipe and no other grant,
  /// so it can never enter the inventory. Two things follow, and both are the
  /// point of the flag rather than incidental:
  ///
  /// 1. It is excluded from the progress total. Counting it made the bar
  ///    unsatisfiable — with two preview entries the collection could never
  ///    pass 8/10, so a player who had collected everything still saw a bar
  ///    that refused to fill.
  /// 2. Its card reads 未开放 rather than 未收集. "Not collected" implies the
  ///    player could collect it; "not yet open" is what is true.
  ///
  /// The flag is checked against the recipe truth by
  /// `test/presentation/collection_craft_loop_gap_test.dart`, in both
  /// directions, so it cannot quietly disagree with reality.
  final bool obtainable;

  const CollectionCatalogItem({
    required this.id,
    required this.name,
    required this.category,
    required this.icon,
    required this.description,
    this.obtainable = true,
  });
}

/// Bounded catalog of items displayed in the collection.
/// Item IDs match repository-backed InventoryItem IDs for craft items,
/// ensuring truthful verification of ownership (quantity > 0).
const List<CollectionCatalogItem> kCollectionCatalog = [
  CollectionCatalogItem(
    id: 'sofa',
    name: '温馨布艺沙发',
    category: '家具',
    icon: Icons.chair_rounded,
    description: '柔软舒适的双人布艺沙发，适合休息放松。',
  ),
  CollectionCatalogItem(
    id: 'table',
    name: '原木茶几',
    category: '家具',
    icon: Icons.table_restaurant_rounded,
    description: '纹理质朴的原木小茶几，可摆放茶点与书籍。',
  ),
  CollectionCatalogItem(
    id: 'bookshelf',
    name: '简约书架',
    category: '家具',
    icon: Icons.menu_book_rounded,
    description: '结实耐用的原木书架，收纳专注时阅读的书籍。',
  ),
  CollectionCatalogItem(
    id: 'bed',
    name: '治愈小床',
    category: '家具',
    icon: Icons.bed_rounded,
    description: '松软温暖的单人床，伴你度过甜美夜晚。',
  ),
  CollectionCatalogItem(
    id: 'rug',
    name: '编织地毯',
    category: '生活',
    icon: Icons.crop_square_rounded,
    description: '手工编织的纯羊毛小地毯，保暖又防滑。',
  ),
  CollectionCatalogItem(
    id: 'lamp',
    name: '暖光台灯',
    category: '生活',
    icon: Icons.light_rounded,
    description: '温暖柔和的暖黄台灯，照亮专注时光。',
  ),
  CollectionCatalogItem(
    id: 'cabinet',
    name: '原木收纳矮柜',
    category: '家具',
    icon: Icons.kitchen_rounded,
    description: '精巧的储物柜，让小屋井井有条。',
  ),
  CollectionCatalogItem(
    id: 'desk',
    name: '专注写字台',
    category: '家具',
    icon: Icons.desk_rounded,
    description: '陪伴每一次深度心流的木质书桌。',
  ),
  CollectionCatalogItem(
    id: 'plant_succulent',
    name: '多肉盆栽',
    category: '植物',
    icon: Icons.yard_rounded,
    description: '生机勃勃的治愈多肉，增添清新绿意。',
    // Preview entry: no recipe, no grant. See [CollectionCatalogItem.obtainable].
    obtainable: false,
  ),
  CollectionCatalogItem(
    id: 'special_trophy',
    name: '专注纪念徽章',
    category: '特别',
    icon: Icons.military_tech_rounded,
    description: '记录漫长专注旅途的特别荣誉勋章。',
    // Preview entry: no recipe, no grant. See [CollectionCatalogItem.obtainable].
    obtainable: false,
  ),
];

/// Screen: Growth > Collection Page
/// Truthful collection screen displaying repository-backed inventory ownership
/// and pet context, while keeping unsupported achievement data visibly unavailable.
class PetCollectionPage extends ConsumerStatefulWidget {
  const PetCollectionPage({super.key});

  @override
  ConsumerState<PetCollectionPage> createState() => _PetCollectionPageState();
}

class _PetCollectionPageState extends ConsumerState<PetCollectionPage> {
  String _selectedCategory = '全部';

  /// Watches the real inventory for items that have just become owned.
  ///
  /// Read from a provider rather than owned by this `State`: inventory only
  /// changes during a focus-session settlement, so a page-scoped tracker would
  /// take a fresh baseline on every visit and could never observe the
  /// transition it exists to report. The tracker is fed only collection items,
  /// so its baseline is about the collection rather than about everything the
  /// craft system stores.
  PetCollectionUnlockTracker get _unlockTracker =>
      ref.read(petCollectionUnlockTrackerProvider);

  /// The one-shot celebration currently on screen, if any.
  ///
  /// `null` means "no override": Mochi falls back to whatever the presentation
  /// mapper derives, which is the normal case. Clearing it needs no memory of
  /// what came before — the mapper is the answer.
  PetVisualState? _unlockCelebration;

  /// The name of the item that just unlocked, while the celebration lasts.
  String? _unlockMessage;

  Timer? _unlockTimer;

  /// How long the unlock celebration stays up.
  ///
  /// Long enough to read the item name, short enough not to become a state the
  /// page is stuck in. 11I is a one-shot for exactly this reason.
  static const Duration _unlockDisplayDuration = Duration(milliseconds: 2600);

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(craftControllerProvider.notifier).loadAll();
    });
  }

  @override
  void dispose() {
    _unlockTimer?.cancel();
    super.dispose();
  }

  /// Reacts to a real, newly-owned collection item.
  ///
  /// Driven from a provider listener rather than derived during `build`: an
  /// unlock is a thing that *happens*, not a thing that is true, and deriving it
  /// per rebuild would fire once per frame. [PetCollectionUnlockTracker] also
  /// returns `null` for its first observation, so arriving on the page with a
  /// full collection celebrates nothing — see the class docs for why that
  /// matters.
  void _onInventoryChanged(CraftState craft) {
    // A loading state is **not an authoritative reading**. `CraftController`
    // emits `isLoading: true` carrying the *previous* inventory before the rows
    // arrive, and on a cold controller that previous inventory is empty. Feeding
    // that to the tracker would establish a false empty baseline, and the very
    // next real reading would then look like a whole collection being unlocked
    // at once — the exact false celebration this feature exists to prevent.
    if (craft.isLoading) return;

    final catalogIds = kCollectionCatalog.map((entry) => entry.id).toSet();
    final unlockedItemId = _unlockTracker.observe(
      craft.inventory.where((item) => catalogIds.contains(item.itemId)),
    );
    if (unlockedItemId == null || !mounted) return;

    final item = kCollectionCatalog.firstWhere(
      (entry) => entry.id == unlockedItemId,
    );

    _unlockTimer?.cancel();
    setState(() {
      _unlockCelebration = PetVisualState.celebrate;
      _unlockMessage = '新收藏：${item.name}！';
    });
    _unlockTimer = Timer(_unlockDisplayDuration, () {
      if (!mounted) return;
      setState(() {
        _unlockCelebration = null;
        _unlockMessage = null;
      });
      _unlockTimer = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final growthState = ref.watch(growthControllerProvider);
    final craftState = ref.watch(craftControllerProvider);

    ref.listen<CraftState>(craftControllerProvider, (_, next) {
      _onInventoryChanged(next);
    });

    final Map<String, int> inventoryQuantities = {};
    for (final inv in craftState.inventory) {
      inventoryQuantities[inv.itemId] =
          (inventoryQuantities[inv.itemId] ?? 0) + inv.quantity;
    }

    // Only entries the loop can actually deliver count toward completion.
    // Preview entries are still shown, but including them made the bar
    // unsatisfiable — see [CollectionCatalogItem.obtainable].
    int ownedCount = 0;
    var obtainableTotal = 0;
    for (final item in kCollectionCatalog) {
      if (!item.obtainable) continue;
      obtainableTotal++;
      final qty = inventoryQuantities[item.id] ?? 0;
      if (qty > 0) {
        ownedCount++;
      }
    }

    final Map<String, int> placedCounts = {};
    for (final placed in craftState.roomItems) {
      placedCounts[placed.itemId] = (placedCounts[placed.itemId] ?? 0) + 1;
    }

    // P29.1 — the acquisition view is derived from the live craft, inventory and
    // room state on every build, never copied into the catalog. Change a
    // recipe's duration and this page changes with it.
    CollectionAcquisitionViewModel vmFor(CollectionCatalogItem item) =>
        CollectionAcquisitionViewModel.from(
          itemId: item.id,
          itemName: item.name,
          obtainable: item.obtainable,
          recipes: craftState.recipes,
          activeJob: craftState.activeJob,
          activeRecipe: craftState.activeRecipe,
          ownedQuantity: inventoryQuantities[item.id] ?? 0,
          placedCount: placedCounts[item.id] ?? 0,
        );

    final filteredItems = _selectedCategory == '全部'
        ? kCollectionCatalog
        : kCollectionCatalog
            .where((item) => item.category == _selectedCategory)
            .toList();

    const categories = ['全部', '植物', '家具', '生活', '特别'];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('收藏图鉴'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, semanticLabel: '返回'),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/growth');
            }
          },
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          children: [
            const GrowthSubNav(active: GrowthSection.collection),
            const SizedBox(height: 16),
            _buildPetContextHeader(growthState),
            const SizedBox(height: 16),
            _buildSummaryCard(ownedCount, obtainableTotal),
            const SizedBox(height: 16),
            _buildCategoryFilter(categories),
            const SizedBox(height: 16),
            _buildCollectionGrid(filteredItems, vmFor),
            const SizedBox(height: 20),
            _buildEncouragementBanner(),
            const SizedBox(height: 24),
            _buildUnsupportedAchievementSection(),
            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 2),
    );
  }

  Widget _buildPetContextHeader(GrowthState state) {
    final pet = state.pet;
    if (pet == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text(
            '暂无宠物陪伴，前往成长页领养宠物伙伴吧！',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CompanionAvatar(
            size: 56,
            // Only the unlock message. It used to fall back to the page title,
            // which drew the same words in a bubble directly beside the heading
            // — twice on screen, and one merged announcement in the
            // accessibility tree reading `小猫 的收藏屋 🌱\n小猫 空闲\n小猫 的收藏屋`.
            message: _unlockMessage,
            // `null` outside an unlock, so the presentation mapper keeps
            // deciding and there is no previous state to remember.
            visualStateOverride: _unlockCelebration,
            showStateBadge: false,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${pet.name} 的收藏屋',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '陪伴伙伴 · 专注点滴收藏',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Reference 10B shows the collection progress as one card: an icon and
  /// title on the left, the owned/total fraction and percentage on the right,
  /// and a progress bar underneath. The previous version showed only
  /// "已拥有 N 件", which told the user nothing about how much is left.
  Widget _buildSummaryCard(int ownedCount, int totalCount) {
    final ratio = totalCount == 0 ? 0.0 : ownedCount / totalCount;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Icon(
                  Icons.auto_stories_rounded,
                  color: AppColors.primarySage,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '图鉴收集',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      // P29.6 — the loop, in the one place the page already
                      // explains itself. This replaced a vague line rather than
                      // adding a block: the copy was the problem, and a second
                      // banner saying the same thing would be clutter.
                      '选配方 → 专注变制作进度 → 做好入库存 → 摆进房间',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$ownedCount / $totalCount',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '已收集 ${(ratio * 100).round()}%',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor: AppColors.surfaceMuted,
              color: AppColors.primarySage,
            ),
          ),
        ],
      ),
    );
  }

  /// Reference 10B closes the page with this line.
  Widget _buildEncouragementBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: const Text(
        '🌱 生活中的每一份专注，都会让这个小小的世界更丰富。💚',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          color: AppColors.primaryDark,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildCategoryFilter(List<String> categories) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: categories.map((category) {
          final isSelected = _selectedCategory == category;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: FilterChip(
              label: Text(category),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedCategory = category;
                });
              },
              selectedColor: AppColors.primaryLight,
              checkmarkColor: AppColors.primarySage,
              labelStyle: TextStyle(
                color: isSelected
                    ? AppColors.primaryDark
                    : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              backgroundColor: AppColors.surface,
            ),
          );
        }).toList(),
      ),
    );
  }

  /// The acquisition detail for one item (P29.3).
  ///
  /// Every number in the sheet comes from the live recipe and job, so editing a
  /// recipe changes this without touching the collection catalog.
  Future<void> _showAcquisitionDetail(
    CollectionAcquisitionViewModel vm,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.md)),
      ),
      builder: (sheetContext) => _AcquisitionSheet(
        vm: vm,
        onGo: (route) {
          Navigator.of(sheetContext).pop();
          // A recipe detail is a pushed page; the room and the inventory are
          // destinations. Both are existing routes — no CTA here invents one.
          if (route.startsWith('/craft/detail')) {
            context.push(route);
          } else {
            context.go(route);
          }
        },
      ),
    );
  }

  Widget _buildCollectionGrid(
    List<CollectionCatalogItem> items,
    CollectionAcquisitionViewModel Function(CollectionCatalogItem) vmFor,
  ) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      // Reference 10B lays the catalogue out as a dense four-column grid so the
      // whole collection is readable at a glance. Two columns made the page
      // scroll for several screens and hid how much of the set exists.
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 10,
        childAspectRatio: 0.72,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final vm = vmFor(item);
        final isOwned = vm.ownedQuantity > 0;

        return GestureDetector(
          onTap: vm.isTappable ? () => _showAcquisitionDetail(vm) : null,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color: isOwned ? AppColors.primarySage : AppColors.border,
                width: isOwned ? 1.5 : 1.0,
              ),
            ),
            padding: const EdgeInsets.all(6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: isOwned
                          ? AppColors.primaryLight
                          : AppColors.surfaceMuted,
                      child: Opacity(
                        opacity: isOwned ? 1 : 0.48,
                        // The tile names the item below; the artwork's
                        // own label would say it a second time.
                        child: ExcludeSemantics(
                          child: CozyFurnitureArtwork(
                            itemId: item.id,
                            size: 36,
                          ),
                        ),
                      ),
                    ),
                    if (!isOwned)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Colors.grey,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.lock_rounded,
                            size: 10,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  item.name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isOwned
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  vm.statusLine,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 9,
                    color: isOwned
                        ? AppColors.primarySage
                        : AppColors.textTertiary,
                    fontWeight: isOwned ? FontWeight.bold : FontWeight.normal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildUnsupportedAchievementSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline,
                  size: 18, color: AppColors.textSecondary),
              SizedBox(width: 8),
              Text(
                '成就系统',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            '成就与勋章数据尚未接入运行时数据库，当前仅展示真实背包收集品。\n后续版本将支持更多成就里程碑。',
            style: TextStyle(
                fontSize: 13, color: AppColors.textSecondary, height: 1.4),
          ),
        ],
      ),
    );
  }
}

/// The acquisition detail sheet.
///
/// Shows what the item is, how it is obtained, how much real progress it needs,
/// what the current state is and what the player can do next — the five things
/// P29.3 asks for — and nothing the product cannot back up.
class _AcquisitionSheet extends StatelessWidget {
  final CollectionAcquisitionViewModel vm;
  final void Function(String route) onGo;

  const _AcquisitionSheet({required this.vm, required this.onGo});

  @override
  Widget build(BuildContext context) {
    final recipe = vm.recipe;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Named by the text beside it, so the artwork is decoration
              // here rather than a second reading of the same name.
              ExcludeSemantics(
                child: CozyFurnitureArtwork(itemId: vm.itemId, size: 40),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(vm.itemName,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _row('获取方式', vm.howToObtain),
          if (recipe != null) ...[
            const SizedBox(height: 8),
            _row('制作工坊', recipe.name),
            const SizedBox(height: 8),
            _row('需要专注', '${recipe.requiredMinutes} 分钟'),
            const SizedBox(height: 8),
            // Materials are read from the recipe, not asserted. Today every
            // shipped recipe costs time only, and the sheet says so rather than
            // showing an empty list that reads like a missing feature.
            _row('材料需求', vm.requiresMaterials ? _materialsText() : '无需额外材料'),
          ],
          if (vm.status == CollectionAcquisitionStatus.crafting) ...[
            const SizedBox(height: 8),
            _row('当前进度',
                '${vm.progressSeconds ~/ 60} / ${vm.requiredMinutes} 分钟'),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: vm.progressFraction,
                minHeight: 6,
                backgroundColor: AppColors.surfaceMuted,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.primarySage),
              ),
            ),
          ],
          if (vm.ownedQuantity > 0) ...[
            const SizedBox(height: 8),
            _row('当前拥有', 'x${vm.ownedQuantity}'),
          ],
          if (vm.placedCount > 0) ...[
            const SizedBox(height: 8),
            _row('已摆放', 'x${vm.placedCount}'),
          ],
          const SizedBox(height: 18),
          // An unavailable item gets no button at all. A disabled one would
          // imply a path that does not exist.
          if (vm.ctaLabel != null && vm.ctaRoute != null)
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => onGo(vm.ctaRoute!),
                child: Text(vm.ctaLabel!),
              ),
            )
          else
            const Text('当前版本尚未开放',
                style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
        ],
      ),
    );
  }

  String _materialsText() =>
      vm.ingredientCosts.entries.map((e) => '${e.key} x${e.value}').join('、');

  Widget _row(String label, String value) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textTertiary)),
          ),
          Expanded(
            child:
                Text(value, style: const TextStyle(fontSize: 12, height: 1.4)),
          ),
        ],
      );
}

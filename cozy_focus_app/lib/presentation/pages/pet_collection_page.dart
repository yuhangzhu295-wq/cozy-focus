import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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

  const CollectionCatalogItem({
    required this.id,
    required this.name,
    required this.category,
    required this.icon,
    required this.description,
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
  ),
  CollectionCatalogItem(
    id: 'special_trophy',
    name: '专注纪念徽章',
    category: '特别',
    icon: Icons.military_tech_rounded,
    description: '记录漫长专注旅途的特别荣誉勋章。',
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

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(craftControllerProvider.notifier).loadAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final growthState = ref.watch(growthControllerProvider);
    final craftState = ref.watch(craftControllerProvider);

    final Map<String, int> inventoryQuantities = {};
    for (final inv in craftState.inventory) {
      inventoryQuantities[inv.itemId] =
          (inventoryQuantities[inv.itemId] ?? 0) + inv.quantity;
    }

    int ownedCount = 0;
    for (final item in kCollectionCatalog) {
      final qty = inventoryQuantities[item.id] ?? 0;
      if (qty > 0) {
        ownedCount++;
      }
    }

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
          icon: const Icon(Icons.arrow_back),
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
            _buildSummaryCard(ownedCount, kCollectionCatalog.length),
            const SizedBox(height: 16),
            _buildCategoryFilter(categories),
            const SizedBox(height: 16),
            _buildCollectionGrid(filteredItems, inventoryQuantities),
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
            message: '${pet.name} 的收藏屋 🌱',
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
                      '用专注，解锁更多美好的事物吧！',
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

  Widget _buildCollectionGrid(
    List<CollectionCatalogItem> items,
    Map<String, int> inventoryQuantities,
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
        final quantity = inventoryQuantities[item.id] ?? 0;
        final isOwned = quantity > 0;

        return Container(
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
                      child: CozyFurnitureArtwork(
                        itemId: item.id,
                        size: 36,
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
                  color:
                      isOwned ? AppColors.textPrimary : AppColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                isOwned ? '已拥有 x$quantity' : '未收集',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9,
                  color:
                      isOwned ? AppColors.primarySage : AppColors.textTertiary,
                  fontWeight: isOwned ? FontWeight.bold : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
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

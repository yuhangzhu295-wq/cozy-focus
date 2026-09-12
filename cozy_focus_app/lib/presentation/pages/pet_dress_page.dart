import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/pet_models.dart';
import '../controllers/growth_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/pet_avatar_widget.dart';

/// Presentation metadata for outfit catalog preview items.
class OutfitPreviewItem {
  final String id;
  final String name;
  final String category;
  final IconData icon;
  final String description;

  const OutfitPreviewItem({
    required this.id,
    required this.name,
    required this.category,
    required this.icon,
    required this.description,
  });
}

/// Bounded outfit catalog preview matching design reference categories.
const List<OutfitPreviewItem> kPreviewOutfitCatalog = [
  OutfitPreviewItem(
    id: 'basic_collar',
    name: '基础红项圈',
    category: '颈饰',
    icon: Icons.circle_outlined,
    description: '陪伴初识时的经典红色编织项圈。',
  ),
  OutfitPreviewItem(
    id: 'cozy_scarf',
    name: '暖冬姜黄围巾',
    category: '颈饰',
    icon: Icons.waves_rounded,
    description: '柔软保暖的针织羊毛围巾。',
  ),
  OutfitPreviewItem(
    id: 'beret_hat',
    name: '小画家贝雷帽',
    category: '头饰',
    icon: Icons.brush_rounded,
    description: '充满文艺与创想气息的深蓝贝雷帽。',
  ),
  OutfitPreviewItem(
    id: 'gentleman_bowtie',
    name: '绅士小领结',
    category: '颈饰',
    icon: Icons.favorite_border_rounded,
    description: '精致优雅的深绿丝质蝴蝶结。',
  ),
];

/// Screen: Growth > Pet Dress (10A 宠物装扮)
/// Presentation slice aligned to design reference 10A_pet_outfit.png / 10A_宠物装扮.png.
/// Because no outfit domain/data/repository contract exists in current codebase,
/// this screen renders an honest unavailable/not-yet-connected state with no fake equip actions.
class PetDressPage extends ConsumerWidget {
  const PetDressPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final growthState = ref.watch(growthControllerProvider);
    final pet = growthState.pet;
    final title = pet != null ? '${pet.name} 的衣橱' : '宠物装扮';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundWarm,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: AppColors.textPrimary),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/growth');
            }
          },
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryDark,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _buildPetPreviewSection(context, pet),
            ),
            SliverToBoxAdapter(
              child: _buildHonestStatusNotice(),
            ),
            SliverToBoxAdapter(
              child: _buildCatalogHeader(),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.82,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = kPreviewOutfitCatalog[index];
                    return _buildOutfitCard(item);
                  },
                  childCount: kPreviewOutfitCatalog.length,
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: SizedBox(height: 24),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  Widget _buildPetPreviewSection(BuildContext context, Pet? pet) {
    if (pet != null) {
      return Container(
        color: AppColors.backgroundWarm,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          children: [
            PetAvatarWidget(
              visualState: PetVisualState.idle,
              size: 150,
              message: '${pet.name} 试衣间 🌱',
            ),
            const SizedBox(height: 12),
            Text(
              pet.name,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              '当前装扮：暂无已装备外饰',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      color: AppColors.backgroundWarm,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: const Column(
        children: [
          PetAvatarWidget(
            visualState: PetVisualState.idle,
            size: 150,
            message: '暂未领养宠物，暂无可用装扮',
          ),
          SizedBox(height: 12),
          Text(
            '暂未领养宠物',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 4),
          Text(
            '暂无可装扮的宠物伙伴',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHonestStatusNotice() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline_rounded,
              size: 18, color: AppColors.textSecondary),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              '装扮系统未连接数据，暂无可用装扮，无法穿戴。',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCatalogHeader() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '装扮图鉴',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            '图鉴预览',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutfitCard(OutfitPreviewItem item) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            height: 56,
            width: 56,
            decoration: const BoxDecoration(
              color: AppColors.backgroundWarm,
              shape: BoxShape.circle,
            ),
            child: Icon(item.icon, size: 28, color: AppColors.primarySage),
          ),
          const SizedBox(height: 8),
          Text(
            item.name,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            item.category,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textTertiary,
            ),
          ),
          const Spacer(),
          // Disabled button: explicitly null onPressed to ensure no fake clickable equip actions.
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: null,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
              child: const Text(
                '未连接',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: 2,
      selectedItemColor: AppColors.primarySage,
      unselectedItemColor: AppColors.textTertiary,
      backgroundColor: AppColors.surface,
      onTap: (index) {
        if (index == 2) {
          context.go('/growth');
          return;
        }
        switch (index) {
          case 0:
            context.go('/');
          case 1:
            context.go('/records');
        }
      },
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_rounded),
          label: '首页',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.bar_chart_rounded),
          label: '记录',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.eco_outlined),
          label: '成长',
        ),
      ],
    );
  }
}

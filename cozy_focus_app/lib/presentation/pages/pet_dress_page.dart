import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../domain/models/pet_models.dart';
import '../controllers/growth_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/growth_sub_nav.dart';
import '../companion/companion_avatar.dart';
import '../widgets/app_bottom_nav.dart';

/// Presentation metadata for outfit catalog preview items.
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
              semanticLabel: '返回', color: AppColors.textPrimary),
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
            const SliverToBoxAdapter(
              child: GrowthSubNav(active: GrowthSection.dress),
            ),
            SliverToBoxAdapter(
              child: _buildPetPreviewSection(context, pet),
            ),
            SliverToBoxAdapter(
              child: _buildHonestStatusNotice(),
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
            CompanionAvatar(
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
          CompanionAvatar(
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

  Widget _buildBottomNav(BuildContext context) {
    return const AppBottomNav(currentIndex: 2);
  }
}

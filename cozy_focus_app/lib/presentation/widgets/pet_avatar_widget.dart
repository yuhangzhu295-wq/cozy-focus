import 'package:flutter/material.dart';
import '../../domain/models/enums.dart';
import '../theme/app_theme.dart';

/// FallbackPetAdapter UI representation of Mochi.
/// Aligned strictly with Phase 2 rules:
/// - Controlled only by [PetVisualState] (idle, focus, pause, celebrate, sleep, etc.)
/// - No fake .riv files created.
/// - Displays Mochi the dog with appropriate mood, cozy props, and animated gentle pulse.
class PetAvatarWidget extends StatefulWidget {
  final PetVisualState visualState;
  final double size;
  final String? message;

  const PetAvatarWidget({
    super.key,
    required this.visualState,
    this.size = 140,
    this.message,
  });

  @override
  State<PetAvatarWidget> createState() => _PetAvatarWidgetState();
}

class _PetAvatarWidgetState extends State<PetAvatarWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _breatheController;
  late Animation<double> _breatheAnimation;

  @override
  void initState() {
    super.initState();
    _breatheController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _breatheAnimation = Tween<double>(begin: 0.97, end: 1.03).animate(
      CurvedAnimation(parent: _breatheController, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _breatheController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stateConfig = _getConfig(widget.visualState);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.message != null) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              widget.message!,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
        ScaleTransition(
          scale: _breatheAnimation,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: stateConfig.bgTint,
              border: Border.all(color: stateConfig.borderColor, width: 2),
              boxShadow: [
                BoxShadow(
                  color: stateConfig.borderColor.withValues(alpha: 0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Cute Dog Character Illustration & Accessory
                Icon(
                  Icons.pets_rounded,
                  size: widget.size * 0.45,
                  color: stateConfig.iconColor,
                ),
                Positioned(
                  bottom: widget.size * 0.12,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.surface.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(stateConfig.stateIcon,
                            size: 13, color: stateConfig.iconColor),
                        const SizedBox(width: 4),
                        Text(
                          stateConfig.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: stateConfig.iconColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  _StateVisualConfig _getConfig(PetVisualState state) {
    switch (state) {
      case PetVisualState.focus:
        return const _StateVisualConfig(
          label: 'Mochi 专注中',
          bgTint: Color(0xFFE8F2EC),
          borderColor: AppColors.primarySage,
          iconColor: AppColors.primaryDark,
          stateIcon: Icons.menu_book_rounded,
        );
      case PetVisualState.pause:
        return const _StateVisualConfig(
          label: 'Mochi 休息中',
          bgTint: Color(0xFFFBF4E8),
          borderColor: AppColors.accentGold,
          iconColor: Color(0xFFB57D1B),
          stateIcon: Icons.coffee_rounded,
        );
      case PetVisualState.celebrate:
        return const _StateVisualConfig(
          label: '太棒啦!',
          bgTint: Color(0xFFFDF1EB),
          borderColor: AppColors.accentPeach,
          iconColor: AppColors.accentPeach,
          stateIcon: Icons.star_rounded,
        );
      case PetVisualState.sleep:
        return const _StateVisualConfig(
          label: '晚安 Mochi',
          bgTint: Color(0xFFEBF0F5),
          borderColor: Color(0xFF8CA1B3),
          iconColor: Color(0xFF5A7285),
          stateIcon: Icons.bedtime_rounded,
        );
      case PetVisualState.craft:
        return const _StateVisualConfig(
          label: 'Mochi 制作中',
          bgTint: Color(0xFFF4EBE3),
          borderColor: Color(0xFFB38260),
          iconColor: Color(0xFF8C5C3A),
          stateIcon: Icons.handyman_rounded,
        );
      case PetVisualState.greeting:
      case PetVisualState.idle:
      case PetVisualState.interact:
        return const _StateVisualConfig(
          label: 'Mochi 陪伴中',
          bgTint: Color(0xFFF7F2EA),
          borderColor: Color(0xFFC7BCAB),
          iconColor: Color(0xFF7A6E5D),
          stateIcon: Icons.favorite_rounded,
        );
    }
  }
}

class _StateVisualConfig {
  final String label;
  final Color bgTint;
  final Color borderColor;
  final Color iconColor;
  final IconData stateIcon;

  const _StateVisualConfig({
    required this.label,
    required this.bgTint,
    required this.borderColor,
    required this.iconColor,
    required this.stateIcon,
  });
}

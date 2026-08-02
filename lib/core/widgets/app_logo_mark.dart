// lib/core/widgets/app_logo_mark.dart
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// The AquaGas brand mark: a rounded gradient badge combining a flame
/// (gas) with a water-drop accent badge. Used on the splash and login
/// screens instead of leaning on a plain emoji.
class AppLogoMark extends StatelessWidget {
  const AppLogoMark({super.key, this.size = 84, this.glow = true});

  final double size;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final badgeSize = size * 0.34;
    return SizedBox(
      width: size,
      height: size + badgeSize * 0.2,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              gradient: AppColors.heroGradient,
              borderRadius: BorderRadius.circular(size * 0.28),
              boxShadow: glow
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.38),
                        blurRadius: size * 0.32,
                        offset: Offset(0, size * 0.12),
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              Icons.local_fire_department,
              color: Colors.white,
              size: size * 0.52,
            ),
          ),
          Positioned(
            right: -badgeSize * 0.18,
            bottom: -badgeSize * 0.18,
            child: Container(
              width: badgeSize,
              height: badgeSize,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.background,
                  width: size * 0.035,
                ),
              ),
              child: Icon(
                Icons.opacity,
                color: AppColors.info,
                size: badgeSize * 0.56,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

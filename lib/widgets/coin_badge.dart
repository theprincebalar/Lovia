import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/coin_provider.dart';
import '../theme/app_colors.dart';

class CoinBadge extends StatelessWidget {
  final VoidCallback? onTap;

  const CoinBadge({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Consumer<CoinProvider>(
      builder: (context, coinProvider, child) {
        return GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0x3300E5FF), Color(0x1A00E5FF)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.diamond.withOpacity(0.5),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.diamond.withOpacity(0.15),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (coinProvider.isSubscribed) ...[
                  const Icon(
                    Icons.workspace_premium_rounded,
                    color: AppColors.gold,
                    size: 15,
                  ),
                  const SizedBox(width: 3),
                  const Text(
                    "VIP",
                    style: TextStyle(
                      color: AppColors.goldLight,
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                    ),
                  ),
                  const Text(
                    " • ",
                    style: TextStyle(color: AppColors.goldLight, fontSize: 11),
                  ),
                ],
                const Icon(
                  Icons.diamond_rounded,
                  color: AppColors.diamond,
                  size: 16,
                ),
                const SizedBox(width: 5),
                Text(
                  '${coinProvider.balance}',
                  style: const TextStyle(
                    color: AppColors.diamondLight,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 3),
                const Icon(
                  Icons.add_circle_outline_rounded,
                  color: AppColors.diamond,
                  size: 14,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

typedef DiamondBadge = CoinBadge;


import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class ResponsiveFrame extends StatelessWidget {
  final Widget child;

  const ResponsiveFrame({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 500) {
          // Centered mobile phone frame for wide desktop / web screens
          return Container(
            color: const Color(0xFF040508),
            child: Center(
              child: Container(
                width: 420,
                height: constraints.maxHeight.clamp(600.0, 920.0),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(36),
                  border: Border.all(
                    color: AppColors.glassBorder.withOpacity(0.5),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.12),
                      blurRadius: 40,
                      spreadRadius: 4,
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.8),
                      blurRadius: 30,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: child,
              ),
            ),
          );
        }

        // Native mobile phone screen
        return child;
      },
    );
  }
}

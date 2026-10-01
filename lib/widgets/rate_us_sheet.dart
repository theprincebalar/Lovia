import 'dart:io';
import 'package:flutter/material.dart';
import '../services/review_service.dart';
import '../theme/app_colors.dart';

class RateUsSheet extends StatefulWidget {
  const RateUsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => const RateUsSheet(),
    );
  }

  @override
  State<RateUsSheet> createState() => _RateUsSheetState();
}

class _RateUsSheetState extends State<RateUsSheet> {
  int _selectedRating = 5;

  String get _ratingLabel {
    switch (_selectedRating) {
      case 1:
        return "Needs Work 💔";
      case 2:
        return "Could Be Better 😕";
      case 3:
        return "It's Good 🙂";
      case 4:
        return "Loved It! 🥰";
      case 5:
      default:
        return "Best AI Experience! ✨💖";
    }
  }

  Future<void> _handleSubmit() async {
    Navigator.pop(context);

    // Trigger official Apple StoreKit / Google Play review prompt
    await ReviewService().requestDirectReview();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.favorite_rounded, color: Colors.pinkAccent, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Thank you for supporting Lovia! ❤️",
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF2D143F),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + bottomPadding),
      decoration: const BoxDecoration(
        color: Color(0xFF160D24),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: Color(0xFF4A286D), width: 1.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black87,
            blurRadius: 30,
            offset: Offset(0, -10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Glowing App Icon / Star Badge
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.primaryGradient,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.4),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.star_rounded,
              color: AppColors.goldLight,
              size: 40,
            ),
          ),
          const SizedBox(height: 16),

          // Heading
          const Text(
            "Enjoying Lovia?",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),

          // Subtitle
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              "Your rating helps us bring you more realistic AI companion voices, roleplay scenarios, and memories!",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Interactive 5-Star Row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final starIndex = index + 1;
              final isFilled = starIndex <= _selectedRating;

              return GestureDetector(
                onTap: () {
                  setState(() => _selectedRating = starIndex);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 200),
                    scale: isFilled ? 1.15 : 0.95,
                    child: Icon(
                      isFilled ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 42,
                      color: isFilled ? AppColors.gold : Colors.white24,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),

          // Rating Sentiment Label
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              _ratingLabel,
              key: ValueKey(_selectedRating),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.goldLight,
              ),
            ),
          ),
          const SizedBox(height: 28),

          // Submit Rating Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: Container(
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _handleSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.rate_review_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      Platform.isIOS ? "Rate on App Store" : "Rate on Google Play",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Direct Store Listing Option
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ReviewService().openStoreListing();
            },
            child: Text(
              Platform.isIOS
                  ? "Open Apple App Store Page"
                  : "Open Google Play Store Page",
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textTertiary,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

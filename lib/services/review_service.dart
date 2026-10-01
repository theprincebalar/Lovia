import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'storage_service.dart';

/// Official In-App Review & Rating Service
/// Triggers Apple StoreKit (SKStoreReviewController) and Google Play In-App Review dialogs
/// Rate limits requests to once per 24 hours after successful purchases
class ReviewService {
  static final ReviewService _instance = ReviewService._internal();
  factory ReviewService() => _instance;
  ReviewService._internal();

  final InAppReview _inAppReview = InAppReview.instance;

  /// Checks if user has completed a purchase AND at least 24 hours have elapsed since the last review prompt.
  /// If both conditions are met, requests the official store rating dialog.
  Future<void> checkAndPromptReviewIfEligible({int delaySeconds = 2}) async {
    try {
      final storage = StorageService();

      // Condition 1: User must have completed at least one purchase
      if (!storage.hasMadeAnyPurchase()) {
        return;
      }

      final lastPromptMillis = storage.getLastReviewPromptTime();
      if (lastPromptMillis != null) {
        final lastPromptDate = DateTime.fromMillisecondsSinceEpoch(lastPromptMillis);
        final elapsed = DateTime.now().difference(lastPromptDate);

        // Condition 2: Check 24-hour rate limit
        if (elapsed.inHours < 24) {
          debugPrint('⭐ Review prompt skipped: Already prompted ${elapsed.inHours}h ago (Limit: 24h)');
          return;
        }
      }

      // Check if official In-App Review dialog is available on this platform/device
      final isAvailable = await _inAppReview.isAvailable();
      if (!isAvailable) {
        debugPrint('⭐ In-App Review API unavailable on this device/environment.');
        return;
      }

      // Brief delay to allow UI transitions to complete
      if (delaySeconds > 0) {
        await Future.delayed(Duration(seconds: delaySeconds));
      }

      // Save prompt timestamp immediately to guarantee 1 prompt per 24h limit
      await storage.setLastReviewPromptTime(DateTime.now().millisecondsSinceEpoch);

      // Trigger official Apple / Google in-app rating prompt
      debugPrint('⭐ Triggering official Apple/Google In-App Review Dialog (24h eligible)...');
      await _inAppReview.requestReview();
    } catch (e) {
      debugPrint('⭐ Error requesting In-App Review: $e');
    }
  }

  /// Requests the official native rating dialog immediately after a successful purchase
  Future<void> requestPostPurchaseReview({int delaySeconds = 1}) async {
    final storage = StorageService();
    await storage.setHasMadeAnyPurchase(true);
    await checkAndPromptReviewIfEligible(delaySeconds: delaySeconds);
  }

  /// Explicit direct rating trigger (e.g. from Rate Us button in Profile)
  Future<void> requestDirectReview() async {
    try {
      final isAvailable = await _inAppReview.isAvailable();
      if (isAvailable) {
        debugPrint('⭐ Triggering direct Apple/Google in-app rating prompt...');
        await _inAppReview.requestReview();
      } else {
        debugPrint('⭐ In-app review unavailable, opening store listing...');
        await openStoreListing();
      }
    } catch (e) {
      debugPrint('⭐ Error during direct review request: $e');
      await openStoreListing();
    }
  }

  /// Manually opens store page if needed
  Future<void> openStoreListing({String? appStoreId}) async {
    try {
      await _inAppReview.openStoreListing(appStoreId: appStoreId);
    } catch (e) {
      debugPrint('⭐ Error opening store listing: $e');
    }
  }
}

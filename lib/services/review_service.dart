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

  /// Requests the official native rating dialog after a successful purchase
  /// Enforces a strict maximum of once per 24 hours
  Future<void> requestPostPurchaseReview({int delaySeconds = 1}) async {
    try {
      final storage = StorageService();
      final lastPromptMillis = storage.getLastReviewPromptTime();

      if (lastPromptMillis != null) {
        final lastPromptDate = DateTime.fromMillisecondsSinceEpoch(lastPromptMillis);
        final elapsed = DateTime.now().difference(lastPromptDate);

        // Check 24-hour rate limit
        if (elapsed.inHours < 24) {
          debugPrint('⭐ Review prompt skipped: Already prompted $elapsed ago (Limit: 24h)');
          return;
        }
      }

      // Check if official In-App Review dialog is available on this platform/device
      final isAvailable = await _inAppReview.isAvailable();
      if (!isAvailable) {
        debugPrint('⭐ In-App Review API unavailable on this device/environment.');
        return;
      }

      // Brief delay to allow the purchase celebration / success snackbar to be seen first
      if (delaySeconds > 0) {
        await Future.delayed(Duration(seconds: delaySeconds));
      }

      // Save prompt timestamp immediately to guarantee 1 prompt per 24h limit
      await storage.setLastReviewPromptTime(DateTime.now().millisecondsSinceEpoch);

      // Trigger official Apple / Google in-app rating prompt
      debugPrint('⭐ Triggering official Apple/Google In-App Review Dialog...');
      await _inAppReview.requestReview();
    } catch (e) {
      debugPrint('⭐ Error requesting In-App Review: $e');
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

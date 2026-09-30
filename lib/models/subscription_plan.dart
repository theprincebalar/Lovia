enum SubscriptionPeriod { weekly, monthly, yearly }

class SubscriptionPlan {
  final String id;
  final String? _productId;
  final String title;
  final SubscriptionPeriod period;
  final double priceUsd;
  final int voiceMinutes;
  final String description;
  final String badge;
  final bool isPopular;
  final bool isBestValue;

  const SubscriptionPlan({
    required this.id,
    String? productId,
    required this.title,
    required this.period,
    required this.priceUsd,
    required this.voiceMinutes,
    required this.description,
    this.badge = '',
    this.isPopular = false,
    this.isBestValue = false,
  }) : _productId = productId;

  String get productId => _productId ?? id;

  /// Duration of the subscription cycle
  Duration get duration {
    switch (period) {
      case SubscriptionPeriod.weekly:
        return const Duration(days: 7);
      case SubscriptionPeriod.monthly:
        return const Duration(days: 30);
      case SubscriptionPeriod.yearly:
        return const Duration(days: 365);
    }
  }

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    SubscriptionPeriod parsedPeriod;
    final periodStr = (json['period'] as String? ?? 'monthly').toLowerCase();
    if (periodStr.contains('week')) {
      parsedPeriod = SubscriptionPeriod.weekly;
    } else if (periodStr.contains('year') || periodStr.contains('annual')) {
      parsedPeriod = SubscriptionPeriod.yearly;
    } else {
      parsedPeriod = SubscriptionPeriod.monthly;
    }

    return SubscriptionPlan(
      id: json['id'] as String? ?? 'sub_${DateTime.now().millisecondsSinceEpoch}',
      productId: json['productId'] as String?,
      title: json['title'] as String? ?? 'VIP Plan',
      period: parsedPeriod,
      priceUsd: (json['priceUsd'] as num?)?.toDouble() ?? 12.99,
      voiceMinutes: (json['voiceMinutes'] as num?)?.toInt() ?? 50,
      description: json['description'] as String? ?? 'Voice talk included',
      badge: json['badge'] as String? ?? '',
      isPopular: json['isPopular'] as bool? ?? false,
      isBestValue: json['isBestValue'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'productId': productId,
    'title': title,
    'period': period.name,
    'priceUsd': priceUsd,
    'voiceMinutes': voiceMinutes,
    'description': description,
    'badge': badge,
    'isPopular': isPopular,
    'isBestValue': isBestValue,
  };

  static const List<SubscriptionPlan> plans = [
    SubscriptionPlan(
      id: "sub_weekly",
      productId: "lovia_vip_weekly",
      title: "Weekly VIP",
      period: SubscriptionPeriod.weekly,
      priceUsd: 4.99,
      voiceMinutes: 10,
      description: "10 minutes voice talk included",
      badge: "Weekly",
    ),
    SubscriptionPlan(
      id: "sub_monthly",
      productId: "lovia_vip_monthly",
      title: "Monthly VIP",
      period: SubscriptionPeriod.monthly,
      priceUsd: 12.99,
      voiceMinutes: 50,
      description: "50 minutes voice talk included",
      isPopular: true,
      badge: "MOST POPULAR",
    ),
    SubscriptionPlan(
      id: "sub_yearly",
      productId: "lovia_vip_yearly",
      title: "Yearly VIP",
      period: SubscriptionPeriod.yearly,
      priceUsd: 79.99,
      voiceMinutes: 720, // 12 hours = 720 minutes
      description: "12 hours (720 min) voice talk included",
      isBestValue: true,
      badge: "BEST VALUE",
    ),
  ];
}

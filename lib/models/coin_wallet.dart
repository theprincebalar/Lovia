class CoinPackage {
  final String id;
  final String? _productId;
  final String title;
  final int coins;
  final int bonusCoins;
  final double priceUsd;
  final bool isPopular;
  final bool isBestValue;
  final String badge;

  const CoinPackage({
    required this.id,
    String? productId,
    required this.title,
    required this.coins,
    required this.bonusCoins,
    required this.priceUsd,
    this.isPopular = false,
    this.isBestValue = false,
    this.badge = '',
  }) : _productId = productId;

  int get totalCoins => coins + bonusCoins;
  int get diamonds => coins;
  int get bonusDiamonds => bonusCoins;
  int get totalDiamonds => totalCoins;
  String get diamondTitle => title.replaceAll("Coins", "Diamonds");
  String get productId => _productId ?? 'lovia_diamonds_$totalCoins';

  factory CoinPackage.fromJson(Map<String, dynamic> json) {
    return CoinPackage(
      id: json['id'] as String? ?? 'pkg_${DateTime.now().millisecondsSinceEpoch}',
      productId: json['productId'] as String?,
      title: json['title'] as String? ?? 'Diamonds',
      coins: (json['coins'] as num?)?.toInt() ?? 20,
      bonusCoins: (json['bonusCoins'] as num?)?.toInt() ?? 0,
      priceUsd: (json['priceUsd'] as num?)?.toDouble() ?? 0.99,
      isPopular: json['isPopular'] as bool? ?? false,
      isBestValue: json['isBestValue'] as bool? ?? false,
      badge: json['badge'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'productId': productId,
    'title': title,
    'coins': coins,
    'bonusCoins': bonusCoins,
    'priceUsd': priceUsd,
    'isPopular': isPopular,
    'isBestValue': isBestValue,
    'badge': badge,
  };

  static const List<CoinPackage> standardPackages = [
    CoinPackage(
      id: "pkg_20",
      productId: "lovia_diamonds_20",
      title: "Handful of Coins",
      coins: 20,
      bonusCoins: 0,
      priceUsd: 1.00,
      badge: "STARTER",
    ),
    CoinPackage(
      id: "pkg_50",
      productId: "lovia_diamonds_50",
      title: "Pouch of Coins",
      coins: 50,
      bonusCoins: 0,
      priceUsd: 2.00,
      badge: "POPULAR",
    ),
    CoinPackage(
      id: "pkg_130",
      productId: "lovia_diamonds_130",
      title: "Chest of Coins",
      coins: 130,
      bonusCoins: 0,
      priceUsd: 5.00,
      isPopular: true,
      badge: "MOST POPULAR",
    ),
    CoinPackage(
      id: "pkg_300",
      productId: "lovia_diamonds_300",
      title: "Vault of Coins",
      coins: 300,
      bonusCoins: 0,
      priceUsd: 10.00,
      badge: "+50% BONUS",
    ),
    CoinPackage(
      id: "pkg_650",
      productId: "lovia_diamonds_650",
      title: "Treasury of Coins",
      coins: 650,
      bonusCoins: 0,
      priceUsd: 20.00,
      badge: "+62% BONUS",
    ),
    CoinPackage(
      id: "pkg_1700",
      productId: "lovia_diamonds_1700",
      title: "Royal Emperor Treasury",
      coins: 1700,
      bonusCoins: 0,
      priceUsd: 50.00,
      isBestValue: true,
      badge: "BEST VALUE",
    ),
  ];
}

class CoinTransaction {
  final String id;
  final String description;
  final int amount; // positive for credit, negative for debit
  final DateTime timestamp;

  const CoinTransaction({
    required this.id,
    required this.description,
    required this.amount,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'description': description,
    'amount': amount,
    'timestamp': timestamp.toIso8601String(),
  };

  factory CoinTransaction.fromJson(Map<String, dynamic> json) => CoinTransaction(
    id: json['id'] as String,
    description: json['description'] as String,
    amount: json['amount'] as int,
    timestamp: DateTime.parse(json['timestamp'] as String),
  );
}

typedef DiamondPackage = CoinPackage;
typedef DiamondTransaction = CoinTransaction;


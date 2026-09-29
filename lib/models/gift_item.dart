import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum GiftRarity {
  common,
  rare,
  epic,
  legendary,
  divine;

  String get displayName {
    switch (this) {
      case GiftRarity.common:
        return "Common";
      case GiftRarity.rare:
        return "Rare";
      case GiftRarity.epic:
        return "Epic";
      case GiftRarity.legendary:
        return "Legendary";
      case GiftRarity.divine:
        return "Divine";
    }
  }

  Color get color {
    switch (this) {
      case GiftRarity.common:
        return const Color(0xFF8A94B8);
      case GiftRarity.rare:
        return AppColors.tertiary;
      case GiftRarity.epic:
        return AppColors.secondary;
      case GiftRarity.legendary:
        return AppColors.primary;
      case GiftRarity.divine:
        return AppColors.gold;
    }
  }
}

class GiftItem {
  final String id;
  final String name;
  final String emoji;
  final int coinPrice;
  final int affectionPoints;
  final String description;
  final GiftRarity rarity;

  const GiftItem({
    required this.id,
    required this.name,
    required this.emoji,
    required this.coinPrice,
    required this.affectionPoints,
    required this.description,
    required this.rarity,
  });

  Color get rarityColor => rarity.color;
  int get diamondPrice => coinPrice;

  static const List<GiftItem> allGifts = [
    GiftItem(
      id: "gift_rose",
      name: "Red Rose",
      emoji: "🌹",
      coinPrice: 5,
      affectionPoints: 25,
      description: "A fresh, fragrant red rose symbolizing sweet affection.",
      rarity: GiftRarity.common,
    ),
    GiftItem(
      id: "gift_chocolate",
      name: "Artisan Chocolates",
      emoji: "🍫",
      coinPrice: 10,
      affectionPoints: 60,
      description: "A gourmet box of handmade heart-shaped truffles.",
      rarity: GiftRarity.rare,
    ),
    GiftItem(
      id: "gift_plushie",
      name: "Cute Plushie",
      emoji: "🧸",
      coinPrice: 25,
      affectionPoints: 160,
      description: "An adorably soft companion plush to cuddle with all night.",
      rarity: GiftRarity.epic,
    ),
    GiftItem(
      id: "gift_perfume",
      name: "Luxury Perfume",
      emoji: "🌸",
      coinPrice: 50,
      affectionPoints: 350,
      description: "An enchanting, intoxicating floral fragrance in crystal glass.",
      rarity: GiftRarity.legendary,
    ),
    GiftItem(
      id: "gift_diamond_ring",
      name: "Diamond Ring",
      emoji: "💍",
      coinPrice: 100,
      affectionPoints: 800,
      description: "A sparkling commitment of profound devotion and pure romance.",
      rarity: GiftRarity.divine,
    ),
  ];

  static GiftItem getById(String id) {
    return allGifts.firstWhere(
      (g) => g.id == id,
      orElse: () => allGifts.first,
    );
  }
}

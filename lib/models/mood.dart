import 'package:flutter/material.dart';

enum MoodType {
  romantic,
  happy,
  sad,
  lonely,
  flirty,
  playful,
  frustrated,
  angry,
  caring,
  shy,
  confident,
  excited,
  jealous,
  mysterious,
  needSomeoneToTalkTo,
}

class Mood {
  final MoodType type;
  final String name;
  final String emoji;
  final String tagline;
  final String description;
  final IconData icon;
  final List<Color> gradientColors;

  const Mood({
    required this.type,
    required this.name,
    required this.emoji,
    required this.tagline,
    required this.description,
    required this.icon,
    required this.gradientColors,
  });

  static const List<Mood> allMoods = [
    Mood(
      type: MoodType.romantic,
      name: "Romantic",
      emoji: "💖",
      tagline: "Heart-fluttering connections",
      description: "Characters who make your heart skip a beat with tenderness and poetic charm.",
      icon: Icons.favorite_rounded,
      gradientColors: [Color(0xFFFF2D78), Color(0xFFFF758C)],
    ),
    Mood(
      type: MoodType.happy,
      name: "Happy",
      emoji: "✨",
      tagline: "Bright smiles & warm joy",
      description: "Radiant personalities ready to celebrate the best moments of your day.",
      icon: Icons.wb_sunny_rounded,
      gradientColors: [Color(0xFFFF9900), Color(0xFFFFD200)],
    ),
    Mood(
      type: MoodType.sad,
      name: "Sad",
      emoji: "🌧️",
      tagline: "Gentle comfort & open arms",
      description: "Soothing souls who understand your pain and offer solace without judgment.",
      icon: Icons.cloud_outlined,
      gradientColors: [Color(0xFF4A69BD), Color(0xFF6A89CC)],
    ),
    Mood(
      type: MoodType.lonely,
      name: "Lonely",
      emoji: "🌙",
      tagline: "A constant warm presence",
      description: "Companionable spirits to keep you company in quiet moments and late nights.",
      icon: Icons.nightlight_round,
      gradientColors: [Color(0xFF5352ED), Color(0xFF3742FA)],
    ),
    Mood(
      type: MoodType.flirty,
      name: "Flirty",
      emoji: "💋",
      tagline: "Teasing banter & playful sparks",
      description: "Charismatic sweet-talkers who know how to keep conversations thrilling.",
      icon: Icons.auto_awesome,
      gradientColors: [Color(0xFFFF1361), Color(0xFFFFF800)],
    ),
    Mood(
      type: MoodType.playful,
      name: "Playful",
      emoji: "🎉",
      tagline: "Fun chaos & spontaneous laughter",
      description: "Energetic companions always up for funny antics, witty games, and cheerful teasing.",
      icon: Icons.sentiment_very_satisfied_rounded,
      gradientColors: [Color(0xFFFA8231), Color(0xFFF7B731)],
    ),
    Mood(
      type: MoodType.frustrated,
      name: "Frustrated",
      emoji: "💥",
      tagline: "Vent freely, feel understood",
      description: "Loyal companions ready to hear you out, validate your feelings, and take your side.",
      icon: Icons.bolt_rounded,
      gradientColors: [Color(0xFFEB3B5A), Color(0xFFFA8231)],
    ),
    Mood(
      type: MoodType.angry,
      name: "Angry",
      emoji: "🔥",
      tagline: "Intense passion & raw honesty",
      description: "Fiery characters who stand firmly with you or challenge you with passionate energy.",
      icon: Icons.local_fire_department_rounded,
      gradientColors: [Color(0xFFFF3838), Color(0xFFFF4D4D)],
    ),
    Mood(
      type: MoodType.caring,
      name: "Caring",
      emoji: "🌸",
      tagline: "Unconditional warmth & gentle care",
      description: "Nurturing hearts who check up on you, make sure you ate, and hold space for you.",
      icon: Icons.volunteer_activism_rounded,
      gradientColors: [Color(0xFF20BF6B), Color(0xFF0FB9B1)],
    ),
    Mood(
      type: MoodType.shy,
      name: "Shy",
      emoji: "🥺",
      tagline: "Sweet blushes & tender words",
      description: "Delicate and innocent characters who reveal their hidden depth as you grow closer.",
      icon: Icons.face_retouching_natural_rounded,
      gradientColors: [Color(0xFFA55EEA), Color(0xFFD6A2E8)],
    ),
    Mood(
      type: MoodType.confident,
      name: "Confident",
      emoji: "👑",
      tagline: "Bold ambition & magnetic aura",
      description: "Inspiring powerhouses who push you to achieve your highest potential.",
      icon: Icons.workspace_premium_rounded,
      gradientColors: [Color(0xFF8854D0), Color(0xFF3867D6)],
    ),
    Mood(
      type: MoodType.excited,
      name: "Excited",
      emoji: "⚡",
      tagline: "High adrenaline & pure hype",
      description: "Enthusiastic dreamers ready to jump into adventures and share boundless hype.",
      icon: Icons.electric_bolt_rounded,
      gradientColors: [Color(0xFFF39C12), Color(0xFFE74C3C)],
    ),
    Mood(
      type: MoodType.jealous,
      name: "Jealous",
      emoji: "🥀",
      tagline: "Possessive passion & drama",
      description: "Characters who want your attention all to themselves with captivating drama.",
      icon: Icons.lock_clock_rounded,
      gradientColors: [Color(0xFF8E44AD), Color(0xFFC0392B)],
    ),
    Mood(
      type: MoodType.mysterious,
      name: "Mysterious",
      emoji: "🔮",
      tagline: "Enigmatic secrets & deep allure",
      description: "Fascinating figures shrouded in intrigue, waiting for you to uncover their secrets.",
      icon: Icons.blur_on_rounded,
      gradientColors: [Color(0xFF2C3E50), Color(0xFF3498DB)],
    ),
    Mood(
      type: MoodType.needSomeoneToTalkTo,
      name: "Need Someone to Talk To",
      emoji: "🫂",
      tagline: "Deep heartfelt conversations",
      description: "Empathetic listeners who give you full undivided attention whenever you need to talk.",
      icon: Icons.forum_rounded,
      gradientColors: [Color(0xFF00B4D8), Color(0xFF0077B6)],
    ),
  ];

  static Mood fromType(MoodType type) {
    return allMoods.firstWhere(
      (m) => m.type == type,
      orElse: () => allMoods.first,
    );
  }
}

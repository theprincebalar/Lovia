import 'package:flutter/material.dart';

enum EmotionState {
  happy,
  sad,
  romantic,
  angry,
  shy,
  playful,
  surprised,
  thinking,
  laughing,
  emotional,
  excited;

  String get id => name;

  String get displayName {
    switch (this) {
      case EmotionState.happy:
        return "Happy";
      case EmotionState.sad:
        return "Melancholic";
      case EmotionState.romantic:
        return "Romantic";
      case EmotionState.angry:
        return "Passionate";
      case EmotionState.shy:
        return "Bashful";
      case EmotionState.playful:
        return "Playful";
      case EmotionState.surprised:
        return "Surprised";
      case EmotionState.thinking:
        return "Contemplative";
      case EmotionState.laughing:
        return "Laughing";
      case EmotionState.emotional:
        return "Touched";
      case EmotionState.excited:
        return "Excited";
    }
  }

  String get emoji {
    switch (this) {
      case EmotionState.happy:
        return "😊";
      case EmotionState.sad:
        return "🥺";
      case EmotionState.romantic:
        return "💖";
      case EmotionState.angry:
        return "😠";
      case EmotionState.shy:
        return "😳";
      case EmotionState.playful:
        return "😜";
      case EmotionState.surprised:
        return "😲";
      case EmotionState.thinking:
        return "🤔";
      case EmotionState.laughing:
        return "😂";
      case EmotionState.emotional:
        return "🥹";
      case EmotionState.excited:
        return "🤩";
    }
  }

  Color get accentColor {
    switch (this) {
      case EmotionState.happy:
        return const Color(0xFFFFC107);
      case EmotionState.sad:
        return const Color(0xFF64B5F6);
      case EmotionState.romantic:
        return const Color(0xFFFF4081);
      case EmotionState.angry:
        return const Color(0xFFFF5252);
      case EmotionState.shy:
        return const Color(0xFFE040FB);
      case EmotionState.playful:
        return const Color(0xFFFF9100);
      case EmotionState.surprised:
        return const Color(0xFF69F0AE);
      case EmotionState.thinking:
        return const Color(0xFF7C4DFF);
      case EmotionState.laughing:
        return const Color(0xFFFFD740);
      case EmotionState.emotional:
        return const Color(0xFF40C4FF);
      case EmotionState.excited:
        return const Color(0xFFFF6D00);
    }
  }

  /// Voice pitch multiplier for speech synthesis
  double get pitchMultiplier {
    switch (this) {
      case EmotionState.happy:
        return 1.1;
      case EmotionState.sad:
        return 0.85;
      case EmotionState.romantic:
        return 0.95;
      case EmotionState.angry:
        return 0.9;
      case EmotionState.shy:
        return 1.05;
      case EmotionState.playful:
        return 1.15;
      case EmotionState.surprised:
        return 1.25;
      case EmotionState.thinking:
        return 0.95;
      case EmotionState.laughing:
        return 1.2;
      case EmotionState.emotional:
        return 0.9;
      case EmotionState.excited:
        return 1.25;
    }
  }

  /// Voice speech rate multiplier
  double get speechRateMultiplier {
    switch (this) {
      case EmotionState.happy:
        return 1.05;
      case EmotionState.sad:
        return 0.8;
      case EmotionState.romantic:
        return 0.88;
      case EmotionState.angry:
        return 1.15;
      case EmotionState.shy:
        return 0.85;
      case EmotionState.playful:
        return 1.12;
      case EmotionState.surprised:
        return 1.2;
      case EmotionState.thinking:
        return 0.82;
      case EmotionState.laughing:
        return 1.1;
      case EmotionState.emotional:
        return 0.85;
      case EmotionState.excited:
        return 1.2;
    }
  }

  static EmotionState fromString(String str) {
    return EmotionState.values.firstWhere(
      (e) => e.name.toLowerCase() == str.toLowerCase(),
      orElse: () => EmotionState.happy,
    );
  }
}

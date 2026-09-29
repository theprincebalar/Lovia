import 'package:flutter/material.dart';

enum RelationshipLevel {
  stranger,
  friend,
  closeFriend,
  crush,
  partner;

  String get displayName {
    switch (this) {
      case RelationshipLevel.stranger:
        return "Stranger";
      case RelationshipLevel.friend:
        return "Friend";
      case RelationshipLevel.closeFriend:
        return "Close Friend";
      case RelationshipLevel.crush:
        return "Crush";
      case RelationshipLevel.partner:
        return "Partner";
    }
  }

  Color get color {
    switch (this) {
      case RelationshipLevel.stranger:
        return const Color(0xFF8A94B8);
      case RelationshipLevel.friend:
        return const Color(0xFF00D2FF);
      case RelationshipLevel.closeFriend:
        return const Color(0xFF8A3FFC);
      case RelationshipLevel.crush:
        return const Color(0xFFFF66A1);
      case RelationshipLevel.partner:
        return const Color(0xFFFF2D78);
    }
  }

  IconData get icon {
    switch (this) {
      case RelationshipLevel.stranger:
        return Icons.person_outline_rounded;
      case RelationshipLevel.friend:
        return Icons.handshake_rounded;
      case RelationshipLevel.closeFriend:
        return Icons.favorite_border_rounded;
      case RelationshipLevel.crush:
        return Icons.favorite_rounded;
      case RelationshipLevel.partner:
        return Icons.auto_awesome_rounded;
    }
  }

  int get maxAffectionPoints {
    switch (this) {
      case RelationshipLevel.stranger:
        return 50;
      case RelationshipLevel.friend:
        return 150;
      case RelationshipLevel.closeFriend:
        return 350;
      case RelationshipLevel.crush:
        return 650;
      case RelationshipLevel.partner:
        return 1000;
    }
  }
}

class MemoryItem {
  final String id;
  final String title;
  final String summary;
  final String emotion;
  final DateTime createdAt;
  final String characterId;

  const MemoryItem({
    required this.id,
    required this.title,
    required this.summary,
    required this.emotion,
    required this.createdAt,
    required this.characterId,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'summary': summary,
    'emotion': emotion,
    'createdAt': createdAt.toIso8601String(),
    'characterId': characterId,
  };

  factory MemoryItem.fromJson(Map<String, dynamic> json) => MemoryItem(
    id: json['id'] as String,
    title: json['title'] as String,
    summary: json['summary'] as String,
    emotion: json['emotion'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    characterId: json['characterId'] as String,
  );
}

class CharacterRelationship {
  final String characterId;
  int affectionPoints;
  RelationshipLevel level;
  List<MemoryItem> memories;

  CharacterRelationship({
    required this.characterId,
    this.affectionPoints = 0,
    this.level = RelationshipLevel.stranger,
    List<MemoryItem>? memories,
  }) : memories = memories ?? [];

  bool addAffection(int points) {
    final oldLevel = level;
    affectionPoints += points;
    _updateLevel();
    return level.index > oldLevel.index;
  }

  bool addGift(dynamic gift) {
    // Accepts GiftItem or any object with affectionPoints
    final points = (gift.affectionPoints as num).toInt();
    return addAffection(points);
  }

  void _updateLevel() {
    if (affectionPoints >= RelationshipLevel.crush.maxAffectionPoints) {
      level = RelationshipLevel.partner;
    } else if (affectionPoints >= RelationshipLevel.closeFriend.maxAffectionPoints) {
      level = RelationshipLevel.crush;
    } else if (affectionPoints >= RelationshipLevel.friend.maxAffectionPoints) {
      level = RelationshipLevel.closeFriend;
    } else if (affectionPoints >= RelationshipLevel.stranger.maxAffectionPoints) {
      level = RelationshipLevel.friend;
    } else {
      level = RelationshipLevel.stranger;
    }
  }

  double get levelProgress {
    int currentFloor = 0;
    int nextCeiling = level.maxAffectionPoints;

    switch (level) {
      case RelationshipLevel.stranger:
        currentFloor = 0;
        nextCeiling = 50;
        break;
      case RelationshipLevel.friend:
        currentFloor = 50;
        nextCeiling = 150;
        break;
      case RelationshipLevel.closeFriend:
        currentFloor = 150;
        nextCeiling = 350;
        break;
      case RelationshipLevel.crush:
        currentFloor = 350;
        nextCeiling = 650;
        break;
      case RelationshipLevel.partner:
        currentFloor = 650;
        nextCeiling = 1000;
        break;
    }

    if (affectionPoints >= nextCeiling) return 1.0;
    final progress = (affectionPoints - currentFloor) / (nextCeiling - currentFloor);
    return progress.clamp(0.0, 1.0);
  }
}

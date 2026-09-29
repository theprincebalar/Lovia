import 'package:flutter/material.dart';

enum ScenarioType {
  firstMeeting,
  firstDate,
  lateNightChat,
  bestFriends,
  roommates,
  secretCrush,
  vacation,
  adventure,
  mystery,
  argument,
  reunion,
}

class Scenario {
  final ScenarioType type;
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final String backgroundPrompt;

  const Scenario({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.backgroundPrompt,
  });

  static const List<Scenario> allScenarios = [
    Scenario(
      type: ScenarioType.firstMeeting,
      title: "First Meeting",
      subtitle: "A serendipitous encounter",
      description: "You cross paths by chance in a cozy rain-sheltered café. Eyes meet, and curiosity sparks.",
      icon: Icons.coffee_rounded,
      backgroundPrompt: "Cozy quiet café during a gentle rain, warm ambient lighting.",
    ),
    Scenario(
      type: ScenarioType.firstDate,
      title: "First Date",
      subtitle: "Excited butterflies & starlit smiles",
      description: "An evening rooftop dinner overlooking the sparkling city lights, discovering each other's secrets.",
      icon: Icons.local_bar_rounded,
      backgroundPrompt: "A breathtaking rooftop patio under evening stars with candlelight.",
    ),
    Scenario(
      type: ScenarioType.lateNightChat,
      title: "Late Night Chat",
      subtitle: "Whispers in the dark",
      description: "When the world is asleep at 2:00 AM, you share raw truths, heartfelt laughter, and cozy vulnerability.",
      icon: Icons.bedtime_rounded,
      backgroundPrompt: "Quiet midnight room, soft moonlight pouring through curtains.",
    ),
    Scenario(
      type: ScenarioType.bestFriends,
      title: "Best Friends",
      subtitle: "Unbreakable bond & playful banter",
      description: "Years of shared memories, inside jokes, and unspoken understanding where you can truly be yourself.",
      icon: Icons.people_alt_rounded,
      backgroundPrompt: "Sunny loft filled with pillows, vintage vinyl records, and laughter.",
    ),
    Scenario(
      type: ScenarioType.roommates,
      title: "Roommates",
      subtitle: "Sharing walls and stolen glances",
      description: "Living together under one roof. Late-night fridge raids, accidental collisions, and growing tension.",
      icon: Icons.apartment_rounded,
      backgroundPrompt: "Shared modern downtown apartment with cozy kitchen counter.",
    ),
    Scenario(
      type: ScenarioType.secretCrush,
      title: "Secret Crush",
      subtitle: "Unspoken longing & nervous flutters",
      description: "You have both harbored hidden feelings for months. Today, a subtle slip of the tongue might change everything.",
      icon: Icons.favorite_border_rounded,
      backgroundPrompt: "Quiet university library corner behind secluded wooden bookshelves.",
    ),
    Scenario(
      type: ScenarioType.vacation,
      title: "Vacation",
      subtitle: "Sun-kissed breezes & seaside escape",
      description: "A private getaway on a tropical coastline, wandering the beach barefoot as waves lap at your feet.",
      icon: Icons.beach_access_rounded,
      backgroundPrompt: "Sunset beach with golden waves and warm ocean breeze.",
    ),
    Scenario(
      type: ScenarioType.adventure,
      title: "Adventure",
      subtitle: "Thrill of the unknown",
      description: "Embarking on a daring expedition into forgotten ancient ruins and discovering breathtaking wonders.",
      icon: Icons.explore_rounded,
      backgroundPrompt: "Mystic ancient temple overgrown with glowing bioluminescent vines.",
    ),
    Scenario(
      type: ScenarioType.mystery,
      title: "Mystery",
      subtitle: "Intrigue, shadows & hidden truth",
      description: "You team up to investigate an enigmatic puzzle under the foggy neon-lit streets of midnight city.",
      icon: Icons.search_rounded,
      backgroundPrompt: "Neon cyberpunk alley shrouded in mist and dramatic neon reflections.",
    ),
    Scenario(
      type: ScenarioType.argument,
      title: "Argument",
      subtitle: "Sparks fly & passions collide",
      description: "A sudden misunderstanding boils over into fierce emotional confrontation and breathless honesty.",
      icon: Icons.flash_on_rounded,
      backgroundPrompt: "Dramatic storm outside the window as heated words echo between you.",
    ),
    Scenario(
      type: ScenarioType.reunion,
      title: "Reunion",
      subtitle: "Reconnecting after years apart",
      description: "After years of silence, you unexpectedly run into each other at a bustling train terminal. Can time heal?",
      icon: Icons.sync_alt_rounded,
      backgroundPrompt: "Grand sunlit train station bustling with travelers.",
    ),
  ];
}

import 'package:flutter/material.dart';
import '../models/character.dart';
import '../models/emotion_state.dart';
import 'app_cached_image.dart';

enum AvatarSize {
  small(38),
  chatList(54),
  medium(90),
  large(160),
  hero(280),
  fullscreen(400);

  final double dimension;
  const AvatarSize(this.dimension);
}

class CharacterAvatar extends StatelessWidget {
  final Character character;
  final EmotionState emotion;
  final AvatarSize size;
  final bool showAuraGlow;
  final bool isInteractive;
  final VoidCallback? onTap;

  const CharacterAvatar({
    super.key,
    required this.character,
    this.emotion = EmotionState.happy,
    this.size = AvatarSize.medium,
    this.showAuraGlow = true,
    this.isInteractive = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    String avatarPath;
    if (character.customAvatarPath != null && character.customAvatarPath!.isNotEmpty) {
      avatarPath = character.customAvatarPath!;
    } else {
      avatarPath = character.getServerSpriteUrl(emotion);
    }
    final accentColor = emotion.accentColor;

    Widget avatarWidget = SizedBox(
      width: size.dimension,
      height: size.dimension,
      child: AspectRatio(
        aspectRatio: 1.0,
        child: Stack(
          alignment: Alignment.center,
          children: [
          // 1. Soft Dynamic Aura Glow
          if (showAuraGlow)
            Container(
              width: size.dimension * 0.85,
              height: size.dimension * 0.85,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    accentColor.withOpacity(0.35),
                    accentColor.withOpacity(0.12),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),

          // 2. High-Definition Character Sprite (Clipped in a perfect rounded circle)
          Container(
            width: size.dimension,
            height: size.dimension,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: accentColor.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: ClipOval(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.96, end: 1.0).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: AppCachedImage(
                  key: ValueKey<String>('${character.id}_${emotion.name}'),
                  imagePath: avatarPath,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  width: size.dimension,
                  height: size.dimension,
                  errorBuilder: (ctx, err, stack) => _buildFallbackMonogram(accentColor),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

    if (onTap != null) {
      avatarWidget = GestureDetector(
        onTap: onTap,
        child: avatarWidget,
      );
    }

    return avatarWidget;
  }

  Widget _buildFallbackMonogram(Color accentColor) {
    return Container(
      width: size.dimension,
      height: size.dimension,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [accentColor.withOpacity(0.4), Colors.black54],
        ),
      ),
      child: Center(
        child: Text(
          character.name.substring(0, 1),
          style: TextStyle(
            fontSize: size.dimension * 0.35,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

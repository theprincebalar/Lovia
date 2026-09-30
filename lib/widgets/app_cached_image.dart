import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/character.dart';
import '../models/emotion_state.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';

/// Sandboxed cached image loader (Solution 1: Anti-Reverse Engineering & Resilient Caching).
///
/// Automatically routes:
/// 1. Remote HTTP/HTTPS -> [CachedNetworkImage] with automatic fallback to [Image.network] if sqflite is unavailable.
/// 2. Device Local Files -> [Image.file] for user-selected photos from camera/gallery.
/// 3. App Assets -> Automatically redirects any 'assets/characters/' to the VPS CDN; falls back to [Image.asset] for local UI icons.
class AppCachedImage extends StatelessWidget {
  static bool _fallbackToStandardNetwork = false;

  final String imagePath;
  final BoxFit fit;
  final Alignment alignment;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;

  const AppCachedImage({
    super.key,
    required this.imagePath,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.width,
    this.height,
    this.borderRadius,
    this.placeholder,
    this.errorBuilder,
  });

  /// Factory constructor for Character Cover art (routes to VPS server CDN or custom user upload)
  factory AppCachedImage.characterCover({
    Key? key,
    required Character character,
    BoxFit fit = BoxFit.cover,
    Alignment alignment = Alignment.topCenter,
    double? width,
    double? height,
    BorderRadius? borderRadius,
    Widget? placeholder,
    Widget Function(BuildContext, Object, StackTrace?)? errorBuilder,
  }) {
    String resolvedPath;
    if (character.customAvatarPath != null && character.customAvatarPath!.isNotEmpty) {
      resolvedPath = character.customAvatarPath!;
    } else {
      resolvedPath = character.serverCoverUrl;
    }

    return AppCachedImage(
      key: key ?? ValueKey('cover_${character.id}'),
      imagePath: resolvedPath,
      fit: fit,
      alignment: alignment,
      width: width,
      height: height,
      borderRadius: borderRadius,
      placeholder: placeholder,
      errorBuilder: errorBuilder,
    );
  }

  /// Factory constructor for Character Emotion Sprites
  factory AppCachedImage.characterSprite({
    Key? key,
    required Character character,
    required EmotionState emotion,
    BoxFit fit = BoxFit.cover,
    Alignment alignment = Alignment.center,
    double? width,
    double? height,
    BorderRadius? borderRadius,
    Widget? placeholder,
    Widget Function(BuildContext, Object, StackTrace?)? errorBuilder,
  }) {
    String resolvedPath;
    if (character.customAvatarPath != null && character.customAvatarPath!.isNotEmpty) {
      resolvedPath = character.customAvatarPath!;
    } else {
      resolvedPath = character.getServerSpriteUrl(emotion);
    }

    return AppCachedImage(
      key: key ?? ValueKey('sprite_${character.id}_${emotion.name}'),
      imagePath: resolvedPath,
      fit: fit,
      alignment: alignment,
      width: width,
      height: height,
      borderRadius: borderRadius,
      placeholder: placeholder,
      errorBuilder: errorBuilder,
    );
  }

  /// Safe ImageProvider for precaching or DecorationImage without native plugin failure risks
  static ImageProvider provider(String path) {
    String resolved = path.trim();
    if (resolved.startsWith('assets/characters/')) {
      resolved = '${ApiService().baseUrl}/$resolved';
      if (!resolved.contains('?')) resolved += '?v=20260930_clean';
    }
    if (resolved.startsWith('http://') || resolved.startsWith('https://')) {
      return NetworkImage(resolved);
    }
    if (resolved.startsWith('/') || resolved.contains(':\\') || resolved.contains(':/')) {
      return FileImage(File(resolved));
    }
    return AssetImage(resolved);
  }

  @override
  Widget build(BuildContext context) {
    Widget content;
    String path = imagePath.trim();

    // Auto-redirect any legacy asset references to remote CDN
    if (path.startsWith('assets/characters/')) {
      path = '${ApiService().baseUrl}/$path';
      if (!path.contains('?')) path += '?v=20260930_clean';
    }

    if (path.isEmpty) {
      content = _buildDefaultFallback(context);
    } else if (path.startsWith('http://') || path.startsWith('https://')) {
      if (_fallbackToStandardNetwork) {
        content = _buildNetworkImage(context, path);
      } else {
        content = CachedNetworkImage(
          imageUrl: path,
          fit: fit,
          alignment: alignment,
          width: width,
          height: height,
          fadeInDuration: const Duration(milliseconds: 150),
          placeholder: (ctx, url) => placeholder ?? _buildShimmerPlaceholder(),
          errorWidget: (ctx, url, err) {
            // If CachedNetworkImage encounters MissingPluginException or sqflite issue,
            // immediately flip to standard Image.network which never fails on native channels.
            _fallbackToStandardNetwork = true;
            return _buildNetworkImage(ctx, url);
          },
        );
      }
    } else if (_isLocalFilePath(path)) {
      final file = File(path);
      content = Image.file(
        file,
        fit: fit,
        alignment: alignment,
        width: width,
        height: height,
        errorBuilder: (ctx, err, stack) {
          if (errorBuilder != null) {
            return errorBuilder!(ctx, err, stack);
          }
          return _buildDefaultFallback(context);
        },
      );
    } else {
      // Asset fallback
      content = Image.asset(
        path,
        fit: fit,
        alignment: alignment,
        width: width,
        height: height,
        errorBuilder: (ctx, err, stack) {
          if (errorBuilder != null) {
            return errorBuilder!(ctx, err, stack);
          }
          return _buildDefaultFallback(context);
        },
      );
    }

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: content,
      );
    }

    return content;
  }

  Widget _buildNetworkImage(BuildContext context, String url) {
    return Image.network(
      url,
      fit: fit,
      alignment: alignment,
      width: width,
      height: height,
      gaplessPlayback: true,
      loadingBuilder: (ctx, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return placeholder ?? _buildShimmerPlaceholder();
      },
      errorBuilder: (ctx, err, stack) {
        if (errorBuilder != null) {
          return errorBuilder!(ctx, err, stack);
        }
        return _buildDefaultFallback(context);
      },
    );
  }

  bool _isLocalFilePath(String path) {
    if (path.startsWith('/') || path.contains(':\\') || path.contains(':/')) {
      return true;
    }
    try {
      final file = File(path);
      return file.existsSync();
    } catch (_) {
      return false;
    }
  }

  Widget _buildShimmerPlaceholder() {
    return Container(
      width: width,
      height: height,
      color: const Color(0xFF161826),
      child: Center(
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary.withOpacity(0.15),
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultFallback(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: AppColors.surfaceLight,
      child: const Center(
        child: Icon(Icons.person, color: Colors.white38, size: 28),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:twain/models/twain_user.dart';

class TwainAvatar extends StatelessWidget {
  final TwainUser user;
  final double size;
  final Color? color;
  final bool showInitials;
  final bool showBorder;

  const TwainAvatar({
    super.key,
    required this.user,
    this.size = 60,
    this.color,
    this.showInitials = true,
    this.showBorder = true,
  });

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = color ?? Colors.deepPurple;
    final borderColor = bgColor.withValues(alpha: 0.3);
    final initials = _getInitials(user.displayName);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: showBorder
            ? Border.all(color: borderColor, width: size * 0.08)
            : null,
      ),
      child: ClipOval(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: user.avatarUrl != null && user.avatarUrl!.isNotEmpty
              ? _buildAvatarImage(
                  user.avatarUrl!,
                  bgColor,
                  initials,
                  // Use URL as key to trigger animation on avatar change
                  key: ValueKey(user.avatarUrl),
                )
              : _buildInitialCircle(bgColor, initials),
        ),
      ),
    );
  }

  Widget _buildAvatarImage(String url, Color bgColor, String initials, {Key? key}) {
    // Check if URL is SVG (Dicebear avatars)
    final isSvg = url.contains('dicebear') || url.endsWith('.svg');

    if (isSvg) {
      // For SVG avatars, use cached SVG with flutter_cache_manager
      return FutureBuilder<FileInfo?>(
        key: key,
        future: DefaultCacheManager().getFileFromCache(url),
        builder: (context, cacheSnapshot) {
          if (cacheSnapshot.connectionState == ConnectionState.done) {
            // If we have cached file, use it
            if (cacheSnapshot.hasData && cacheSnapshot.data != null) {
              return SvgPicture.file(
                cacheSnapshot.data!.file,
                fit: BoxFit.cover,
                placeholderBuilder: (context) => _buildInitialCircle(bgColor, initials),
              );
            }
          }

          // Otherwise, load from network and cache
          return FutureBuilder(
            future: DefaultCacheManager().downloadFile(url),
            builder: (context, downloadSnapshot) {
              if (downloadSnapshot.connectionState == ConnectionState.done &&
                  downloadSnapshot.hasData) {
                return SvgPicture.file(
                  downloadSnapshot.data!.file,
                  fit: BoxFit.cover,
                  placeholderBuilder: (context) => _buildInitialCircle(bgColor, initials),
                );
              }

              // Show placeholder while loading
              return _buildInitialCircle(bgColor, initials);
            },
          );
        },
      );
    } else {
      // For regular images (future photo uploads), use cached network image
      return CachedNetworkImage(
        key: key,
        imageUrl: url,
        fit: BoxFit.cover,
        placeholder: (context, url) => _buildInitialCircle(bgColor, initials),
        errorWidget: (context, url, error) => _buildInitialCircle(bgColor, initials),
        fadeInDuration: const Duration(milliseconds: 300),
        fadeOutDuration: const Duration(milliseconds: 300),
      );
    }
  }

  Widget _buildInitialCircle(Color bgColor, String initials) {
    return Container(
      color: bgColor,
      alignment: Alignment.center,
      child: Text(
        showInitials ? initials : '',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 20,
        ),
      ),
    );
  }
}

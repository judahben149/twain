import 'package:flutter/material.dart';
import 'package:twain/models/twain_user.dart';
import 'package:twain/widgets/main_avatar.dart';

/// A wrapper around TwainAvatar that only rebuilds when displayName or avatarUrl changes.
/// This prevents unnecessary rebuilds when other fields like status or lastActiveAt change.
class StableTwainAvatar extends StatefulWidget {
  final TwainUser user;
  final double size;
  final Color? color;
  final bool showInitials;
  final bool showBorder;

  const StableTwainAvatar({
    super.key,
    required this.user,
    this.size = 60,
    this.color,
    this.showInitials = true,
    this.showBorder = true,
  });

  @override
  State<StableTwainAvatar> createState() => _StableTwainAvatarState();
}

class _StableTwainAvatarState extends State<StableTwainAvatar> {
  late String _cachedId;
  late String _cachedDisplayName;
  late String? _cachedAvatarUrl;
  late Widget _cachedAvatar;

  @override
  void initState() {
    super.initState();
    _updateCache();
  }

  @override
  void didUpdateWidget(StableTwainAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Only rebuild the avatar if the fields that affect display have changed
    if (_cachedId != widget.user.id ||
        _cachedDisplayName != widget.user.displayName ||
        _cachedAvatarUrl != widget.user.avatarUrl ||
        oldWidget.size != widget.size ||
        oldWidget.color != widget.color ||
        oldWidget.showInitials != widget.showInitials ||
        oldWidget.showBorder != widget.showBorder) {
      _updateCache();
    }
  }

  void _updateCache() {
    _cachedId = widget.user.id;
    _cachedDisplayName = widget.user.displayName;
    _cachedAvatarUrl = widget.user.avatarUrl;
    _cachedAvatar = TwainAvatar(
      key: ValueKey('${widget.user.id}_${widget.user.displayName}_${widget.user.avatarUrl}'),
      user: widget.user,
      size: widget.size,
      color: widget.color,
      showInitials: widget.showInitials,
      showBorder: widget.showBorder,
    );
  }

  @override
  Widget build(BuildContext context) {
    // RepaintBoundary prevents repainting when parent rebuilds
    return RepaintBoundary(
      child: _cachedAvatar,
    );
  }
}

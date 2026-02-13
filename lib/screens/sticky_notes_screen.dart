import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:twain/constants/app_themes.dart';
import 'package:twain/models/sticky_note.dart';
import 'package:twain/models/content_report.dart';
import 'package:twain/providers/auth_providers.dart';
import 'package:twain/services/sticky_notes_service.dart';
import 'package:twain/screens/sticky_note_detail_screen.dart';
import 'package:twain/utils/connectivity_utils.dart';
import 'package:twain/widgets/report_bottom_sheet.dart';

class StickyNotesScreen extends ConsumerStatefulWidget {
  const StickyNotesScreen({super.key});

  @override
  ConsumerState<StickyNotesScreen> createState() => _StickyNotesScreenState();
}

class _StickyNotesScreenState extends ConsumerState<StickyNotesScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSending = false;
  String _selectedColor = 'FFF9C4'; // Default yellow
  final Map<String, bool> _optimisticLikes = {}; // noteId -> isLiked by current user

  final List<Map<String, dynamic>> _availableColors = [
    {'hex': 'FFF9C4', 'name': 'Yellow'},
    {'hex': 'FFE6F0', 'name': 'Pink'},
    {'hex': 'E1BEE7', 'name': 'Purple'},
    {'hex': 'B3E5FC', 'name': 'Blue'},
    {'hex': 'C8E6C9', 'name': 'Green'},
  ];

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    if (_isSending) return;
    if (!checkConnectivity(context, ref)) return;

    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    setState(() {
      _isSending = true;
    });

    try {
      await ref.read(stickyNotesServiceProvider).createNote(
            message,
            color: _selectedColor,
          );
      _messageController.clear();
      _selectedColor = 'FFF9C4'; // Reset to default

      // Scroll to bottom after sending
      Future.delayed(const Duration(milliseconds: 300), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e, stack) {
      print('StickyNotes: Failed to send message: $e');
      print('StickyNotes: Stack trace: $stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _toggleLike(StickyNote note) async {
    if (!checkConnectivity(context, ref)) return;

    final currentUserId = ref.read(twainUserProvider).value?.id;
    if (currentUserId == null) return;

    // Optimistic update
    final currentlyLiked = note.isLikedBy(currentUserId);
    setState(() {
      _optimisticLikes[note.id] = !currentlyLiked;
    });

    try {
      await ref.read(stickyNotesServiceProvider).toggleLike(note.id);
      // Success - the stream will update with real data
      setState(() {
        _optimisticLikes.remove(note.id);
      });
    } catch (e) {
      // Revert optimistic update on error
      setState(() {
        _optimisticLikes.remove(note.id);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to like note. Please try again.')),
        );
      }
    }
  }

  bool _isLikedByCurrentUser(StickyNote note, String? currentUserId) {
    if (currentUserId == null) return false;
    // Check optimistic state first
    if (_optimisticLikes.containsKey(note.id)) {
      return _optimisticLikes[note.id]!;
    }
    // Fall back to server state
    return note.isLikedBy(currentUserId);
  }

  /// Returns a small rotation angle (~-2.6 to 2.6 degrees)
  /// deterministically based on the note ID so it stays consistent.
  double _getTiltAngle(String noteId) {
    final hash = noteId.hashCode;
    // Range: -0.045 to 0.045 radians (~-2.6 to 2.6 degrees)
    return (hash % 91 - 45) / 1000.0;
  }

  Color _parseColor(String hexColor) {
    try {
      return Color(int.parse('FF$hexColor', radix: 16));
    } catch (e) {
      return const Color(0xFFFFF9C4); // Default yellow
    }
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final noteDate = DateTime(date.year, date.month, date.day);

    if (noteDate == today) {
      return 'Today';
    } else if (noteDate == yesterday) {
      return 'Yesterday';
    } else if (now.year == date.year) {
      return DateFormat('d MMM').format(date);
    } else {
      return DateFormat('d MMM yyyy').format(date);
    }
  }

  String _formatTime(DateTime dateTime) {
    return DateFormat('h:mm a').format(dateTime);
  }

  Map<String, List<StickyNote>> _groupNotesByDate(List<StickyNote> notes) {
    final Map<String, List<StickyNote>> grouped = {};

    for (final note in notes) {
      final dateKey = DateFormat('yyyy-MM-dd').format(note.createdAt);
      if (!grouped.containsKey(dateKey)) {
        grouped[dateKey] = [];
      }
      grouped[dateKey]!.add(note);
    }

    // Sort notes within each date group (oldest to newest)
    grouped.forEach((key, noteList) {
      noteList.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    });

    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final twainTheme = context.twainTheme;
    final currentUser = ref.watch(twainUserProvider).value;
    final notesAsync = ref.watch(stickyNotesStreamProvider);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: twainTheme.gradientColors,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(theme),
              Expanded(
                child: notesAsync.when(
                  data: (notes) {
                    if (notes.isEmpty) {
                      return _buildEmptyState(theme);
                    }

                    // Group notes by date
                    final groupedNotes = _groupNotesByDate(notes);
                    final sortedDates = groupedNotes.keys.toList()
                      ..sort(); // Oldest to newest

                    // Scroll to bottom after build
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (_scrollController.hasClients) {
                        _scrollController.jumpTo(
                          _scrollController.position.maxScrollExtent,
                        );
                      }
                    });

                    return CustomScrollView(
                      controller: _scrollController,
                      slivers: [
                        const SliverToBoxAdapter(
                          child: SizedBox(height: 16),
                        ),
                        for (final dateKey in sortedDates) ...[
                          // Date header
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.only(
                                left: 20.0,
                                right: 16.0,
                                top: 8.0,
                                bottom: 12.0,
                              ),
                              child: Text(
                                _formatDateHeader(DateTime.parse(dateKey)),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                                ),
                              ),
                            ),
                          ),
                          // List of notes for this date
                          SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final note = groupedNotes[dateKey]![index];
                                final isCurrentUser = note.senderId == currentUser?.id;
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20.0,
                                    vertical: 8.0,
                                  ),
                                  child: Transform.rotate(
                                    angle: _getTiltAngle(note.id),
                                    child: _buildNoteCard(
                                      note,
                                      isCurrentUser,
                                      _parseColor(note.color),
                                      theme,
                                      twainTheme,
                                    ),
                                  ),
                                );
                              },
                              childCount: groupedNotes[dateKey]!.length,
                            ),
                          ),
                          // Add spacing after each date group
                          const SliverToBoxAdapter(
                            child: SizedBox(height: 16),
                          ),
                        ],
                      ],
                    );
                  },
                  loading: () {
                    // Show cached data if available, otherwise show spinner
                    final previousValue = notesAsync.valueOrNull;
                    if (previousValue != null && previousValue.isNotEmpty) {
                      // Group cached notes by date
                      final groupedNotes = _groupNotesByDate(previousValue);
                      final sortedDates = groupedNotes.keys.toList()
                        ..sort(); // Oldest to newest

                      // Scroll to bottom after build
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (_scrollController.hasClients) {
                          _scrollController.jumpTo(
                            _scrollController.position.maxScrollExtent,
                          );
                        }
                      });

                      return CustomScrollView(
                        controller: _scrollController,
                        slivers: [
                          const SliverToBoxAdapter(
                            child: SizedBox(height: 16),
                          ),
                          for (final dateKey in sortedDates) ...[
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  left: 20.0,
                                  right: 16.0,
                                  top: 8.0,
                                  bottom: 12.0,
                                ),
                                child: Text(
                                  _formatDateHeader(DateTime.parse(dateKey)),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                                  ),
                                ),
                              ),
                            ),
                            SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final note = groupedNotes[dateKey]![index];
                                  final isCurrentUser = note.senderId == currentUser?.id;
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20.0,
                                      vertical: 8.0,
                                    ),
                                    child: Transform.rotate(
                                      angle: _getTiltAngle(note.id),
                                      child: _buildNoteCard(
                                        note,
                                        isCurrentUser,
                                        _parseColor(note.color),
                                        theme,
                                        twainTheme,
                                      ),
                                    ),
                                  );
                                },
                                childCount: groupedNotes[dateKey]!.length,
                              ),
                            ),
                            const SliverToBoxAdapter(
                              child: SizedBox(height: 16),
                            ),
                          ],
                        ],
                      );
                    }
                    // No cached data, show loading spinner
                    return Center(
                      child: CircularProgressIndicator(
                        color: twainTheme.iconColor,
                      ),
                    );
                  },
                  error: (error, stack) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: twainTheme.destructiveColor,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading notes',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            'Something went wrong. Please check your connection and try again.',
                            style: TextStyle(
                              fontSize: 14,
                              color: theme.colorScheme.onSurface.withOpacity(0.5),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () {
                            ref.invalidate(stickyNotesStreamProvider);
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: twainTheme.iconColor,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              _buildMessageInput(theme, twainTheme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 16),
          Text(
            'Sticky Notes',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  void _showColorPicker(ThemeData theme, TwainThemeExtension twainTheme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: twainTheme.cardBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Choose a color',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.center,
              children: _availableColors.map((colorData) {
                final hexColor = colorData['hex'] as String;
                final colorName = colorData['name'] as String;
                final isSelected = _selectedColor == hexColor;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedColor = hexColor;
                    });
                    Navigator.pop(context);
                  },
                  child: Column(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: _parseColor(hexColor),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? twainTheme.iconColor
                                : theme.dividerColor,
                            width: isSelected ? 3 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: isSelected
                            ? Icon(
                                Icons.check,
                                color: Colors.black54,
                                size: 28,
                              )
                            : null,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        colorName,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput(ThemeData theme, TwainThemeExtension twainTheme) {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: twainTheme.cardBackgroundColor,
        boxShadow: context.isDarkMode
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
        border: context.isDarkMode
            ? Border(top: BorderSide(color: theme.dividerColor, width: 0.5))
            : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              style: TextStyle(color: theme.colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: 'Type a sweet message...',
                hintStyle: TextStyle(
                  color: theme.colorScheme.onSurface.withOpacity(0.4),
                  fontSize: 16,
                ),
                filled: true,
                fillColor: context.isDarkMode
                    ? theme.colorScheme.surface
                    : Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          // Color picker button
          GestureDetector(
            onTap: () => _showColorPicker(theme, twainTheme),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _parseColor(_selectedColor),
                shape: BoxShape.circle,
                border: Border.all(
                  color: theme.dividerColor,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.palette,
                color: Colors.black54,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Send button
          Container(
            decoration: BoxDecoration(
              color: twainTheme.iconColor,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: _isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.send, color: Colors.white),
              onPressed: _isSending ? null : _sendMessage,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteCard(
    StickyNote note,
    bool isCurrentUser,
    Color color,
    ThemeData theme,
    TwainThemeExtension twainTheme,
  ) {
    final currentUserId = ref.watch(twainUserProvider).value?.id;
    final partner = ref.watch(pairedUserProvider).value;

    return GestureDetector(
      onTap: () {
        // Navigate to detail screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StickyNoteDetailScreen(note: note),
          ),
        );
      },
      onLongPress: () {
        // Show report bottom sheet
        ReportBottomSheet.show(
          context,
          contentId: note.id,
          contentType: ContentType.stickyNote,
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Message
            Text(
              note.message,
              style: TextStyle(
                fontSize: 16,
                color: Colors.black87,
                height: 1.4,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 12),
            // Sender and timestamp
            Text(
              '${isCurrentUser ? 'You' : note.senderName ?? 'Partner'} • ${_formatTime(note.createdAt)}',
              style: TextStyle(
                fontSize: 13,
                color: Colors.black54,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            // Footer row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Likes section
                _buildLikesSection(note, currentUserId, partner, twainTheme),
                // Reply count
                if (note.hasReplies)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 14,
                          color: Colors.black54,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${note.replyCount}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLikesSection(
      StickyNote note, String? currentUserId, partner, TwainThemeExtension twainTheme) {
    // Use optimistic state
    final isCurrentUserLiked = _isLikedByCurrentUser(note, currentUserId);
    final isPartnerLiked = partner != null && note.isLikedBy(partner.id);

    final currentUser = ref.watch(twainUserProvider).value;

    if (!isCurrentUserLiked && !isPartnerLiked) {
      // No likes - show empty heart (small, inline)
      return GestureDetector(
        onTap: () => _toggleLike(note),
        child: Icon(
          Icons.favorite_border,
          color: Colors.grey.shade500,
          size: 20,
        ),
      );
    }

    // Build list of avatars to show
    final avatarsToShow = <Widget>[];

    if (isCurrentUserLiked && currentUser?.avatarUrl != null) {
      avatarsToShow.add(_buildAvatar(currentUser!.avatarUrl!));
    }
    if (isPartnerLiked && partner?.avatarUrl != null) {
      avatarsToShow.add(_buildAvatar(partner!.avatarUrl!));
    }

    return GestureDetector(
      onTap: () => _toggleLike(note),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.favorite,
            color: AppThemes.appAccentColor,
            size: 20,
          ),
          if (avatarsToShow.isNotEmpty) ...[
            const SizedBox(width: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: avatarsToShow.asMap().entries.map((entry) {
                final index = entry.key;
                final avatar = entry.value;
                return Transform.translate(
                  offset: Offset(index * -8.0, 0),
                  child: avatar,
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatar(String avatarUrl) {
    // Convert SVG URLs to PNG format for dicebear
    final imageUrl = avatarUrl.contains('dicebear.com')
        ? avatarUrl.replaceAll('/svg?', '/png?')
        : avatarUrl;

    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        color: Colors.grey.shade200,
      ),
      child: ClipOval(
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Icon(
              Icons.person,
              size: 16,
              color: Colors.grey.shade400,
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.sticky_note_2_outlined,
              size: 80,
              color: theme.colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No notes yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Send a sweet message to your partner!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


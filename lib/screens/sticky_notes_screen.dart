import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:twain/constants/app_colours.dart';
import 'package:twain/models/sticky_note.dart';
import 'package:twain/providers/auth_providers.dart';
import 'package:twain/services/sticky_notes_service.dart';
import 'package:twain/screens/sticky_note_detail_screen.dart';

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
    } catch (e) {
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
          SnackBar(content: Text('Failed to like note: $e')),
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
    final currentUser = ref.watch(twainUserProvider).value;
    final notesAsync = ref.watch(stickyNotesStreamProvider);

    return Scaffold(
      body: Container(
        decoration: _buildGradientBackground(),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: notesAsync.when(
                  data: (notes) {
                    if (notes.isEmpty) {
                      return _buildEmptyState();
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
                                  color: Colors.grey.shade700,
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
                                    vertical: 6.0,
                                  ),
                                  child: _buildNoteCard(
                                    note,
                                    isCurrentUser,
                                    _parseColor(note.color),
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
                                    color: Colors.grey.shade700,
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
                                      vertical: 6.0,
                                    ),
                                    child: _buildNoteCard(
                                      note,
                                      isCurrentUser,
                                      _parseColor(note.color),
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
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  },
                  error: (error, stack) => Center(
                    child: Text('Error loading notes: $error'),
                  ),
                ),
              ),
              _buildMessageInput(),
            ],
          ),
        ),
      ),
    );
  }

  BoxDecoration _buildGradientBackground() {
    return const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFF5F5F5),
          Color(0xFFF0E6F0),
          Color(0xFFFFE6F0),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.black),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 16),
          const Text(
            'Sticky Notes',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.black,
            ),
          ),
        ],
      ),
    );
  }

  void _showColorPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
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
                color: Colors.grey.shade800,
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
                                ? const Color(0xFFE91E63)
                                : Colors.grey.shade300,
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
                            ? const Icon(
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
                          color: Colors.grey.shade700,
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

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Type a sweet message...',
                hintStyle: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 16,
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
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
            onTap: _showColorPicker,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _parseColor(_selectedColor),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.grey.shade300,
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
            decoration: const BoxDecoration(
              color: Color(0xFFE91E63),
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

  Widget _buildNoteCard(StickyNote note, bool isCurrentUser, Color color) {
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
      child: Stack(
        children: [
          // Main note container
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 8,
                  offset: const Offset(2, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Message with handwriting font
                Text(
                  note.message,
                  style: GoogleFonts.patrickHand(
                    fontSize: 19,
                    color: AppColors.black,
                    height: 1.3,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 12),
                // Sender and timestamp
                Text(
                  '${isCurrentUser ? 'You' : note.senderName ?? 'Partner'} • ${_formatTime(note.createdAt)}',
                  style: GoogleFonts.patrickHand(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 12),
                // Footer row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Likes section
                    _buildLikesSection(note, currentUserId, partner),
                    // Reply count
                    if (note.hasReplies)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 14,
                              color: Colors.grey.shade700,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${note.replyCount}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
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
          // Bent corner effect (top-right corner)
          Positioned(
            top: 0,
            right: 0,
            child: ClipPath(
              clipper: _BentCornerClipper(),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.black.withOpacity(0.1),
                      Colors.black.withOpacity(0.05),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLikesSection(
      StickyNote note, String? currentUserId, partner) {
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
          const Icon(
            Icons.favorite,
            color: Color(0xFFE91E63),
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

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.sticky_note_2_outlined,
              size: 80,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'No notes yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Send a sweet message to your partner!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Custom clipper for the bent corner effect
class _BentCornerClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

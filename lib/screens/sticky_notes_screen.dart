import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
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
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
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
                    return ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24.0,
                        vertical: 16.0,
                      ),
                      itemCount: notes.length,
                      itemBuilder: (context, index) {
                        final note = notes[index];
                        final isCurrentUser = note.senderId == currentUser?.id;
                        return _buildNoteCard(
                          note,
                          isCurrentUser,
                          _parseColor(note.color),
                        );
                      },
                    );
                  },
                  loading: () {
                    // Show cached data if available, otherwise show spinner
                    final previousValue = notesAsync.valueOrNull;
                    if (previousValue != null && previousValue.isNotEmpty) {
                      // Show cached data while loading new data
                      return ListView.builder(
                        controller: _scrollController,
                        reverse: true,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24.0,
                          vertical: 16.0,
                        ),
                        itemCount: previousValue.length,
                        itemBuilder: (context, index) {
                          final note = previousValue[index];
                          final isCurrentUser = note.senderId == currentUser?.id;
                          return _buildNoteCard(
                            note,
                            isCurrentUser,
                            _parseColor(note.color),
                          );
                        },
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Color picker
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _availableColors.length,
              itemBuilder: (context, index) {
                final colorData = _availableColors[index];
                final hexColor = colorData['hex'] as String;
                final isSelected = _selectedColor == hexColor;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedColor = hexColor;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 12),
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: _parseColor(hexColor),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFFE91E63)
                            : Colors.grey.shade300,
                        width: isSelected ? 3 : 1,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          // Message input
          Row(
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
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFE91E63),
                      Color(0xFF9C27B0),
                    ],
                  ),
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
        ],
      ),
    );
  }

  Widget _buildNoteCard(StickyNote note, bool isCurrentUser, Color color) {
    final currentUserId = ref.watch(twainUserProvider).value?.id;
    final partner = ref.watch(pairedUserProvider).value;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: GestureDetector(
        onTap: () {
          // Navigate to detail screen
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => StickyNoteDetailScreen(note: note),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                note.message,
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.black,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${isCurrentUser ? 'You' : note.senderName ?? 'Partner'} • ${timeago.format(note.createdAt)}',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
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

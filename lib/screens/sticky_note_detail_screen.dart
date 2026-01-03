import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:twain/constants/app_colours.dart';
import 'package:twain/models/sticky_note.dart';
import 'package:twain/models/sticky_note_reply.dart';
import 'package:twain/providers/auth_providers.dart';

class StickyNoteDetailScreen extends ConsumerStatefulWidget {
  final StickyNote note;

  const StickyNoteDetailScreen({
    super.key,
    required this.note,
  });

  @override
  ConsumerState<StickyNoteDetailScreen> createState() =>
      _StickyNoteDetailScreenState();
}

class _StickyNoteDetailScreenState
    extends ConsumerState<StickyNoteDetailScreen> {
  final _replyController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSending = false;

  @override
  void dispose() {
    _replyController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendReply() async {
    if (_isSending) return;

    final message = _replyController.text.trim();
    if (message.isEmpty) return;

    setState(() {
      _isSending = true;
    });

    try {
      await ref
          .read(stickyNotesServiceProvider)
          .createReply(widget.note.id, message);
      _replyController.clear();

      // Scroll to bottom
      Future.delayed(const Duration(milliseconds: 100), () {
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
          SnackBar(content: Text('Failed to send reply: $e')),
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

  Future<void> _toggleLike() async {
    try {
      await ref.read(stickyNotesServiceProvider).toggleLike(widget.note.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to like note: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(twainUserProvider).value;
    final partner = ref.watch(pairedUserProvider).value;
    final repliesAsync =
        ref.watch(stickyNoteRepliesStreamProvider(widget.note.id));

    final isCurrentUserNote = widget.note.senderId == currentUser?.id;

    return Scaffold(
      body: Container(
        decoration: _buildGradientBackground(),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 16.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Main note card
                      _buildMainNoteCard(
                        widget.note,
                        isCurrentUserNote,
                        currentUser?.id,
                        partner,
                      ),
                      const SizedBox(height: 24),

                      // Replies section
                      if (widget.note.hasReplies || repliesAsync.hasValue)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Replies',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade800,
                              ),
                            ),
                            const SizedBox(height: 12),
                            repliesAsync.when(
                              data: (replies) {
                                if (replies.isEmpty) {
                                  return _buildEmptyRepliesState();
                                }
                                return Column(
                                  children: replies.map((reply) {
                                    final isCurrentUserReply =
                                        reply.senderId == currentUser?.id;
                                    return _buildReplyCard(
                                      reply,
                                      isCurrentUserReply,
                                    );
                                  }).toList(),
                                );
                              },
                              loading: () => const Center(
                                child: CircularProgressIndicator(),
                              ),
                              error: (error, stack) => Text('Error: $error'),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              _buildReplyInput(),
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
            'Note Details',
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

  Color _parseColor(String hexColor) {
    try {
      return Color(int.parse('FF$hexColor', radix: 16));
    } catch (e) {
      return const Color(0xFFFFF9C4); // Default yellow
    }
  }

  String _formatTime(DateTime dateTime) {
    return DateFormat('h:mm a').format(dateTime);
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final noteDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (noteDate == today) {
      return 'Today, ${_formatTime(dateTime)}';
    } else {
      return '${DateFormat('d MMM').format(dateTime)}, ${_formatTime(dateTime)}';
    }
  }

  Widget _buildMainNoteCard(
    StickyNote note,
    bool isCurrentUser,
    String? currentUserId,
    partner,
  ) {
    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _parseColor(note.color),
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 12,
                offset: const Offset(2, 4),
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
                  fontSize: 22,
                  color: AppColors.black,
                  height: 1.4,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 16),

              // Sender and timestamp
              Text(
                '${isCurrentUser ? 'You' : note.senderName ?? 'Partner'} • ${_formatDateTime(note.createdAt)}',
                style: GoogleFonts.patrickHand(
                  fontSize: 15,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w400,
                ),
              ),

              const SizedBox(height: 16),

              // Likes section
              _buildLikesSection(note, currentUserId, partner),
            ],
          ),
        ),
        // Bent corner effect
        Positioned(
          top: 0,
          right: 0,
          child: ClipPath(
            clipper: _BentCornerClipper(),
            child: Container(
              width: 30,
              height: 30,
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
    );
  }

  Widget _buildLikesSection(
    StickyNote note,
    String? currentUserId,
    partner,
  ) {
    final currentUser = ref.watch(twainUserProvider).value;
    final isCurrentUserLiked = currentUserId != null && note.isLikedBy(currentUserId);
    final isPartnerLiked = partner != null && note.isLikedBy(partner.id);

    if (!isCurrentUserLiked && !isPartnerLiked) {
      return GestureDetector(
        onTap: _toggleLike,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.favorite_border,
              color: Colors.grey.shade600,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              'Be the first to like this',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    // Build list of avatars to show
    final avatarsToShow = <Widget>[];

    if (isCurrentUserLiked && currentUser?.avatarUrl != null) {
      avatarsToShow.add(_buildAvatar(currentUser!.avatarUrl!, 32));
    }
    if (isPartnerLiked && partner?.avatarUrl != null) {
      avatarsToShow.add(_buildAvatar(partner!.avatarUrl!, 32));
    }

    return GestureDetector(
      onTap: _toggleLike,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFE91E63).withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.favorite,
              color: Color(0xFFE91E63),
              size: 22,
            ),
            if (avatarsToShow.isNotEmpty) ...[
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: avatarsToShow.asMap().entries.map((entry) {
                  final index = entry.key;
                  final avatar = entry.value;
                  return Transform.translate(
                    offset: Offset(index * -12.0, 0),
                    child: avatar,
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(String avatarUrl, double size) {
    // Convert SVG URLs to PNG format for dicebear
    final imageUrl = avatarUrl.contains('dicebear.com')
        ? avatarUrl.replaceAll('/svg?', '/png?')
        : avatarUrl;

    return Container(
      width: size,
      height: size,
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
              size: size * 0.6,
              color: Colors.grey.shade400,
            );
          },
        ),
      ),
    );
  }

  Widget _buildReplyCard(StickyNoteReply reply, bool isCurrentUser) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey.shade200,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Reply message with handwriting font
            Text(
              reply.message,
              style: GoogleFonts.patrickHand(
                fontSize: 16,
                color: AppColors.black,
                height: 1.3,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 8),

            // Sender and timestamp
            Text(
              '${isCurrentUser ? 'You' : reply.senderName ?? 'Partner'} • ${_formatTime(reply.createdAt)}',
              style: GoogleFonts.patrickHand(
                fontSize: 13,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyRepliesState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0),
      child: Center(
        child: Text(
          'No replies yet. Be the first!',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade500,
          ),
        ),
      ),
    );
  }

  Widget _buildReplyInput() {
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
              controller: _replyController,
              decoration: InputDecoration(
                hintText: 'Write a reply...',
                hintStyle: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 15,
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
              onSubmitted: (_) => _sendReply(),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
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
              onPressed: _isSending ? null : _sendReply,
            ),
          ),
        ],
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

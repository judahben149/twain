import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:twain/constants/app_themes.dart';
import 'package:twain/providers/auth_providers.dart';
import 'package:twain/services/avatar_service.dart';
import 'package:twain/widgets/avatar_preview_card.dart';
import 'package:twain/widgets/avatar_style_section.dart';

/// Screen for selecting Dicebear avatars
class AvatarSelectorScreen extends ConsumerStatefulWidget {
  const AvatarSelectorScreen({super.key});

  @override
  ConsumerState<AvatarSelectorScreen> createState() =>
      _AvatarSelectorScreenState();
}

class _AvatarSelectorScreenState extends ConsumerState<AvatarSelectorScreen> {
  bool _isSaving = false;
  String? _selectedAvatarUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final twainTheme = context.twainTheme;
    final currentUserAsync = ref.watch(twainUserProvider);

    return currentUserAsync.when(
      data: (currentUser) {
        if (currentUser == null) {
          return Scaffold(
            body: Center(
              child: Text(
                'No user logged in',
                style: TextStyle(color: theme.colorScheme.onSurface),
              ),
            ),
          );
        }

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
                  _buildHeader(context, theme),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          AvatarPreviewCard(
                            user: currentUser,
                            onReset: () => _resetToInitials(currentUser.id),
                            isResetting: _isSaving,
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            child: Text(
                              'Choose an Avatar',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                          _buildAvatarSections(),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: context.twainTheme.iconColor,
          ),
        ),
      ),
      error: (error, stack) => Scaffold(
        body: Center(
          child: Text(
            'Error: $error',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme) {
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
            'Choose Avatar',
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

  Widget _buildAvatarSections() {
    final avatarsByStyle = AvatarService.getAvatarsByStyle();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: avatarsByStyle.entries.map((entry) {
          return AvatarStyleSection(
            style: entry.key,
            avatars: entry.value,
            selectedAvatarUrl: _selectedAvatarUrl,
            onAvatarSelected: _selectAvatar,
          );
        }).toList(),
      ),
    );
  }

  Future<void> _selectAvatar(AvatarOption avatar) async {
    final twainTheme = context.twainTheme;

    setState(() {
      _selectedAvatarUrl = avatar.url;
      _isSaving = true;
    });

    try {
      await ref.read(authServiceProvider).updateUserProfile(
            avatarUrl: avatar.url,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                const Text('Avatar updated successfully!'),
              ],
            ),
            backgroundColor: const Color(0xFF4CAF50),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Failed to update avatar: $e')),
              ],
            ),
            backgroundColor: twainTheme.destructiveColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _resetToInitials(String userId) async {
    final twainTheme = context.twainTheme;

    setState(() {
      _isSaving = true;
    });

    try {
      await ref.read(authServiceProvider).updateUserProfile(
            avatarUrl: '',
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                const Text('Avatar reset to initials'),
              ],
            ),
            backgroundColor: const Color(0xFF4CAF50),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Failed to reset avatar: $e')),
              ],
            ),
            backgroundColor: twainTheme.destructiveColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
}

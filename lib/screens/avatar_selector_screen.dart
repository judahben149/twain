import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:twain/constants/app_colours.dart';
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
    final currentUserAsync = ref.watch(twainUserProvider);

    return currentUserAsync.when(
      data: (currentUser) {
        if (currentUser == null) {
          return const Scaffold(
            body: Center(child: Text('No user logged in')),
          );
        }

        return Scaffold(
          body: Container(
            decoration: _buildGradientBackground(),
            child: SafeArea(
              child: Column(
                children: [
                  _buildHeader(context),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          AvatarPreviewCard(
                            user: currentUser,
                            onReset: () => _resetToInitials(currentUser.id),
                            isResetting: _isSaving,
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            child: Text(
                              'Choose an Avatar',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.black,
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
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        body: Center(child: Text('Error: $error')),
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

  Widget _buildHeader(BuildContext context) {
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
            'Choose Avatar',
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
            backgroundColor: const Color(0xFFE91E63),
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
            backgroundColor: const Color(0xFFE91E63),
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

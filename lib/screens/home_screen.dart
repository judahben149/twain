import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:twain/constants/app_colours.dart';
import 'package:twain/providers/auth_providers.dart';
import 'package:twain/services/auth_service.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(twainUserProvider).value;

    return Scaffold(
      body: Container(
        decoration: _buildGradientBackground(),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 24),
                      _buildConnectionCard(currentUser),
                      const SizedBox(height: 32),
                      _buildFeatureCard(
                        icon: Icons.wallpaper_outlined,
                        title: 'Wallpaper',
                        subtitle: 'Sync your home screens',
                        colors: [
                          const Color(0xFFE8D5F2),
                          const Color(0xFFFCE4EC),
                        ],
                        onTap: () {
                          // TODO: Navigate to wallpaper sync
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildFeatureCard(
                        icon: Icons.photo_library_outlined,
                        title: 'Shared Board',
                        subtitle: 'Photos & memories',
                        colors: [
                          const Color(0xFFE3F2FD),
                          const Color(0xFFFFF9C4),
                          const Color(0xFFC8E6C9),
                        ],
                        onTap: () {
                          // TODO: Navigate to shared board
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildFeatureCard(
                        icon: Icons.sticky_note_2_outlined,
                        title: 'Sticky Notes',
                        subtitle: 'Leave sweet messages',
                        colors: [
                          const Color(0xFFFFF9C4),
                          const Color(0xFFFCE4EC),
                          const Color(0xFFE1BEE7),
                        ],
                        onTap: () {
                          // TODO: Navigate to sticky notes
                        },
                      ),
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
          // App logo
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFE91E63),
                  const Color(0xFF9C27B0),
                ],
              ),
            ),
            child: const Center(
              child: Text(
                'T',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Twain',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.black,
            ),
          ),
          const Spacer(),
          // Notification bell
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                iconSize: 28,
                color: AppColors.black,
                onPressed: () {
                  // TODO: Show notifications
                },
              ),
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE91E63),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionCard(dynamic currentUser) {
    return FutureBuilder(
      future: ref.read(authServiceProvider).getPairedUser(),
      builder: (context, snapshot) {
        final partner = snapshot.data;
        final isLoading = snapshot.connectionState == ConnectionState.waiting;

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              const Text(
                'Connected with',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary3,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Current user avatar
                  _buildAvatar(
                    label: currentUser?.displayName?.substring(0, 2).toUpperCase() ?? 'YO',
                    name: 'You',
                    color: const Color(0xFF9C27B0),
                  ),
                  const SizedBox(width: 16),
                  // Connection dots
                  Row(
                    children: List.generate(
                      3,
                      (index) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Partner avatar
                  isLoading
                      ? const SizedBox(
                          width: 80,
                          height: 80,
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : _buildAvatar(
                          label: partner?.displayName?.substring(0, 2).toUpperCase() ?? 'PA',
                          name: partner?.displayName ?? 'Partner',
                          color: const Color(0xFFE91E63),
                        ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Last active: 2 min ago',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAvatar({
    required String label,
    required String name,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          name,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.black,
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> colors,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 15,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFF3E5F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: const Color(0xFF9C27B0),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            // Color preview
            Row(
              children: colors.map((color) {
                return Container(
                  margin: const EdgeInsets.only(left: 6),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(6),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

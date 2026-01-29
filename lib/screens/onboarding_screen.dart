import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:twain/constants/app_themes.dart';
import 'package:twain/services/onboarding_service.dart';
import 'package:twain/widgets/onboarding_page.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({
    super.key,
    required this.onComplete,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  final _onboardingService = OnboardingService();
  int _currentPage = 0;

  final List<OnboardingPageData> _pages = [
    OnboardingPageData(
      icon: Icons.favorite,
      title: 'Welcome to Twain',
      description: 'The everything app for couples. Stay connected with your partner in beautiful ways.',
      gradientColors: [AppThemes.appAccentColor, const Color(0xFFE91E63)],
    ),
    OnboardingPageData(
      icon: Icons.wallpaper_outlined,
      title: 'Sync Wallpapers',
      description: 'Set the same wallpaper on both your phones with a single tap. Share memories, art, or sweet moments.',
      gradientColors: [const Color(0xFFE8D5F2), const Color(0xFFFCE4EC)],
    ),
    OnboardingPageData(
      icon: Icons.sticky_note_2_outlined,
      title: 'Sweet Messages',
      description: 'Leave colorful sticky notes for your partner. Send love notes that brighten their day.',
      gradientColors: [const Color(0xFFFFF9C4), const Color(0xFFE1BEE7)],
    ),
    OnboardingPageData(
      icon: Icons.photo_library_outlined,
      title: 'Shared Memories',
      description: 'Create a shared board with photos and memories. Build your story together.',
      gradientColors: [const Color(0xFFE3F2FD), const Color(0xFFC8E6C9)],
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _skip() {
    _completeOnboarding();
  }

  Future<void> _completeOnboarding() async {
    await _onboardingService.markOnboardingCompleted();
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final twainTheme = context.twainTheme;
    final isLastPage = _currentPage == _pages.length - 1;

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
              // Header with skip button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Logo
                    Row(
                      children: [
                        ClipOval(
                          child: SvgPicture.asset(
                            'assets/images/logo_twain_circular.svg',
                            width: 36,
                            height: 36,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Twain',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    // Skip button
                    if (!isLastPage)
                      TextButton(
                        onPressed: _skip,
                        child: Text(
                          'Skip',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    else
                      const SizedBox(width: 60),
                  ],
                ),
              ),
              // Page content
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _pages.length,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  itemBuilder: (context, index) {
                    final page = _pages[index];
                    return OnboardingPage(
                      icon: page.icon,
                      title: page.title,
                      description: page.description,
                      gradientColors: page.gradientColors,
                    );
                  },
                ),
              ),
              // Bottom section with dots and button
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Page indicators
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _pages.length,
                        (index) => _buildDotIndicator(index, twainTheme),
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Next/Get Started button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _nextPage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: twainTheme.iconColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 2,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isLastPage ? 'Get Started' : 'Next',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              isLastPage ? Icons.check : Icons.arrow_forward,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDotIndicator(int index, TwainThemeExtension twainTheme) {
    final isActive = index == _currentPage;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: isActive ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: isActive
            ? twainTheme.iconColor
            : twainTheme.iconColor.withOpacity(0.3),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class OnboardingPageData {
  final IconData icon;
  final String title;
  final String description;
  final List<Color> gradientColors;

  OnboardingPageData({
    required this.icon,
    required this.title,
    required this.description,
    required this.gradientColors,
  });
}

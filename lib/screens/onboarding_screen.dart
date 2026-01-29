import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lottie/lottie.dart';
import 'package:twain/constants/app_themes.dart';
import 'package:twain/services/onboarding_service.dart';

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
      lottiePath: 'assets/lottie/love_flying.json',
      title: 'Welcome to Twain',
      description: 'The everything app for couples. Stay close, even when you\'re apart.',
      gradientColors: [const Color(0xFFFFF8FB), const Color(0xFFFFEEF4)],
    ),
    OnboardingPageData(
      lottiePath: 'assets/lottie/wallpaper.json',
      title: 'Sync Wallpapers',
      description: 'Set the same wallpaper on both your phones with a single tap. Share memories, art, or sweet moments.',
      gradientColors: [const Color(0xFFE8D5F2), const Color(0xFFFCE4EC)],
    ),
    OnboardingPageData(
      lottiePath: 'assets/lottie/sticky_notes.json',
      title: 'Sweet Messages',
      description: 'Leave colorful sticky notes for your partner. Send love notes that brighten their day.',
      gradientColors: [const Color(0xFFFFF9C4), const Color(0xFFE1BEE7)],
    ),
    OnboardingPageData(
      lottiePath: 'assets/lottie/shared_board.json',
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
                    return _buildOnboardingPage(page, theme);
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

  Widget _buildOnboardingPage(OnboardingPageData page, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: page.gradientColors,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: page.gradientColors.first.withOpacity(0.3),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipOval(
              child: Lottie.asset(
                page.lottiePath,
                fit: BoxFit.contain,
                repeat: true,
                errorBuilder: (context, error, stackTrace) {
                  debugPrint('Lottie error (${page.lottiePath}): $error');
                  return Icon(
                    Icons.favorite,
                    size: 80,
                    color: Colors.white,
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 48),
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            page.description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: theme.colorScheme.onSurface.withOpacity(0.6),
              height: 1.5,
            ),
          ),
        ],
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
  final String lottiePath;
  final String title;
  final String description;
  final List<Color> gradientColors;

  OnboardingPageData({
    required this.lottiePath,
    required this.title,
    required this.description,
    required this.gradientColors,
  });
}

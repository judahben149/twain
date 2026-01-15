import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:twain/widgets/buttons.dart';
import 'package:twain/providers/auth_providers.dart';
import 'package:twain/constants/app_themes.dart';

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(twainUserProvider);
    final twainTheme = context.twainTheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: twainTheme.gradientColors,
          ),
        ),
        child: Center(
          child: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                  // _buildLogo(),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.08),
                  _buildTitle(context),
                  SizedBox(height: 12),
                  _buildSubtitle(context),
                  SizedBox(height: 12),
                  _buildSubtext(context),
                  SizedBox(height: 36),
                  _buildCtaButton(context, onPressed: () {}, text: 'Get started'),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.1),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTitle(BuildContext context) {
    final twainTheme = context.twainTheme;
    return Text(
      'Twain',
      style: TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.bold,
        color: twainTheme.iconColor,
      ),
    );
  }

  Widget _buildSubtitle(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      'Stay in sync with your partner',
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.normal,
        color: theme.colorScheme.onSurface.withOpacity(0.7),
      ),
    );
  }

  Widget _buildSubtext(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      'Share moments, set wallpapers together, and stay connected',
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: theme.colorScheme.onSurface.withOpacity(0.5),
      ),
    );
  }

  Widget _buildCtaButton(
      BuildContext context,
      {
        required VoidCallback onPressed,
        required String text
      }
      ) {
    final twainTheme = context.twainTheme;
    return PrimaryButton(
      onPressed: onPressed,
      text: text,
      color: twainTheme.iconBackgroundColor,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:twain/widgets/buttons.dart';
import 'package:twain/providers/auth_providers.dart';
import 'package:twain/constants/app_colours.dart';

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(twainUserProvider);

    return Scaffold(
      body: Container(
        color: AppColors.background,
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
    return const Text(
      'Twain',
      style: TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.bold,
        color: Colors.purple,
      ),
    );
  }

  Widget _buildSubtitle(BuildContext context) {
    return const Text(
      'Stay in sync with your partner',
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.normal,
        color: AppColors.textSecondary2
      ),
    );
  }

  Widget _buildSubtext(BuildContext context) {
    return const Text(
      'Share moments, set wallpapers together, and stay connected',
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary
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
    return PrimaryButton(
      onPressed: onPressed,
      text: text,
      color: AppColors.secondaryLight
    );
  }
}
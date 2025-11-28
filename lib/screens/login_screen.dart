import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:twain/constants/app_colours.dart';
import 'package:twain/widgets/textfields.dart';
import 'package:twain/widgets/buttons.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();

    return Scaffold(
      body: Container(
        decoration: _buildGradientBackground(),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  _buildBackButton(context),
                  const SizedBox(height: 60),
                  _buildHeader(),
                  const SizedBox(height: 48),
                  _buildEmailField(emailController),
                  const SizedBox(height: 24),
                  _buildPasswordField(passwordController),
                  const SizedBox(height: 32),
                  _buildSignInButton(),
                  const SizedBox(height: 32),
                  const DividerWithText(text: 'Or continue with', color: AppColors.grey),
                  const SizedBox(height: 24),
                  _buildSocialButtons(),
                  const SizedBox(height: 32),
                  _buildSignUpLink(context),
                  const SizedBox(height: 32),
                ],
              ),
            ),
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

  Widget _buildBackButton(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back, color: AppColors.black),
      onPressed: () => Navigator.pop(context),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
    );
  }

  Widget _buildHeader() {
    return const Column(
      children: [
        Center(
          child: Text(
            'Welcome back',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: AppColors.black,
            ),
          ),
        ),
        SizedBox(height: 8),
        Center(
          child: Text(
            'Sign in to connect with your partner',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmailField(TextEditingController controller) {
    return LabeledTextField(
      label: 'Email',
      child: EmailTextField(controller: controller),
    );
  }

  Widget _buildPasswordField(TextEditingController controller) {
    return LabeledTextField(
      label: 'Password',
      child: PasswordTextField(controller: controller),
    );
  }

  Widget _buildSignInButton() {
    return GradientButton(
      onPressed: () {
        // TODO: Implement sign in logic
      },
      text: 'Sign In',
      icon: Icons.email_outlined,
    );
  }

  Widget _buildSocialButtons() {
    return Column(
      children: [
        SocialLoginButton(
          onPressed: () {
            // TODO: Implement Google sign in
          },
          text: 'Continue with Google',
          iconColor: const Color(0xFFFF6B35),
        ),
        const SizedBox(height: 16),
        SocialLoginButton(
          onPressed: () {
            // TODO: Implement Apple sign in
          },
          text: 'Continue with Apple',
          iconColor: AppColors.black,
        ),
      ],
    );
  }

  Widget _buildSignUpLink(BuildContext context) {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            "Don't have an account? ",
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          GestureDetector(
            onTap: () {
              // TODO: Navigate to sign up screen
            },
            child: const Text(
              'Sign up',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF9C27B0),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

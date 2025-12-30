import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:twain/constants/app_colours.dart';
import 'package:twain/providers/auth_providers.dart';
import 'package:twain/widgets/textfields.dart';
import 'package:twain/widgets/buttons.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signInWithEmail() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter email and password';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = ref.read(authServiceProvider);
      await authService.signInWithEmailPassword(email, password);
      // Navigation will be handled by AuthGate automatically
    } catch (e) {
      setState(() {
        _errorMessage = 'Invalid email or password';
        _isLoading = false;
      });
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = ref.read(authServiceProvider);
      final user = await authService.signInWithGoogle();

      if (user == null) {
        setState(() {
          _errorMessage = 'Google sign-in was cancelled';
          _isLoading = false;
        });
      }
      // If successful, AuthGate will handle navigation
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to sign in with Google';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  if (_errorMessage != null) ...[
                    _buildErrorMessage(),
                    const SizedBox(height: 16),
                  ],
                  _buildEmailField(_emailController),
                  const SizedBox(height: 24),
                  _buildPasswordField(_passwordController),
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

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(
                color: Colors.red.shade700,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
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
      onPressed: _isLoading ? null : () => _signInWithEmail(),
      text: _isLoading ? 'Signing in...' : 'Sign In',
      icon: _isLoading ? null : Icons.email_outlined,
    );
  }

  Widget _buildSocialButtons() {
    return Column(
      children: [
        SocialLoginButton(
          onPressed: _isLoading ? null : () => _signInWithGoogle(),
          text: 'Continue with Google',
          iconColor: const Color(0xFFFF6B35),
        ),
        // Only show Apple sign-in on iOS
        if (Platform.isIOS) ...[
          const SizedBox(height: 16),
          SocialLoginButton(
            onPressed: _isLoading ? null : () {
              // TODO: Implement Apple sign in when ready
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Apple Sign-In coming soon')),
              );
            },
            text: 'Continue with Apple',
            iconColor: AppColors.black,
          ),
        ],
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
            onTap: _isLoading ? null : () {
              // TODO: Navigate to sign up screen
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sign up screen coming soon')),
              );
            },
            child: Text(
              'Sign up',
              style: TextStyle(
                fontSize: 14,
                color: _isLoading ? AppColors.grey : const Color(0xFF9C27B0),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

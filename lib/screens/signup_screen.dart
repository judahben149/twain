import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:twain/constants/app_themes.dart';
import 'package:twain/providers/auth_providers.dart';
import 'package:twain/screens/email_verification_screen.dart';
import 'package:twain/widgets/textfields.dart';
import 'package:twain/widgets/buttons.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signUpWithEmail() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      setState(() {
        _errorMessage = 'Please fill in all fields';
      });
      return;
    }

    if (password != confirmPassword) {
      setState(() {
        _errorMessage = 'Passwords do not match';
      });
      return;
    }

    if (password.length < 6) {
      setState(() {
        _errorMessage = 'Password must be at least 6 characters';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = ref.read(authServiceProvider);
      await authService.signUpWithEmailPassword(email, password, name);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => EmailVerificationScreen(email: email),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _signUpWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = ref.read(authServiceProvider);
      final user = await authService.signInWithGoogle();

      if (user == null) {
        setState(() {
          _errorMessage = 'Google sign-up was cancelled';
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to sign up with Google';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Container(
        decoration: _buildGradientBackground(context),
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
                  _buildHeader(context),
                  const SizedBox(height: 48),
                  if (_errorMessage != null) ...[
                    _buildErrorMessage(context),
                    const SizedBox(height: 16),
                  ],
                  _buildNameField(_nameController),
                  const SizedBox(height: 24),
                  _buildEmailField(_emailController),
                  const SizedBox(height: 24),
                  _buildPasswordField(_passwordController),
                  const SizedBox(height: 24),
                  _buildConfirmPasswordField(_confirmPasswordController),
                  const SizedBox(height: 32),
                  _buildSignUpButton(),
                  const SizedBox(height: 32),
                  DividerWithText(
                    text: 'Or continue with',
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                  const SizedBox(height: 24),
                  _buildSocialButtons(),
                  const SizedBox(height: 32),
                  _buildLoginLink(context),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  BoxDecoration _buildGradientBackground(BuildContext context) {
    final twainTheme = context.twainTheme;
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: twainTheme.gradientColors,
      ),
    );
  }

  Widget _buildBackButton(BuildContext context) {
    final theme = Theme.of(context);
    return IconButton(
      icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
      onPressed: () => Navigator.pop(context),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Center(
          child: Text(
            'Create Account',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'Sign up to connect with your partner',
            style: TextStyle(
              fontSize: 16,
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorMessage(BuildContext context) {
    final twainTheme = context.twainTheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: twainTheme.destructiveBackgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: twainTheme.destructiveColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: twainTheme.destructiveColor, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(
                color: twainTheme.destructiveColor,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNameField(TextEditingController controller) {
    return LabeledTextField(
      label: 'Full Name',
      child: TextField(
        controller: controller,
        decoration: const InputDecoration(
          hintText: 'Enter your name',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
          ),
        ),
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

  Widget _buildConfirmPasswordField(TextEditingController controller) {
    return LabeledTextField(
      label: 'Confirm Password',
      child: PasswordTextField(controller: controller),
    );
  }

  Widget _buildSignUpButton() {
    return GradientButton(
      onPressed: _isLoading ? null : () => _signUpWithEmail(),
      text: _isLoading ? 'Creating account...' : 'Sign Up',
      icon: _isLoading ? null : Icons.person_add_outlined,
    );
  }

  Widget _buildSocialButtons() {
    return Column(
      children: [
        SocialLoginButton(
          onPressed: _isLoading ? null : () => _signUpWithGoogle(),
          text: 'Google',
          icon: SvgPicture.asset(
            'assets/images/google-icon.svg',
            width: 24,
            height: 24,
          ),
        ),
        if (Platform.isIOS) ...[
          const SizedBox(height: 16),
          SocialLoginButton(
            onPressed: _isLoading ? null : () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Apple Sign-In coming soon')),
              );
            },
            text: 'Apple',
            icon: SvgPicture.asset(
              'assets/images/apple-icon.svg',
              width: 24,
              height: 24,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLoginLink(BuildContext context) {
    final theme = Theme.of(context);
    final twainTheme = context.twainTheme;
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Already have an account? ',
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          GestureDetector(
            onTap: _isLoading ? null : () => Navigator.pop(context),
            child: Text(
              'Login',
              style: TextStyle(
                fontSize: 14,
                color: _isLoading
                    ? theme.colorScheme.onSurface.withOpacity(0.4)
                    : twainTheme.iconColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

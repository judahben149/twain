import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:twain/constants/app_themes.dart';
import 'package:twain/providers/auth_providers.dart';
import 'package:twain/screens/signup_screen.dart';
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

      if (mounted) {
        ref.invalidate(twainUserProvider);
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Invalid email or password';
          _isLoading = false;
        });
      }
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
        if (mounted) {
          setState(() {
            _errorMessage = 'Google sign-in was cancelled';
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          ref.invalidate(twainUserProvider);
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to sign in with Google';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final theme = Theme.of(context);

    final topSpacing = screenHeight * 0.04;
    final headerSpacing = screenHeight * 0.06;
    final fieldSpacing = screenHeight * 0.03;
    final buttonSpacing = screenHeight * 0.04;
    final horizontalPadding = screenWidth * 0.06;

    return Scaffold(
      body: Container(
        decoration: _buildGradientBackground(context),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: horizontalPadding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: topSpacing + headerSpacing),
                          _buildHeader(context),
                          SizedBox(height: fieldSpacing),
                          if (_errorMessage != null) ...[
                            _buildErrorMessage(context),
                            SizedBox(height: fieldSpacing * 0.5),
                          ],
                          _buildEmailField(_emailController),
                          SizedBox(height: fieldSpacing),
                          _buildPasswordField(_passwordController),
                          SizedBox(height: buttonSpacing),
                          _buildSignInButton(),
                          SizedBox(height: buttonSpacing),
                          DividerWithText(
                            text: 'Or continue with',
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                          ),
                          SizedBox(height: fieldSpacing),
                          _buildSocialButtons(),
                          const Spacer(),
                          _buildSignUpLink(context),
                          SizedBox(height: buttonSpacing),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
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

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Center(
          child: Text(
            'Welcome back',
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
            'Sign in to connect with your partner',
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
          Icon(Icons.error_outline,
              color: twainTheme.destructiveColor, size: 20),
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
            onPressed: _isLoading
                ? null
                : () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Apple Sign-In coming soon')),
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

  Widget _buildSignUpLink(BuildContext context) {
    final theme = Theme.of(context);
    final twainTheme = context.twainTheme;
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "Don't have an account? ",
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          GestureDetector(
            onTap: _isLoading
                ? null
                : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const SignupScreen()),
                    );
                  },
            child: Text(
              'Sign up',
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

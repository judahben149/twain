import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:twain/constants/app_themes.dart';
import 'package:twain/providers/auth_providers.dart';
import 'package:twain/screens/home_screen.dart';
import 'package:twain/widgets/buttons.dart';

class PairingScreen extends ConsumerStatefulWidget {
  const PairingScreen({super.key});

  @override
  ConsumerState<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends ConsumerState<PairingScreen> {
  bool _isGenerateMode = true;
  final _codeController = TextEditingController();
  String? _generatedCode;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _generateCode() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = ref.read(authServiceProvider);
      final code = await authService.generateInviteCode();

      setState(() {
        _generatedCode = code;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to generate code';
        _isLoading = false;
      });
    }
  }

  Future<void> _connectWithCode() async {
    final code = _codeController.text.trim().toUpperCase();

    if (code.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter an invite code';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = ref.read(authServiceProvider);
      await authService.pairWithCode(code);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _scanQRCode() async {
    final twainTheme = context.twainTheme;
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => QRScannerScreen(accentColor: twainTheme.iconColor),
      ),
    );

    if (result != null) {
      _codeController.text = result;
      _connectWithCode();
    }
  }

  void _skipToPair() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final twainTheme = context.twainTheme;

    // Listen for successful pairing (when pair_id becomes non-null)
    ref.listen(twainUserProvider, (previous, next) {
      next.whenData((user) {
        if (user?.pairId != null && mounted) {
          // Pairing successful! Navigate to home screen
          print('PairingScreen: Pairing successful, navigating to home screen');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        }
      });
    });

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
              _buildAppBar(theme),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 32),
                      _buildHeader(theme),
                      const SizedBox(height: 32),
                      _buildToggleButtons(theme, twainTheme),
                      const SizedBox(height: 48),
                      if (_errorMessage != null) ...{
                        _buildErrorMessage(twainTheme),
                        const SizedBox(height: 24),
                      },
                      _isGenerateMode
                          ? _buildGenerateMode(theme, twainTheme)
                          : _buildEnterMode(theme, twainTheme),
                      const SizedBox(height: 32),
                      _buildSkipButton(theme),
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

  Widget _buildAppBar(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Column(
      children: [
        Text(
          'Pair with Partner',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Connect with your partner to start sharing\nmoments together',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildToggleButtons(ThemeData theme, TwainThemeExtension twainTheme) {
    return Row(
      children: [
        Expanded(
          child: _buildToggleButton(
            'Generate Code',
            _isGenerateMode,
            Icons.add,
            () => setState(() => _isGenerateMode = true),
            theme,
            twainTheme,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildToggleButton(
            'Enter Code',
            !_isGenerateMode,
            Icons.camera_alt_outlined,
            () => setState(() => _isGenerateMode = false),
            theme,
            twainTheme,
          ),
        ),
      ],
    );
  }

  Widget _buildToggleButton(
    String text,
    bool isActive,
    IconData icon,
    VoidCallback onPressed,
    ThemeData theme,
    TwainThemeExtension twainTheme,
  ) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(
        icon,
        color: isActive ? Colors.white : twainTheme.iconColor,
        size: 20,
      ),
      label: Text(
        text,
        style: TextStyle(
          color: isActive ? Colors.white : twainTheme.iconColor,
          fontWeight: FontWeight.bold,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: isActive
            ? twainTheme.iconColor
            : twainTheme.cardBackgroundColor,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: twainTheme.iconColor,
            width: isActive ? 0 : 1,
          ),
        ),
      ),
    );
  }

  Widget _buildGenerateMode(ThemeData theme, TwainThemeExtension twainTheme) {
    return Column(
      children: [
        if (_generatedCode != null) ...[
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: twainTheme.cardBackgroundColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.dividerColor, width: 2),
            ),
            child: QrImageView(
              data: _generatedCode!,
              version: QrVersions.auto,
              size: 200.0,
              backgroundColor: twainTheme.cardBackgroundColor,
              eyeStyle: QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: theme.colorScheme.onSurface,
              ),
              dataModuleStyle: QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _generatedCode!,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 4,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ] else ...[
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: twainTheme.cardBackgroundColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.dividerColor,
                width: 2,
                style: BorderStyle.solid,
              ),
            ),
            child: Center(
              child: Icon(
                Icons.qr_code_2,
                size: 100,
                color: theme.colorScheme.onSurface.withOpacity(0.3),
              ),
            ),
          ),
        ],
        const SizedBox(height: 32),
        GradientButton(
          onPressed: _isLoading ? null : _generateCode,
          text: _isLoading
              ? 'Generating...'
              : (_generatedCode != null ? 'Regenerate Invite Code' : 'Generate Invite Code'),
          icon: _isLoading ? null : Icons.qr_code,
        ),
      ],
    );
  }

  Widget _buildEnterMode(ThemeData theme, TwainThemeExtension twainTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Enter Invite Code',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _codeController,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 4,
            color: theme.colorScheme.onSurface,
          ),
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            hintText: 'ABCD12',
            hintStyle: TextStyle(
              color: theme.colorScheme.onSurface.withOpacity(0.3),
              letterSpacing: 4,
            ),
            filled: true,
            fillColor: twainTheme.cardBackgroundColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.dividerColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.dividerColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: twainTheme.iconColor,
                width: 2,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        GradientButton(
          onPressed: _isLoading ? null : _connectWithCode,
          text: _isLoading ? 'Connecting...' : 'Connect',
          icon: _isLoading ? null : Icons.link,
        ),
        const SizedBox(height: 32),
        Row(
          children: [
            Expanded(child: Divider(color: theme.dividerColor)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Or',
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(child: Divider(color: theme.dividerColor)),
          ],
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isLoading ? null : _scanQRCode,
            icon: Icon(Icons.qr_code_scanner, color: twainTheme.iconColor),
            label: Text(
              'Scan QR Code',
              style: TextStyle(
                color: twainTheme.iconColor,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: BorderSide(color: twainTheme.iconColor, width: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorMessage(TwainThemeExtension twainTheme) {
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

  Widget _buildSkipButton(ThemeData theme) {
    return TextButton(
      onPressed: _skipToPair,
      child: Text(
        'Skip for now',
        style: TextStyle(
          fontSize: 14,
          color: theme.colorScheme.onSurface.withOpacity(0.5),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class QRScannerScreen extends StatefulWidget {
  final Color accentColor;

  const QRScannerScreen({super.key, required this.accentColor});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? _controller;
  bool _isProcessing = false;

  @override
  void reassemble() {
    super.reassemble();
    if (_controller != null) {
      _controller!.pauseCamera();
      _controller!.resumeCamera();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _onQRViewCreated(QRViewController controller) {
    _controller = controller;
    controller.scannedDataStream.listen((scanData) async {
      // Prevent multiple detections
      if (_isProcessing) return;

      if (scanData.code != null && !_isProcessing) {
        setState(() {
          _isProcessing = true;
        });

        // Pause the camera
        await controller.pauseCamera();

        // Pop with the result
        if (mounted) {
          Navigator.pop(context, scanData.code);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
      ),
      body: Stack(
        children: [
          QRView(
            key: qrKey,
            onQRViewCreated: _onQRViewCreated,
            overlay: QrScannerOverlayShape(
              borderColor: widget.accentColor,
              borderRadius: 10,
              borderLength: 30,
              borderWidth: 10,
              cutOutSize: 250,
            ),
          ),
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lottie/lottie.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:twain/constants/app_themes.dart';
import 'package:twain/models/distance_state.dart';
import 'package:twain/models/twain_user.dart';
import 'package:twain/providers/auth_providers.dart';
import 'package:twain/screens/sticky_notes_screen.dart';
import 'package:twain/screens/user_profile_screen.dart';
import 'package:twain/screens/partner_profile_screen.dart';
import 'package:twain/screens/pairing_screen.dart';
import 'package:twain/screens/wallpaper_screen.dart';
import 'package:twain/screens/shared_board_screen.dart';
import 'package:twain/screens/settings_screen.dart';
import 'package:twain/widgets/stable_avatar.dart';
import 'package:twain/widgets/scrolling_text.dart';
import 'package:twain/widgets/battery_optimization_dialog.dart';
import 'package:twain/widgets/location_permission_dialog.dart';
import 'package:twain/providers/location_providers.dart';
import 'package:twain/services/location_service.dart';
import 'package:twain/services/app_tour_service.dart';
import 'package:twain/widgets/distance_meter_widget.dart';
import 'package:twain/widgets/directional_dots.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  bool _hasCheckedBatteryOptimization = false;
  bool _hasCheckedLocationPermission = false;
  bool _hasCheckedTour = false;
  bool _showPairingPrompt = false;
  bool _hasShownPairingPrompt = false;
  bool _hasInitializedPreferences = false;
  bool _hasPendingTourCheck = false;
  String? _lastPairId;

  String? _normalizePairId(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    return value;
  }

  bool _isPaired(TwainUser? user) => _normalizePairId(user?.pairId) != null;

  Timer? _locationUpdateTimer;
  ProviderSubscription<AsyncValue<TwainUser?>>? _userSubscription;
  ProviderSubscription<AsyncValue<bool>>? _distanceFeatureSubscription;

  // Tour keys
  final GlobalKey _settingsKey = GlobalKey();
  final GlobalKey _userAvatarKey = GlobalKey();
  final GlobalKey _partnerAvatarKey = GlobalKey();
  final GlobalKey _stickyNotesKey = GlobalKey();
  final GlobalKey _wallpaperKey = GlobalKey();

  final AppTourService _appTourService = AppTourService();
  TutorialCoachMark? _tutorialCoachMark;
  bool _isTourActive = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize from current user if data is already available
    final currentUserAsync = ref.read(twainUserProvider);
    currentUserAsync.whenOrNull(
      data: (user) {
        _initializePreferencesFromUser(user);
      },
    );

    _userSubscription = ref.listenManual<AsyncValue<TwainUser?>>(
      twainUserProvider,
      (previous, next) {
        if (next is! AsyncData<TwainUser?>) return;

        final user = next.value;

        // Initialize preferences on first data load
        if (!_hasInitializedPreferences && user != null) {
          _initializePreferencesFromUser(user);
        }

        final nextPairId = _normalizePairId(user?.pairId);
        final isPaired = nextPairId != null;

        final hasPairChanged = nextPairId != _lastPairId;
        if (hasPairChanged) {
          if (isPaired) {
            _hasCheckedLocationPermission = false;
            _postFrame(_scheduleLocationSync);
          } else {
            _stopLocationUpdates();
            _hasCheckedLocationPermission = false;
          }
        }

        // TODO: Re-enable tour and pairing prompt later
        // Tour and pairing prompt disabled for now - will fix later

        _lastPairId = nextPairId;
      },
      fireImmediately: false,
    );

    _distanceFeatureSubscription = ref.listenManual<AsyncValue<bool>>(
      distanceFeatureProvider,
      (previous, next) {
        final enabled =
            next.maybeWhen(data: (value) => value, orElse: () => false);
        if (enabled) {
          _hasCheckedLocationPermission = false;
          _postFrame(_scheduleLocationSync);
        } else {
          _stopLocationUpdates();
          _hasCheckedLocationPermission = false;
        }
      },
      fireImmediately: false,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _evaluateInitialLocationCheck();

      // Handle initial state after first frame
      final currentUser = ref.read(twainUserProvider).value;
      if (currentUser != null && !_hasInitializedPreferences) {
        _initializePreferencesFromUser(currentUser);
      }

      // TODO: Re-enable tour and pairing prompt later
      // Tour and pairing prompt disabled for now - will fix later
    });
  }

  void _initializePreferencesFromUser(TwainUser? user) {
    if (_hasInitializedPreferences) return;
    _hasInitializedPreferences = true;

    _lastPairId = _normalizePairId(user?.pairId);
    final hasSeenPrompt =
        user?.preferences?['has_seen_pairing_prompt'] as bool? ?? false;
    _hasShownPairingPrompt = hasSeenPrompt;

    // Schedule location sync if paired
    if (_lastPairId != null) {
      _postFrame(_scheduleLocationSync);
    }
  }

  void _scheduleTourCheck() {
    // Prevent multiple pending tour checks
    if (_hasPendingTourCheck) return;
    _hasPendingTourCheck = true;
    _postFrame(() {
      _hasPendingTourCheck = false;
      _checkAndShowTour(isPaired: true);
    });
  }

  void _maybeShowPairingPrompt(TwainUser? user) {
    if (_isPaired(user) || _hasShownPairingPrompt) return;
    _showPairingPromptOverlay();
  }

  void _showPairingPromptOverlay() {
    if (!mounted) return;
    setState(() {
      _showPairingPrompt = true;
      _hasShownPairingPrompt = true;
      _updatePromptPreference(true);
    });
  }

  void _dismissPairingPrompt() {
    if (!mounted || !_showPairingPrompt) return;
    setState(() {
      _showPairingPrompt = false;
    });
    _updatePromptPreference(true);
  }

  void _updatePromptPreference(bool value) {
    final user = ref.read(twainUserProvider).value;
    if (user == null) return;
    final preferences = Map<String, dynamic>.from(user.preferences ?? {});
    if (preferences['has_seen_pairing_prompt'] == value) return;
    preferences['has_seen_pairing_prompt'] = value;
    ref.read(authServiceProvider).updateUserPreferences(preferences);
  }

  Future<void> _checkAndShowTour({required bool isPaired}) async {
    if (!isPaired) {
      return;
    }
    // Double-check both flags to prevent any race condition
    if (_hasCheckedTour || _isTourActive) return;
    _hasCheckedTour = true;

    final hasCompletedTour = await _appTourService.hasCompletedTour();
    if (!hasCompletedTour && mounted && !_isTourActive) {
      // Small delay to let the UI settle
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted && !_isTourActive) {
        _showTour();
      }
    }
  }

  void _showTour() {
    // Final guard - ensure tour isn't already active
    if (_isTourActive) {
      debugPrint('Tour already active, skipping');
      return;
    }
    _isTourActive = true;

    // Dismiss any existing tutorial overlay
    _tutorialCoachMark?.finish();
    _tutorialCoachMark = null;

    final twainTheme = context.twainTheme;
    final targets = _createTourTargets(twainTheme);
    _showSequentialTour(targets, 0);
  }

  void _showSequentialTour(List<TargetFocus> targets, int index) {
    if (!mounted) {
      // Widget disposed - don't mark as completed, user didn't finish
      _isTourActive = false;
      return;
    }
    if (index >= targets.length) {
      // All targets shown - mark as completed
      _isTourActive = false;
      _appTourService.markTourCompleted();
      return;
    }

    var skipCalled = false;

    _tutorialCoachMark = TutorialCoachMark(
      targets: [targets[index]],
      colorShadow: Colors.black,
      opacityShadow: 0.8,
      paddingFocus: 10,
      hideSkip: false,
      skipWidget: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          'Skip Tour',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      onFinish: () {
        if (skipCalled) return;
        _tutorialCoachMark = null;
        if (index + 1 < targets.length) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Future.delayed(const Duration(milliseconds: 80), () {
              _showSequentialTour(targets, index + 1);
            });
          });
        } else {
          _isTourActive = false;
          _appTourService.markTourCompleted();
        }
      },
      onSkip: () {
        skipCalled = true;
        _tutorialCoachMark = null;
        _isTourActive = false;
        _appTourService.markTourCompleted();
        return true;
      },
    );

    _tutorialCoachMark!.show(context: context);
  }

  List<TargetFocus> _createTourTargets(TwainThemeExtension twainTheme) {
    return [
      TargetFocus(
        identify: 'settings',
        keyTarget: _settingsKey,
        alignSkip: Alignment.bottomRight,
        shape: ShapeLightFocus.RRect,
        radius: 12,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return _buildTourContent(
                icon: Icons.settings_outlined,
                title: 'Settings',
                description:
                    'Tap the Twain logo to access settings, manage your subscription, and customize your experience.',
                twainTheme: twainTheme,
              );
            },
          ),
        ],
      ),
      TargetFocus(
        identify: 'user_avatar',
        keyTarget: _userAvatarKey,
        alignSkip: Alignment.bottomRight,
        shape: ShapeLightFocus.Circle,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return _buildTourContent(
                icon: Icons.person,
                title: 'Your Profile',
                description:
                    'Tap here to view and edit your profile, change your avatar, and set a nickname.',
                twainTheme: twainTheme,
              );
            },
          ),
        ],
      ),
      TargetFocus(
        identify: 'partner_avatar',
        keyTarget: _partnerAvatarKey,
        alignSkip: Alignment.bottomRight,
        shape: ShapeLightFocus.Circle,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return _buildTourContent(
                icon: Icons.favorite,
                title: "Your Partner's Profile",
                description:
                    "See your partner's profile here. You can choose to display their nickname instead of their name.",
                twainTheme: twainTheme,
              );
            },
          ),
        ],
      ),
      TargetFocus(
        identify: 'wallpaper',
        keyTarget: _wallpaperKey,
        alignSkip: Alignment.bottomRight,
        shape: ShapeLightFocus.RRect,
        radius: 20,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return _buildTourContent(
                icon: Icons.wallpaper_outlined,
                title: 'Sync Wallpapers',
                description:
                    'Set matching wallpapers with your partner. Both of you will have the same beautiful background.',
                twainTheme: twainTheme,
              );
            },
          ),
        ],
      ),
      TargetFocus(
        identify: 'sticky_notes',
        keyTarget: _stickyNotesKey,
        alignSkip: Alignment.topRight,
        shape: ShapeLightFocus.RRect,
        radius: 20,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return _buildTourContent(
                icon: Icons.sticky_note_2_outlined,
                title: 'Sticky Notes',
                description:
                    'Leave sweet messages for your partner. Colorful notes to brighten their day!',
                twainTheme: twainTheme,
              );
            },
          ),
        ],
      ),
    ];
  }

  Widget _buildTourContent({
    required IconData icon,
    required String title,
    required String description,
    required TwainThemeExtension twainTheme,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: twainTheme.iconColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: TextStyle(
              fontSize: 15,
              color: Colors.white.withOpacity(0.9),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkBatteryOptimization();
  }

  Future<void> _checkBatteryOptimization() async {
    if (_hasCheckedBatteryOptimization) return;
    _hasCheckedBatteryOptimization = true;

    // Wait for the screen to be fully built
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    // Only show if user is paired (uses wallpaper sync feature)
    final currentUser = ref.read(twainUserProvider).value;
    if (currentUser?.pairId == null) return;

    // Show the dialog if needed
    await BatteryOptimizationDialog.show(context);
  }

  void _scheduleLocationSync() {
    if (_hasCheckedLocationPermission) return;
    ref.invalidate(locationFeatureAvailabilityProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _hasCheckedLocationPermission) return;
      _hasCheckedLocationPermission = true;
      await _ensureLocationSync();
    });
  }

  void _evaluateInitialLocationCheck() {
    final user = ref.read(twainUserProvider).value;
    final featureEnabled = ref.read(distanceFeatureProvider).maybeWhen(
          data: (value) => value,
          orElse: () => false,
        );
    if (user?.pairId != null && featureEnabled) {
      _scheduleLocationSync();
    }
  }

  Future<void> _ensureLocationSync() async {
    final featureEnabled = ref.read(distanceFeatureProvider).maybeWhen(
          data: (value) => value,
          orElse: () => false,
        );
    if (!featureEnabled) {
      _hasCheckedLocationPermission = false;
      return;
    }

    final user = ref.read(twainUserProvider).value;
    if (user?.pairId == null) {
      _hasCheckedLocationPermission = false;
      return;
    }

    final status = await LocationService.checkPermission();
    if (!status.isGranted) {
      // Show location permission dialog if not granted
      if (mounted) {
        final result = await LocationPermissionDialog.show(context);
        if (result == true) {
          // Permission granted, continue with location sync
          await _syncCurrentLocation();
          _startLocationUpdates();
          return;
        }
      }
      _stopLocationUpdates();
      _hasCheckedLocationPermission = false;
      return;
    }

    final isEnabled = await LocationService.isLocationEnabled();
    if (!isEnabled) {
      _stopLocationUpdates();
      _hasCheckedLocationPermission = false;
      return;
    }

    await _syncCurrentLocation();
    _startLocationUpdates();
  }

  Future<void> _syncCurrentLocation() async {
    final featureEnabled = ref.read(distanceFeatureProvider).maybeWhen(
          data: (value) => value,
          orElse: () => false,
        );
    if (!featureEnabled) {
      return;
    }

    final userAsync = ref.read(twainUserProvider);
    final user = userAsync.value;
    if (user == null || user.pairId == null) {
      _stopLocationUpdates();
      return;
    }

    final status = await LocationService.checkPermission();
    if (!status.isGranted) {
      _stopLocationUpdates();
      return;
    }

    final enabled = await LocationService.isLocationEnabled();
    if (!enabled) return;

    final reading = await LocationService.getCurrentLocation();
    if (reading == null) return;

    final repository = ref.read(locationRepositoryProvider);
    try {
      await repository.updateLocation(
        userId: user.id,
        pairId: user.pairId!,
        reading: reading,
      );
    } catch (error) {
      debugPrint('HomeScreen: Failed to sync location -> $error');
    }
  }

  void _startLocationUpdates() {
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      unawaited(_syncCurrentLocation());
    });
    unawaited(_syncCurrentLocation());
  }

  void _stopLocationUpdates() {
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final user = ref.read(twainUserProvider).value;
      if (user?.pairId != null) {
        if (_locationUpdateTimer == null) {
          _hasCheckedLocationPermission = false;
          _postFrame(_scheduleLocationSync);
        } else {
          unawaited(_syncCurrentLocation());
        }
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _locationUpdateTimer?.cancel();
    _userSubscription?.close();
    _distanceFeatureSubscription?.close();
    super.dispose();
  }

  void _postFrame(VoidCallback callback) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      callback();
    });
  }

  void _handleFeatureTap({
    required BuildContext context,
    required bool isPaired,
    required VoidCallback onPaired,
  }) {
    if (isPaired) {
      onPaired();
    } else {
      final twainTheme = context.twainTheme;
      ScaffoldMessenger.of(context).clearSnackBars();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.lock_outline, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Connect with your partner to unlock this feature',
                  style: TextStyle(fontSize: 15),
                ),
              ),
            ],
          ),
          backgroundColor: twainTheme.iconColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Get Paired',
            textColor: Colors.white,
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PairingScreen(),
                ),
              );
            },
          ),
          dismissDirection: DismissDirection.horizontal,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(twainUserProvider).value;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: _buildGradientBackground(context),
            child: SafeArea(
              child: Column(
                children: [
                  _buildHeader(context),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        children: [
                          const SizedBox(height: 24),
                          _buildConnectionCard(context, currentUser),
                          const SizedBox(height: 32),
                          Container(
                            key: _wallpaperKey,
                            child: _buildFeatureCard(
                              context: context,
                              icon: Icons.wallpaper_outlined,
                              title: 'Wallpaper',
                              subtitle: 'Sync your home screens',
                              colors: const [
                                Color(0xFFE8D5F2),
                                Color(0xFFFCE4EC),
                              ],
                              onTap: () => _handleFeatureTap(
                                context: context,
                                isPaired: currentUser?.pairId != null,
                                onPaired: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const WallpaperScreen(),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildFeatureCard(
                            context: context,
                            icon: Icons.photo_library_outlined,
                            title: 'Shared Board',
                            subtitle: 'Photos & memories',
                            colors: const [
                              Color(0xFFE3F2FD),
                              Color(0xFFFFF9C4),
                              Color(0xFFC8E6C9),
                            ],
                            onTap: () => _handleFeatureTap(
                              context: context,
                              isPaired: currentUser?.pairId != null,
                              onPaired: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const SharedBoardScreen(),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            key: _stickyNotesKey,
                            child: _buildFeatureCard(
                              context: context,
                              icon: Icons.sticky_note_2_outlined,
                              title: 'Sticky Notes',
                              subtitle: 'Leave sweet messages',
                              colors: const [
                                Color(0xFFFFF9C4),
                                Color(0xFFFCE4EC),
                                Color(0xFFE1BEE7),
                              ],
                              onTap: () => _handleFeatureTap(
                                context: context,
                                isPaired: currentUser?.pairId != null,
                                onPaired: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const StickyNotesScreen(),
                                    ),
                                  );
                                },
                              ),
                            ),
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
          // TODO: Re-enable love popper pairing prompt later
          // Love popper disabled for now - will fix later
          // if (_showPairingPrompt) ...
        ],
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
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        children: [
          GestureDetector(
            key: _settingsKey,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
            },
            child: Row(
              children: [
                ClipOval(
                  child: SvgPicture.asset(
                    'assets/images/logo_twain_circular.svg',
                    width: 44,
                    height: 44,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Twain',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildConnectionCard(BuildContext context, dynamic currentUser) {
    final isPaired = currentUser?.pairId != null;
    final pairedUserAsync = ref.watch(pairedUserProvider);
    final twainTheme = context.twainTheme;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: twainTheme.cardBackgroundColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: context.isDarkMode
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
        border: context.isDarkMode
            ? Border.all(color: theme.dividerColor, width: 0.5)
            : null,
      ),
      child: isPaired
          ? _buildPairedContent(context, currentUser, pairedUserAsync)
          : _buildUnpairedContent(context, currentUser),
    );
  }

  Widget _buildPairedContent(BuildContext context, dynamic currentUser,
      AsyncValue<dynamic> pairedUserAsync) {
    final theme = Theme.of(context);
    final twainTheme = context.twainTheme;
    return Column(
      children: [
        Text(
          'Connected with',
          style: TextStyle(
            fontSize: 16,
            color: theme.colorScheme.onSurface.withOpacity(0.6),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 24),
        _buildConnectionRow(
          context: context,
          currentUser: currentUser,
          pairedUserAsync: pairedUserAsync,
        ),
        const SizedBox(height: 20),
        pairedUserAsync.when(
          data: (partner) => partner != null
              ? _buildPresenceBadge(context, partner)
              : _buildPresencePlaceholder(context),
          loading: () => SizedBox(
            height: 24,
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(twainTheme.iconColor),
              ),
            ),
          ),
          error: (_, __) => _buildPresenceError(context),
        ),
      ],
    );
  }

  Widget _buildConnectionRow({
    required BuildContext context,
    required dynamic currentUser,
    required AsyncValue<dynamic> pairedUserAsync,
  }) {
    final featureEnabled = ref.watch(distanceFeatureProvider).maybeWhen(
          data: (value) => value,
          orElse: () => false,
        );
    final locationAvailable =
        ref.watch(locationFeatureAvailabilityProvider).maybeWhen(
              data: (value) => value,
              orElse: () => false,
            );
    final distanceState = ref.watch(distanceStateProvider);

    final shouldShowDistance = featureEnabled &&
        locationAvailable &&
        distanceState.status != DistanceStatus.hidden;

    final userAvatar = Container(
      key: _userAvatarKey,
      child: currentUser != null
          ? _buildAvatarWithTwainAvatar(
              context: context,
              user: currentUser,
              name: 'You',
              color: AppThemes.appAccentColor,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => UserProfileScreen(user: currentUser),
                  ),
                );
              },
            )
          : _buildAvatar(
              context: context,
              label: 'YO',
              name: 'You',
              color: AppThemes.appAccentColor,
              onTap: null,
            ),
    );

    final partnerDisplayName = ref.watch(partnerDisplayNameProvider);
    final partnerAvatar = Container(
      key: _partnerAvatarKey,
      child: pairedUserAsync.when(
        data: (partner) => partner != null
            ? _buildAvatarWithTwainAvatar(
                context: context,
                user: partner,
                name: partnerDisplayName ?? partner.displayName,
                color: const Color(0xFFE91E63),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          PartnerProfileScreen(partner: partner),
                    ),
                  );
                },
              )
            : _buildAvatar(
                context: context,
                label: 'PA',
                name: 'Partner',
                color: const Color(0xFFE91E63),
                onTap: null,
              ),
        loading: () => SizedBox(
          width: 80,
          height: 80,
          child: Center(
            child: CircularProgressIndicator(
              color: context.twainTheme.iconColor,
            ),
          ),
        ),
        error: (_, __) => _buildAvatar(
          context: context,
          label: 'PA',
          name: 'Partner',
          color: const Color(0xFFE91E63),
          onTap: null,
        ),
      ),
    );

    final Widget centerWidget = shouldShowDistance
        ? const DistanceMeterWidget()
        : _buildThreeDots(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        _wrapAvatarWithIndicator(
          avatar: userAvatar,
          isLeft: true,
          showIndicator: shouldShowDistance,
        ),
        centerWidget,
        _wrapAvatarWithIndicator(
          avatar: partnerAvatar,
          isLeft: false,
          showIndicator: shouldShowDistance,
        ),
      ],
    );
  }

  Widget _buildUnpairedContent(BuildContext context, dynamic currentUser) {
    final theme = Theme.of(context);
    final twainTheme = context.twainTheme;
    return Column(
      children: [
        Icon(
          Icons.favorite_border,
          size: 60,
          color: theme.colorScheme.onSurface.withOpacity(0.4),
        ),
        const SizedBox(height: 16),
        Text(
          'Not Connected',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Connect with your partner to unlock all features',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const PairingScreen(),
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: twainTheme.iconColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 2,
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.link, size: 20),
              SizedBox(width: 8),
              Text(
                'Get Paired',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarWithTwainAvatar({
    required BuildContext context,
    required TwainUser user,
    required String name,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: StableTwainAvatar(
              user: user,
              size: 80,
              color: color,
              showBorder: true,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 80,
            child: ScrollingText(
              text: name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar({
    required BuildContext context,
    required String label,
    required String name,
    required Color color,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Column(
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
          SizedBox(
            width: 80,
            child: ScrollingText(
              text: name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _wrapAvatarWithIndicator({
    required Widget avatar,
    required bool isLeft,
    required bool showIndicator,
  }) {
    final base = SizedBox(
      width: 80,
      child: avatar,
    );

    if (!showIndicator) return base;

    return SizedBox(
      width: 88,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          base,
          Align(
            alignment: isLeft ? Alignment.centerLeft : Alignment.centerRight,
            child: Transform.translate(
              offset: Offset(isLeft ? -24 : 24, -10),
              child: DirectionalDots(isLeftSide: isLeft),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresenceBadge(BuildContext context, TwainUser partner) {
    final twainTheme = context.twainTheme;
    final status = (partner.status ?? '').toLowerCase();
    final lastActive = partner.lastActiveAt ?? partner.updatedAt;
    final now = DateTime.now();
    final minutesSinceActive =
        now.isAfter(lastActive) ? now.difference(lastActive).inMinutes : 0;

    Color color;
    String text;

    if (status == 'online') {
      color = const Color(0xFFE91E63);
      text = 'Online now';
    } else {
      color = minutesSinceActive <= 59
          ? twainTheme.iconColor
          : Theme.of(context).colorScheme.onSurface.withOpacity(0.6);
      text = 'Last active: ${_formatRelativeTime(lastActive)}';
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildThreeDots(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        3,
        (index) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: theme.dividerColor,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  Widget _buildPresencePlaceholder(BuildContext context) {
    return Text(
      'Status unavailable',
      style: TextStyle(
        fontSize: 14,
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
      ),
    );
  }

  Widget _buildPresenceError(BuildContext context) {
    return Text(
      'Status unavailable',
      style: TextStyle(
        fontSize: 14,
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
      ),
    );
  }

  String _formatRelativeTime(DateTime timestamp) {
    final now = DateTime.now();
    if (timestamp.isAfter(now)) return 'just now';

    final diff = now.difference(timestamp);

    if (diff.inMinutes < 1) {
      return 'just now';
    } else if (diff.inMinutes < 60) {
      final minutes = diff.inMinutes;
      return '$minutes min${minutes == 1 ? '' : 's'} ago';
    } else if (diff.inHours < 24) {
      final hours = diff.inHours;
      return '$hours hour${hours == 1 ? '' : 's'} ago';
    } else {
      final days = diff.inDays;
      return '$days day${days == 1 ? '' : 's'} ago';
    }
  }

  Widget _buildFeatureCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> colors,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final twainTheme = context.twainTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: twainTheme.cardBackgroundColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: context.isDarkMode
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 15,
                    offset: const Offset(0, 2),
                  ),
                ],
          border: context.isDarkMode
              ? Border.all(color: theme.dividerColor, width: 0.5)
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: twainTheme.iconBackgroundColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: twainTheme.iconColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
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

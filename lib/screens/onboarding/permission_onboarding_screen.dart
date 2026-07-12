import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme.dart';
import '../auth/login_screen.dart';
import '../../widgets/custom_permission_popup.dart';

class PermissionOnboardingScreen extends StatefulWidget {
  const PermissionOnboardingScreen({Key? key}) : super(key: key);

  @override
  State<PermissionOnboardingScreen> createState() =>
      _PermissionOnboardingScreenState();
}

class _PermissionOnboardingScreenState
    extends State<PermissionOnboardingScreen> with TickerProviderStateMixin {
  late AnimationController _headerController;
  late AnimationController _cardsController;
  late Animation<double> _headerFade;
  late Animation<Offset> _headerSlide;
  late Animation<double> _cardsFade;

  final Map<String, PermissionStatus> _statuses = {};
  bool _isLoading = false;

  final List<_PermissionItem> _permissions = [
    _PermissionItem(
      permission: Permission.microphone,
      icon: Icons.mic_rounded,
      title: 'Microphone',
      description: 'Join and host voice rooms, speak in communities',
      gradientColors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
      isRequired: true,
    ),
    _PermissionItem(
      permission: Permission.camera,
      icon: Icons.camera_alt_rounded,
      title: 'Camera',
      description: 'Enable video during voice calls and profile photos',
      gradientColors: [Color(0xFF0EA5E9), Color(0xFF6366F1)],
      isRequired: false,
    ),
    _PermissionItem(
      permission: Permission.notification,
      icon: Icons.notifications_rounded,
      title: 'Notifications',
      description: 'Get alerts for replies, mentions and live rooms',
      gradientColors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
      isRequired: false,
    ),
    _PermissionItem(
      permission: Permission.storage,
      icon: Icons.photo_library_rounded,
      title: 'Media & Storage',
      description: 'Upload photos and media to your posts and profile',
      gradientColors: [Color(0xFF10B981), Color(0xFF059669)],
      isRequired: false,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _headerController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _cardsController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );

    _headerFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _headerController, curve: Curves.easeOut),
    );
    _headerSlide = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _headerController, curve: Curves.easeOut),
    );
    _cardsFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _cardsController, curve: Curves.easeOut),
    );

    _headerController.forward().then((_) => _cardsController.forward());
    _checkCurrentStatuses();
  }

  Future<void> _checkCurrentStatuses() async {
    for (final item in _permissions) {
      try {
        final status = await item.permission.status;
        if (mounted) {
          setState(() => _statuses[item.title] = status);
        }
      } catch (_) {}
    }
  }

  Future<void> _requestPermission(_PermissionItem item) async {
    final bool? proceed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => CustomPermissionPopup(
        title: item.title,
        description: item.description,
        icon: item.icon,
        gradientColors: item.gradientColors,
      ),
    );

    if (proceed == true) {
      try {
        final status = await item.permission.request();
        if (mounted) {
          setState(() => _statuses[item.title] = status);
        }
      } catch (_) {}
    }
  }

  bool get _canContinue {
    final micStatus = _statuses['Microphone'];
    return micStatus != null && micStatus.isGranted;
  }

  Future<void> _continue() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('firstLaunchDone', true);
    } catch (_) {}
    Get.offAll(() => const LoginScreen());
  }

  @override
  void dispose() {
    _headerController.dispose();
    _cardsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.5,
            colors: [
              AppTheme.primaryColor.withOpacity(0.08),
              AppTheme.bgDark,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 36),
                // Header
                FadeTransition(
                  opacity: _headerFade,
                  child: SlideTransition(
                    position: _headerSlide,
                    child: _buildHeader(context),
                  ),
                ),
                const SizedBox(height: 36),
                // Permission Cards
                Expanded(
                  child: FadeTransition(
                    opacity: _cardsFade,
                    child: ListView.separated(
                      itemCount: _permissions.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = _permissions[index];
                        final status = _statuses[item.title];
                        return _buildPermissionCard(context, item, status, index);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Skip text
                if (!_canContinue)
                  TextButton(
                    onPressed: _isLoading ? null : _continue,
                    child: Text(
                      'Skip for now',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textTertiary,
                          ),
                    ),
                  ),
                const SizedBox(height: 8),
                // Continue Button
                _buildContinueButton(context),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      children: [
        // Glowing logo
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withOpacity(0.5),
                blurRadius: 30,
                spreadRadius: 2,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.record_voice_over_rounded,
            size: 44,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 22),
        Text(
          'Set Up Creania',
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 28,
              ),
        ),
        const SizedBox(height: 10),
        Text(
          'Grant a few permissions to unlock\nall features and the best experience',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textTertiary,
                height: 1.6,
              ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildPermissionCard(
    BuildContext context,
    _PermissionItem item,
    PermissionStatus? status,
    int index,
  ) {
    final isGranted = status?.isGranted ?? false;
    final isPermanentlyDenied = status?.isPermanentlyDenied ?? false;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: isGranted
            ? AppTheme.accentColor.withOpacity(0.05)
            : AppTheme.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isGranted
              ? AppTheme.accentColor.withOpacity(0.5)
              : AppTheme.borderColor.withOpacity(0.6),
          width: isGranted ? 1.5 : 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: isGranted
                ? AppTheme.accentColor.withOpacity(0.08)
                : Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Icon container
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isGranted
                    ? [AppTheme.accentColor, const Color(0xFF059669)]
                    : item.gradientColors,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: (isGranted
                          ? AppTheme.accentColor
                          : item.gradientColors[0])
                      .withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              isGranted ? Icons.check_rounded : item.icon,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          // Text content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                      ),
                    ),
                    if (item.isRequired) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.errorColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          'Required',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppTheme.errorColor,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  item.description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textTertiary,
                        height: 1.4,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Action button
          if (isGranted)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.accentColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Granted',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.accentColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
              ),
            )
          else if (isPermanentlyDenied)
            GestureDetector(
              onTap: () => openAppSettings(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Settings',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.errorColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                ),
              ),
            )
          else
            GestureDetector(
              onTap: () => _requestPermission(item),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: item.gradientColors,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: item.gradientColors[0].withOpacity(0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Text(
                  'Allow',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContinueButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : (_canContinue ? _continue : null),
        style: ElevatedButton.styleFrom(
          backgroundColor: _canContinue
              ? AppTheme.primaryColor
              : AppTheme.primaryColor.withOpacity(0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: _canContinue ? 8 : 0,
          shadowColor: AppTheme.primaryColor.withOpacity(0.5),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Text(
                _canContinue
                    ? 'Get Started 🚀'
                    : 'Allow Microphone to Continue',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
              ),
      ),
    );
  }
}

class _PermissionItem {
  const _PermissionItem({
    required this.permission,
    required this.icon,
    required this.title,
    required this.description,
    required this.gradientColors,
    this.isRequired = false,
  });

  final Permission permission;
  final IconData icon;
  final String title;
  final String description;
  final List<Color> gradientColors;
  final bool isRequired;
}

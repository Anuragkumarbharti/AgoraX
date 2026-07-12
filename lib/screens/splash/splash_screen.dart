import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';
import '../onboarding/onboarding_screen.dart';
import '../auth/login_screen.dart';
import '../home/main_screen.dart';
import '../../services/user_profile_cache_manager.dart';
import '../../services/user_progress_sync_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _particleController;
  late Animation<double> _logoScale;
  late Animation<double> _textFade;
  late List<Particle> _particles;

  @override
  void initState() {
    super.initState();
    
    // Core animation controller
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _logoScale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );

    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: const Interval(0.4, 1.0, curve: Curves.easeIn),
      ),
    );

    // Particle animation controller
    _particleController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();

    _particles = List.generate(40, (index) => Particle());

    _fadeController.forward();
    _navigateToNextScreen();
  }

  void _navigateToNextScreen() {
    // Splash screen duration: 2.8 seconds
    Future.delayed(const Duration(milliseconds: 2800), () async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final firstLaunchDone = prefs.getBool('firstLaunchDone') ?? false;
        final isLoggedIn = Supabase.instance.client.auth.currentSession != null;

        if (!firstLaunchDone) {
          Get.offAll(() => const OnboardingScreen());
        } else if (isLoggedIn) {
          try {
            await UserProfileCacheManager.getOrFetchCanonicalId();
            await UserProfileCacheManager.fetchUserProfile('me', forceRefresh: true);
            await UserProgressSyncService.syncFromSupabase();
          } catch (_) {}
          Get.offAll(() => const MainScreen());
        } else {
          Get.offAll(() => const LoginScreen());
        }
      } catch (_) {
        Get.offAll(() => const LoginScreen());
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: Stack(
        children: [
          // 1. Subtle Animated Gradient Background
          AnimatedBuilder(
            animation: _particleController,
            builder: (context, child) {
              return Container(
                width: size.width,
                height: size.height,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.bgDark,
                      Color.lerp(
                        AppTheme.bgDark,
                        const Color(0xFF1E1B4B),
                        0.4 + 0.1 * sin(_particleController.value * 2 * pi),
                      )!,
                      Color.lerp(
                        AppTheme.bgDark,
                        const Color(0xFF311B92),
                        0.2 + 0.1 * cos(_particleController.value * 2 * pi),
                      )!,
                    ],
                  ),
                ),
              );
            },
          ),

          // 2. Floating Particles Canvas
          AnimatedBuilder(
            animation: _particleController,
            builder: (context, child) {
              // Update particles
              for (var p in _particles) {
                p.update();
              }
              return CustomPaint(
                size: size,
                painter: ParticlePainter(particles: _particles),
              );
            },
          ),

          // 3. Center Branding
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated Creania Logo
                ScaleTransition(
                  scale: _logoScale,
                  child: FadeTransition(
                    opacity: _fadeController,
                    child: Container(
                      width: 130,
                      height: 130,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppTheme.primaryColor,
                            AppTheme.secondaryColor,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withOpacity(0.3),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(32),
                        child: Image.asset(
                          'assets/images/logo.png',
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Center(
                              child: Text(
                                'C',
                                style: GoogleFonts.outfit(
                                  fontSize: 64,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Title, Tagline and Subtitle
                FadeTransition(
                  opacity: _textFade,
                  child: Column(
                    children: [
                      Text(
                        'Creania',
                        style: GoogleFonts.outfit(
                          fontSize: 40,
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Tagline
                      Text(
                        'Create. Connect. Grow.',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: AppTheme.accentColor,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2.0,
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Subtitle
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          'Knowledge  •  Careers  •  Communities\nEvents  •  Voice Rooms  •  Creators',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: AppTheme.textSecondary.withOpacity(0.7),
                            fontWeight: FontWeight.w500,
                            height: 1.8,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Particle Helper
class Particle {
  double x = Random().nextDouble();
  double y = Random().nextDouble();
  double size = Random().nextDouble() * 3 + 1;
  double speed = Random().nextDouble() * 0.001 + 0.0003;
  double opacity = Random().nextDouble() * 0.4 + 0.1;

  void update() {
    y -= speed;
    if (y < 0) {
      y = 1.0;
      x = Random().nextDouble();
    }
  }
}

// Particle Painter
class ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  ParticlePainter({required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (var p in particles) {
      paint.color = Colors.white.withOpacity(p.opacity);
      canvas.drawCircle(
        Offset(p.x * size.width, p.y * size.height),
        p.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

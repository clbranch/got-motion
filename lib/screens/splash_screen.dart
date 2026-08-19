import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../widgets/motion_logo.dart';

/// Full-screen branded launch state shown while the app boots.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  static const Color backgroundTop = Color(0xFF1E5AA6);
  static const Color backgroundMid = Color(0xFF0B2A57);
  static const Color backgroundBottom = Color(0xFF07090F);
  static const Color loader = Color(0xFF238BFF);
  static const Color tagline = Color(0xFFA9B8C9);

  static const field = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [backgroundTop, backgroundMid, backgroundBottom],
    stops: [0.0, 0.52, 1.0],
  );

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  Widget _stagger({
    required double start,
    required double end,
    required Widget child,
  }) {
    final animation = CurvedAnimation(
      parent: _entrance,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: animation,
      builder: (context, inner) => Opacity(
        opacity: animation.value,
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - animation.value)),
          child: inner,
        ),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final logoSize = math.min(168.0, size.shortestSide * 0.36);
    final titleSize = size.shortestSide < 360 ? 34.0 : 40.0;
    final logoScale = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0, 0.55, curve: Curves.easeOutCubic),
    );

    return Scaffold(
      backgroundColor: SplashScreen.backgroundBottom,
      body: SizedBox.expand(
        child: DecoratedBox(
          decoration: const BoxDecoration(gradient: SplashScreen.field),
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.15,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  children: [
                    const Spacer(flex: 5),
                    AnimatedBuilder(
                      animation: logoScale,
                      builder: (context, child) => Opacity(
                        opacity: logoScale.value,
                        child: Transform.scale(
                          scale: 0.94 + 0.06 * logoScale.value,
                          child: child,
                        ),
                      ),
                      child: MotionLogo(size: logoSize),
                    ),
                    SizedBox(height: size.height < 700 ? 22 : 28),
                    _stagger(
                      start: 0.22,
                      end: 0.7,
                      child: Text(
                        'Got Motion',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: titleSize,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.6,
                          height: 1.05,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _stagger(
                      start: 0.38,
                      end: 0.85,
                      child: const Text(
                        'Stay in motion.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w500,
                          color: SplashScreen.tagline,
                          height: 1.3,
                        ),
                      ),
                    ),
                    const Spacer(flex: 8),
                    _stagger(
                      start: 0.55,
                      end: 1,
                      child: const Column(
                        children: [
                          SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              valueColor: AlwaysStoppedAnimation(
                                SplashScreen.loader,
                              ),
                            ),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Getting things moving…',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF8FA3B8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

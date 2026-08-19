import 'package:flutter/material.dart';

/// Shared dark-blue field used behind the ribbon M.
///
/// A diagonal navy wash plus a cyan bloom — never a flat fill — so the mark
/// reads as lit from inside rather than stuck on a solid colour.
class MotionAtmosphere extends StatelessWidget {
  const MotionAtmosphere({super.key, this.glowStrength = 1});

  /// 0..1, used to pulse the bloom on the splash.
  final double glowStrength;

  static const field = LinearGradient(
    begin: Alignment(-0.58, -1.0),
    end: Alignment(0.58, 1.0),
    colors: [Color(0xFF1E5AA6), Color(0xFF0B2A57), Color(0xFF06152B)],
    stops: [0.0, 0.48, 1.0],
  );

  @override
  Widget build(BuildContext context) {
    final glow = glowStrength.clamp(0.0, 1.0);
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(decoration: BoxDecoration(gradient: field)),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0.0, -0.08),
              radius: 0.72,
              colors: [
                Color.fromRGBO(30, 90, 166, 0.28 * glow),
                const Color(0x0006152B),
              ],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(-0.72, -0.78),
              radius: 0.62,
              colors: [
                Color.fromRGBO(142, 196, 240, 0.12 * glow),
                const Color(0x0006152B),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The ribbon M mark. Drawn from the brand asset so splash, login, and the
/// home-screen icon stay on the same artwork.
class MotionLogo extends StatelessWidget {
  const MotionLogo({super.key, this.size = 96, this.trailPhase = 0});

  static const assetPath = 'assets/branding/motion_mark.png';

  final double size;

  /// Kept so existing splash/login call sites compile. The raster mark is
  /// static; motion now lives in the atmosphere bloom behind it.
  final double trailPhase;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Padding(
        padding: EdgeInsets.all(size * 0.04),
        child: Image.asset(
          assetPath,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}

/// The mark on the rounded-square hero field. Matches the home-screen icon.
class MotionLogoBadge extends StatelessWidget {
  const MotionLogoBadge({super.key, this.size = 112, this.trailPhase = 0});

  final double size;
  final double trailPhase;

  static const gradient = MotionAtmosphere.field;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.2237),
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const Positioned.fill(child: MotionAtmosphere(glowStrength: 1)),
            Center(child: MotionLogo(size: size * 0.82)),
          ],
        ),
      ),
    );
  }
}

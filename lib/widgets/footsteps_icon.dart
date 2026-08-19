import 'package:flutter/material.dart';

class FootstepsIcon extends StatelessWidget {
  const FootstepsIcon({super.key, required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _FootstepsPainter(color)),
  );
}

class _FootstepsPainter extends CustomPainter {
  const _FootstepsPainter(this.color);

  final Color color;

  void _foot(Canvas canvas, Size size, Offset center, double angle) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    final paint = Paint()..color = color;
    final scale = size.shortestSide / 24;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0, 2 * scale),
        width: 6 * scale,
        height: 10 * scale,
      ),
      paint,
    );
    canvas.drawCircle(Offset(-2.4 * scale, -4.4 * scale), 1.3 * scale, paint);
    canvas.drawCircle(Offset(-.4 * scale, -5.4 * scale), 1.25 * scale, paint);
    canvas.drawCircle(Offset(1.7 * scale, -5.1 * scale), 1.1 * scale, paint);
    canvas.drawCircle(Offset(3.2 * scale, -3.9 * scale), .85 * scale, paint);
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    _foot(canvas, size, Offset(size.width * .34, size.height * .39), -.12);
    _foot(canvas, size, Offset(size.width * .68, size.height * .65), .12);
  }

  @override
  bool shouldRepaint(covariant _FootstepsPainter oldDelegate) =>
      oldDelegate.color != color;
}

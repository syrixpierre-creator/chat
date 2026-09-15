import "dart:math" as math;
import "package:flutter/material.dart";
import "../theme/app_theme.dart";

class SyrixEmblemPainter extends CustomPainter {
  final double progress;

  SyrixEmblemPainter({this.progress = 1.0});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);

    // Glow effect
    final glowPaint = Paint()
      ..color = const Color(0xFF8A52F3).withOpacity(0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
    canvas.drawCircle(center, w * 0.35, glowPaint);

    final rect = Rect.fromLTWH(0, 0, w, h);
    final gradient = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF8A52F3), Color(0xFF6C5CE7), Color(0xFF00E5FF)],
    );
    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.18
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Draw the "S" shaped smooth chat ribbon
    final path = Path();
    final r = w * 0.22;
    // Top hook
    path.moveTo(center.dx + r, center.dy - r * 1.3);
    path.cubicTo(
      center.dx + r * 1.3, center.dy - r * 2.2,
      center.dx - r * 1.1, center.dy - r * 2.2,
      center.dx - r * 0.9, center.dy - r * 0.9,
    );
    // Center transition
    path.cubicTo(
      center.dx - r * 0.7, center.dy - r * 0.1,
      center.dx + r * 0.7, center.dy + r * 0.1,
      center.dx + r * 0.9, center.dy + r * 0.9,
    );
    // Bottom hook
    path.cubicTo(
      center.dx + r * 1.1, center.dy + r * 2.2,
      center.dx - r * 1.3, center.dy + r * 2.2,
      center.dx - r, center.dy + r * 1.3,
    );
    canvas.drawPath(path, paint);

    // Speech bubble accents (the dots from the official logo)
    final dotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    
    // Top right speech bubble dot
    canvas.drawCircle(Offset(center.dx + r * 1.45, center.dy - r * 1.4), w * 0.065, dotPaint);
    final dotTail = Path();
    dotTail.moveTo(center.dx + r * 1.4, center.dy - r * 1.25);
    dotTail.lineTo(center.dx + r * 1.2, center.dy - r * 1.2);
    dotTail.lineTo(center.dx + r * 1.35, center.dy - r * 1.4);
    dotTail.close();
    canvas.drawPath(dotTail, dotPaint);

    // Bottom left speech bubble dot
    canvas.drawCircle(Offset(center.dx - r * 1.45, center.dy + r * 1.05), w * 0.055, dotPaint);
  }

  @override
  bool shouldRepaint(covariant SyrixEmblemPainter oldDelegate) => oldDelegate.progress != progress;
}

class SyrixLogo extends StatelessWidget {
  final bool withTagline;
  final String tagline;
  final double size;
  final bool showTitle;

  const SyrixLogo({
    super.key,
    this.withTagline = true,
    this.tagline = "Made in by Syrix Vision",
    this.size = 72,
    this.showTitle = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: SyrixEmblemPainter(),
          ),
        ),
        if (showTitle) ...[
          const SizedBox(height: 12),
          RichText(
            text: const TextSpan(
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5),
              children: [
                TextSpan(
                  text: "Syrix ",
                  style: TextStyle(color: SyrixColors.neonPurple),
                ),
                TextSpan(
                  text: "Chat",
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ],
        if (withTagline && showTitle) ...[
          const SizedBox(height: 6),
          Text(
            tagline,
            style: const TextStyle(
              color: SyrixColors.textMuted,
              fontSize: 12,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}

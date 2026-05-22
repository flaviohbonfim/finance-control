import 'package:flutter/material.dart';

class GoogleSignInButton extends StatelessWidget {
  final bool loading;
  final VoidCallback? onPressed;

  const GoogleSignInButton({super.key, required this.loading, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: loading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.surface,
          side: BorderSide(color: Theme.of(context).dividerColor, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _GoogleGIcon(),
            const SizedBox(width: 10),
            const Text(
              'Continuar com Google',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoogleGIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(painter: _GoogleGPainter()),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final cx = size.width / 2;
    final cy = size.height / 2;

    final sweepPaint = Paint()..style = PaintingStyle.stroke..strokeWidth = size.width * 0.22;

    // Blue arc (top-right)
    sweepPaint.color = const Color(0xFF4285F4);
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.78),
        -0.52, 1.57, false, sweepPaint);

    // Red arc (top-left)
    sweepPaint.color = const Color(0xFFEA4335);
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.78),
        -2.09, 1.57, false, sweepPaint);

    // Yellow arc (bottom-left)
    sweepPaint.color = const Color(0xFFFBBC05);
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.78),
        2.62, 1.05, false, sweepPaint);

    // Green arc (bottom-right)
    sweepPaint.color = const Color(0xFF34A853);
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.78),
        3.67, 1.05, false, sweepPaint);

    // Horizontal bar of the "G"
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx, cy - size.height * 0.11, r * 0.78, size.height * 0.22),
        Radius.circular(2),
      ),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

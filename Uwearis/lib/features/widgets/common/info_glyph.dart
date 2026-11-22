import 'package:flutter/widgets.dart';

/// A bare "i" (no ring) sized and coloured by the ambient [IconTheme] —
/// Material and Lucide only ship the info glyph inside a circle.
class InfoGlyph extends StatelessWidget {
  const InfoGlyph({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final size = theme.size ?? 24;
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _InfoGlyphPainter(theme.color ?? const Color(0xFF000000)),
      ),
    );
  }
}

class _InfoGlyphPainter extends CustomPainter {
  final Color color;

  _InfoGlyphPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final paint = Paint()..color = color;
    final stemWidth = s * 0.15;
    canvas.drawCircle(Offset(s / 2, s * 0.2), stemWidth * 0.68, paint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(
          (s - stemWidth) / 2,
          s * 0.37,
          (s + stemWidth) / 2,
          s * 0.86,
        ),
        Radius.circular(stemWidth / 2),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(_InfoGlyphPainter oldDelegate) =>
      oldDelegate.color != color;
}

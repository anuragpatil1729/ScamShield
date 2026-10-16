import 'package:flutter/material.dart';
import '../models/message_model.dart';
import '../theme/app_colors.dart';

class MessageBodyCard extends StatelessWidget {
  final MessageCategory category;
  final String fullMessage;
  final List<String> maskedLinks;

  const MessageBodyCard({
    super.key,
    required this.category,
    required this.fullMessage,
    required this.maskedLinks,
  });

  @override
  Widget build(BuildContext context) {
    final bool isSpam = category == MessageCategory.spam;
    final bool isSus = category == MessageCategory.sus;
    final String title = (isSpam || (isSus && maskedLinks.isNotEmpty))
        ? 'MESSAGE (LINK DISABLED)'
        : 'MESSAGE';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: AppColors.textSectionHeader,
          ),
        ),
        const SizedBox(height: 10),
        CustomPaint(
          painter: isSpam ? DashedBorderPainter(color: AppColors.spamDashedBorder) : null,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: isSpam
                  ? null
                  : Border.all(
                      color: isSus ? AppColors.susBadgeBg : AppColors.borderSubtle,
                      width: 1,
                    ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: _buildMessageContent(),
          ),
        ),
      ],
    );
  }

  Widget _buildMessageContent() {
    if (maskedLinks.isEmpty) {
      return Text(
        fullMessage,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
          height: 1.4,
        ),
      );
    }

    // Replace the first detected masked link with a dark disabled pill placeholder
    final targetLink = maskedLinks.first;
    final parts = fullMessage.split(targetLink);

    if (parts.length < 2) {
      return Text(
        fullMessage,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
          height: 1.4,
        ),
      );
    }

    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
          height: 1.4,
          fontFamily: 'Plus Jakarta Sans',
        ),
        children: [
          TextSpan(text: parts[0]),
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.link_off_rounded, size: 14, color: Colors.white70),
                  SizedBox(width: 4),
                  Text(
                    'Link blocked',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (parts.length > 1) TextSpan(text: parts[1]),
        ],
      ),
    );
  }
}

class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;
  final double borderRadius;

  DashedBorderPainter({
    required this.color,
    this.strokeWidth = 1.6,
    this.dashWidth = 5.0,
    this.dashSpace = 3.5,
    this.borderRadius = 16.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(borderRadius),
    );

    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();

    for (final metric in metrics) {
      double distance = 0.0;
      while (distance < metric.length) {
        final length = (distance + dashWidth < metric.length) ? dashWidth : metric.length - distance;
        final extract = metric.extractPath(distance, distance + length);
        canvas.drawPath(extract, paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant DashedBorderPainter oldDelegate) =>
      color != oldDelegate.color || strokeWidth != oldDelegate.strokeWidth;
}

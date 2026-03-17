import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class CustomAppBarTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool centerTitle;
  final Color? textColor;
  final Color? subtitleColor;

  const CustomAppBarTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.centerTitle = true,
    this.textColor,
    this.subtitleColor,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    final effectiveTextColor =
        textColor ?? (centerTitle ? Colors.white : AppColors.textPrimary);
    final effectiveSubtitleColor =
        subtitleColor ?? (centerTitle ? Colors.white : AppColors.textSecondary);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: centerTitle
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: effectiveTextColor,
            fontSize: isMobile ? 16 : 18,
            letterSpacing: -0.5,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        if (subtitle != null && subtitle!.isNotEmpty)
          Text(
            subtitle!.toUpperCase(),
            style: TextStyle(
              fontSize: isMobile ? 9 : 10,
              fontWeight: FontWeight.w800,
              color: effectiveSubtitleColor.withOpacity(0.8),
              letterSpacing: 0.5,
            ),
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }
}

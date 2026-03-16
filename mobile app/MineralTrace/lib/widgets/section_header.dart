import 'package:flutter/material.dart';
import '../config/theme.dart';

class SectionHeaderWidget extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onActionTap;
  final String? actionLabel;
  final IconData? actionIcon;

  const SectionHeaderWidget({
    super.key,
    required this.title,
    this.subtitle,
    this.onActionTap,
    this.actionLabel,
    this.actionIcon = Icons.arrow_forward,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLg),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
          if (actionLabel != null || onActionTap != null)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onActionTap,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      if (actionLabel != null)
                        Text(
                          actionLabel!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.secondaryColor,
                          ),
                        ),
                      if (actionLabel != null) const SizedBox(width: 6),
                      Icon(
                        actionIcon,
                        color: AppTheme.secondaryColor,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

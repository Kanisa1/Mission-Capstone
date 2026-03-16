import 'package:flutter/material.dart';
import '../config/theme.dart';

class CurvedAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final VoidCallback? onBackPressed;
  final bool showBackButton;

  const CurvedAppBar({
    super.key,
    required this.title,
    this.actions,
    this.onBackPressed,
    this.showBackButton = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(120);

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: CurvedAppBarClipper(),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primaryColor,
              AppTheme.primaryColor.withValues(alpha: 0.85),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withValues(alpha: 0.25),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                if (showBackButton)
                  GestureDetector(
                    onTap: onBackPressed ?? () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                if (showBackButton) const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.diamond,
                            color: Colors.white,
                            size: 32,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: 50,
                        height: 3,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ),
                if (actions != null) ...[
                  const SizedBox(width: 16),
                  ...actions!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CurvedAppBarClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();

    // Start from top left
    path.moveTo(0, 0);

    // Top line
    path.lineTo(size.width, 0);

    // Right side
    path.lineTo(size.width, size.height * 0.75);

    // Right curve down
    path.quadraticBezierTo(
      size.width * 0.5,
      size.height * 1.15,
      0,
      size.height * 0.75,
    );

    // Close path
    path.close();

    return path;
  }

  @override
  bool shouldReclip(CurvedAppBarClipper oldClipper) => false;
}

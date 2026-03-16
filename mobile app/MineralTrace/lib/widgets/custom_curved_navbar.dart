import 'package:flutter/material.dart';
import '../config/theme.dart';

class CustomCurvedNavBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onTap;

  const CustomCurvedNavBar({
    super.key,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.15),
            blurRadius: 24,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: CustomPaint(
        painter: CurvedNavBarPainter(),
        child: SizedBox(
          height: 90,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                icon: Icons.home_outlined,
                selectedIcon: Icons.home,
                label: 'Home',
                index: 0,
              ),
              _buildNavItem(
                icon: Icons.history_outlined,
                selectedIcon: Icons.history,
                label: 'History',
                index: 1,
              ),
              _buildNavItem(
                icon: Icons.qr_code_scanner_outlined,
                selectedIcon: Icons.qr_code_scanner,
                label: 'Scan',
                index: 2,
              ),
              _buildNavItem(
                icon: Icons.person_outline,
                selectedIcon: Icons.person,
                label: 'Profile',
                index: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required int index,
  }) {
    final isSelected = selectedIndex == index;

    return GestureDetector(
      onTap: () => onTap(index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.accentColor.withValues(alpha: 0.2)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              isSelected ? selectedIcon : icon,
              color: isSelected ? AppTheme.primaryColor : AppTheme.textLight,
              size: isSelected ? 26 : 24,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? AppTheme.primaryColor : AppTheme.textLight,
              letterSpacing: isSelected ? 0.3 : 0,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class CurvedNavBarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    Path path = Path();

    // Start from bottom left
    path.moveTo(0, 30);

    // Curve 1: Left side upward curve
    path.quadraticBezierTo(
      size.width * 0.15,
      0,
      size.width * 0.3,
      0,
    );

    // Top line
    path.lineTo(size.width * 0.7, 0);

    // Curve 2: Right side upward curve
    path.quadraticBezierTo(
      size.width * 0.85,
      0,
      size.width,
      30,
    );

    // Right side
    path.lineTo(size.width, size.height);

    // Bottom
    path.lineTo(0, size.height);

    // Close path
    path.close();

    canvas.drawPath(path, paint);

    // Add subtle accent line
    Paint accentPaint = Paint()
      ..color = AppTheme.primaryColor.withValues(alpha: 0.08)
      ..strokeWidth = 1;

    Path accentPath = Path();
    accentPath.moveTo(0, 30);
    accentPath.quadraticBezierTo(
      size.width * 0.15,
      0,
      size.width * 0.3,
      0,
    );
    accentPath.lineTo(size.width * 0.7, 0);
    accentPath.quadraticBezierTo(
      size.width * 0.85,
      0,
      size.width,
      30,
    );

    canvas.drawPath(accentPath, accentPaint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

import 'package:flutter/material.dart';
import '../config/theme.dart';

class StatCard extends StatefulWidget {
  final String label;
  final String value;
  final String? subtitle;
  final Color? accentColor;
  final IconData? icon;
  final bool highlighted;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.subtitle,
    this.accentColor,
    this.icon,
    this.highlighted = false,
  });

  @override
  State<StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<StatCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _elevationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _elevationAnimation = Tween<double>(begin: 0, end: 8).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = widget.accentColor ?? AppTheme.primaryColor;
    
    return MouseRegion(
      onEnter: (_) => _controller.forward(),
      onExit: (_) => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedBuilder(
          animation: _elevationAnimation,
          builder: (context, child) {
            return Container(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                color: widget.highlighted
                    ? accentColor.withValues(alpha: 0.08)
                    : Colors.white,
                border: Border.all(
                  color: widget.highlighted
                      ? accentColor.withValues(alpha: 0.25)
                      : AppTheme.primaryColor.withValues(alpha: 0.08),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.12),
                    blurRadius: 16 + _elevationAnimation.value,
                    offset: Offset(0, 4 + (_elevationAnimation.value / 2)),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: child,
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with icon
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      widget.label,
                      style: TextStyle(
                        fontSize: 11,
 
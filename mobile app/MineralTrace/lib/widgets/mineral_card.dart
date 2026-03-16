import 'package:flutter/material.dart';
import '../config/theme.dart';

class MineralCard extends StatefulWidget {
  final String name;
  final String image;
  final String? confidence;
  final String? location;
  final String? status;
  final VoidCallback? onTap;
  final bool isLoading;

  const MineralCard({
    super.key,
    required this.name,
    required this.image,
    this.confidence,
    this.location,
    this.status,
    this.onTap,
    this.isLoading = false,
  });

  @override
  State<MineralCard> createState() => _MineralCardState();
}

class _MineralCardState extends State<MineralCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
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
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusXL),
            boxShadow: AppTheme.softCardShadow,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusXL),
            child: Material(
              color: AppTheme.cardBackground,
              child: Stack(
                children: [
                  // Background Image
                  Container(
                    color: AppTheme.surfaceLight,
                    child: widget.image.isNotEmpty
                        ? Image.asset(
                            widget.image,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: AppTheme.surfaceLighter,
                              child: Center(
                                child: Icon(
                                  Icons.image_not_supported_outlined,
                                  color: AppTheme.textLight,
                                  size: 32,
                                ),
                              ),
                            ),
                          )
                        : Center(
                            child: Icon(
                              Icons.diamond_outlined,
                              color: AppTheme.textLight,
                              size: 48,
                            ),
                          ),
                  ),

                  // Gradient overlay
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.20),
                            Colors.black.withValues(alpha: 0.40),
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                      ),
                    ),
                  ),

                  // Content
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.all(AppTheme.spacingMd),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top badges
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              if (widget.status != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppTheme.spacingSm,
                                    vertical: AppTheme.spacingXs,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.accentColor
                                        .withValues(alpha: 0.95),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    widget.status!,
                                    style: const TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ),
                              if (widget.isLoading)
                                const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AppTheme.accentColor,
                                    ),
                                  ),
                                ),
                            ],
                          ),

                          // Bottom content
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: AppTheme.spacingXs),
                              if (widget.confidence != null)
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.check_circle,
                                      color: AppTheme.accentColor,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${widget.confidence}% Confidence',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              if (widget.location != null)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: AppTheme.spacingXs,
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.location_on,
                                        color: AppTheme.accentColor,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          widget.location!,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

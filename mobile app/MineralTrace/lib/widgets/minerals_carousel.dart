import 'package:flutter/material.dart';
import '../config/theme.dart';

class MineralData {
  final String name;
  final String image;
  final String description;

  MineralData({
    required this.name,
    required this.image,
    required this.description,
  });
}

class MineralsCarouselWidget extends StatefulWidget {
  const MineralsCarouselWidget({super.key});

  @override
  State<MineralsCarouselWidget> createState() => _MineralsCarouselWidgetState();
}

class _MineralsCarouselWidgetState extends State<MineralsCarouselWidget>
    with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  late AnimationController _animationController;

  final List<MineralData> minerals = [
    MineralData(
      name: 'Gold',
      image: 'assets/images/gold.jpg',
      description: 'Precious metal with high conductivity',
    ),
    MineralData(
      name: 'Chalcopyrite',
      image: 'assets/images/chal.jpg',
      description: 'Copper iron sulfide mineral',
    ),
    MineralData(
      name: 'Hematite',
      image: 'assets/images/Hem.jpg',
      description: 'Iron oxide with high density',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _animationController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    );

    // Start continuous scrolling animation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startScrolling();
    });
  }

  void _startScrolling() {
    // Jump to start and animate smoothly
    _animationController.repeat();
    _animationController.addListener(() {
      if (_scrollController.hasClients) {
        final maxScroll = _scrollController.position.maxScrollExtent;
        final currentScroll = _animationController.value * maxScroll;
        _scrollController.jumpTo(currentScroll);
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingLg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Accepted Minerals',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Minerals detected by our system',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.spacingMd),
        SizedBox(
          height: 200,
          child: SingleChildScrollView(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            child: Row(
              children: [
                const SizedBox(width: AppTheme.spacingLg),
                ...minerals.expand((mineral) => [
                  _buildMineralCard(mineral),
                  const SizedBox(width: AppTheme.spacingMd),
                ]),
                // Repeat minerals for continuous loop effect
                ...minerals.expand((mineral) => [
                  _buildMineralCard(mineral),
                  const SizedBox(width: AppTheme.spacingMd),
                ]),
                const SizedBox(width: AppTheme.spacingLg),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMineralCard(MineralData mineral) {
    return SizedBox(
      width: 160,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image container
          Container(
            width: 160,
            height: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              boxShadow: AppTheme.softCardShadow,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              child: Image.asset(
                mineral.image,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: AppTheme.backgroundColor,
                    child: Icon(
                      Icons.image_not_supported_outlined,
                      color: AppTheme.textSecondary,
                      size: 32,
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Mineral name
          Text(
            mineral.name,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          // Description
          Text(
            mineral.description,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
              height: 1.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

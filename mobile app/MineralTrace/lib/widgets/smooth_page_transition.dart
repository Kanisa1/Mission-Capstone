import 'package:flutter/material.dart';

class SmoothPageTransition extends StatelessWidget {
  final Widget child;
  final int currentIndex;
  final int index;

  const SmoothPageTransition({
    super.key,
    required this.child,
    required this.currentIndex,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: currentIndex == index ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: AnimatedScale(
        scale: currentIndex == index ? 1.0 : 0.95,
        duration: const Duration(milliseconds: 300),
        child: currentIndex == index
            ? child
            : SizedBox.expand(
                child: child,
              ),
      ),
    );
  }
}

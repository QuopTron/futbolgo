import 'dart:ui';

import 'package:flutter/material.dart';

/// A shimmer loading placeholder that shows animated gradient bars.
/// Mimics the glassmorphism card layout while data is loading.
class ShimmerLoading extends StatefulWidget {
  final int itemCount;
  final double itemHeight;
  final ShimmerType type;

  const ShimmerLoading({
    super.key,
    this.itemCount = 6,
    this.itemHeight = 80,
    this.type = ShimmerType.channel,
  });

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.only(top: 8, bottom: 100),
          itemCount: widget.itemCount,
          itemBuilder: (context, index) {
            return _ShimmerCard(
              animation: _animation,
              height: widget.itemHeight,
              type: widget.type,
            );
          },
        );
      },
    );
  }
}

/// Individual shimmer card placeholder
class _ShimmerCard extends StatelessWidget {
  final Animation<double> animation;
  final double height;
  final ShimmerType type;

  const _ShimmerCard({
    required this.animation,
    required this.height,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    final shimmerGradient = LinearGradient(
      begin: Alignment(-1.0 + animation.value, 0),
      end: Alignment(1.0 + animation.value, 0),
      colors: [
        Colors.white.withValues(alpha: 0.03),
        Colors.white.withValues(alpha: 0.08),
        Colors.white.withValues(alpha: 0.03),
      ],
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.05),
                width: 0.5,
              ),
            ),
            child: Row(
              children: [
                // Live dot shimmer
                _ShimmerBlock(
                  width: 14,
                  height: 14,
                  borderRadius: 7,
                  gradient: shimmerGradient,
                ),
                const SizedBox(width: 14),
                // Icon block shimmer
                _ShimmerBlock(
                  width: 44,
                  height: 44,
                  borderRadius: 12,
                  gradient: shimmerGradient,
                ),
                const SizedBox(width: 14),
                // Text lines shimmer
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _ShimmerBlock(
                        width: type == ShimmerType.channel ? 160 : 220,
                        height: 14,
                        borderRadius: 4,
                        gradient: shimmerGradient,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _ShimmerBlock(
                            width: 40,
                            height: 12,
                            borderRadius: 4,
                            gradient: shimmerGradient,
                          ),
                          const SizedBox(width: 8),
                          _ShimmerBlock(
                            width: 50,
                            height: 12,
                            borderRadius: 4,
                            gradient: shimmerGradient,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Play button shimmer
                _ShimmerBlock(
                  width: 44,
                  height: 44,
                  borderRadius: 12,
                  gradient: shimmerGradient,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A small shimmer rectangle with animated gradient
class _ShimmerBlock extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;
  final Gradient gradient;

  const _ShimmerBlock({
    required this.width,
    required this.height,
    required this.borderRadius,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: gradient,
      ),
    );
  }
}

/// Shimmer loading type
enum ShimmerType { channel, event }

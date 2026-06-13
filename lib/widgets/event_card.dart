import 'dart:math';

import 'package:flutter/material.dart';
import '../models/stream_models.dart';
import 'glass_container.dart';

class EventCard extends StatelessWidget {
  final StreamEvent event;
  final VoidCallback onTap;
  final bool adBlockerEnabled;

  const EventCard({
    super.key,
    required this.event,
    required this.onTap,
    this.adBlockerEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = EventCategory.getIcon(event.category);
    final isLive = event.isLive;
    final isActive = event.isActive;

    return GlassContainer(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      borderRadius: 16,
      blur: 12,
      padding: const EdgeInsets.all(12),
      backgroundColor:
          isLive
              ? Colors.red.withValues(alpha: 0.04)
              : isActive
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.white.withValues(alpha: 0.02),
      borderColor:
          isLive
              ? Colors.red.withValues(alpha: 0.15)
              : isActive
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.white.withValues(alpha: 0.04),
      boxShadow:
          isLive
              ? [
                  BoxShadow(
                    color: Colors.red.withValues(alpha: 0.05),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ]
              : null,
      onTap: isActive ? onTap : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category icon with glass background
          GlassContainer(
            borderRadius: 14,
            blur: 4,
            padding: EdgeInsets.zero,
            margin: EdgeInsets.zero,
            backgroundColor:
                isLive
                    ? Colors.red.withValues(alpha: 0.08)
                    : isActive
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.grey.withValues(alpha: 0.04),
            borderColor: Colors.transparent,
            width: 48,
            height: 48,
            alignment: Alignment.center,
            child: Text(icon, style: const TextStyle(fontSize: 26)),
          ),
          const SizedBox(width: 14),

          // Event info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                    color: isLive ? Colors.white : (isActive ? Colors.white70 : Colors.grey[500]),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (event.category.isNotEmpty)
                      _EventInfoChip(
                        icon: Icons.category_outlined,
                        label: event.category,
                        color: isLive ? Colors.white : Colors.grey,
                      ),
                    if (event.time.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      _EventInfoChip(
                        icon: Icons.access_time,
                        label: event.time,
                        color: Colors.white54,
                      ),
                    ],
                    if (event.language.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      _EventInfoChip(
                        icon: Icons.language,
                        label: event.language,
                        color: Colors.white54,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Status badge
          Column(
            children: [
              if (isLive)
                const _LiveBadge()
              else if (isActive)
                const _NextBadge()
              else
                const _FinishedBadge(),
              if (event.isAdFree) ...[
                const SizedBox(height: 6),
                GlassContainer(
                  borderRadius: 4,
                  blur: 4,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  margin: EdgeInsets.zero,
                  backgroundColor: Colors.white.withValues(alpha: 0.06),
                  borderColor: Colors.white.withValues(alpha: 0.12),
                  child: const Text(
                    'SIN ADS',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Colors.white54,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _EventInfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _EventInfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: color.withValues(alpha: 0.12),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color.withValues(alpha: 0.7)),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w500,
              color: color.withValues(alpha: 0.7),
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveBadge extends StatefulWidget {
  const _LiveBadge();

  @override
  State<_LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<_LiveBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final pulse = 0.2 + (0.4 * sin(_controller.value * pi));
        return GlassContainer(
          borderRadius: 8,
          blur: 4,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          margin: EdgeInsets.zero,
          backgroundColor: Colors.red.withValues(alpha: pulse),
          borderColor: Colors.red.withValues(alpha: 0.4 + pulse),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withValues(alpha: 0.6 + pulse),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'EN VIVO',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.red,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NextBadge extends StatelessWidget {
  const _NextBadge();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassContainer(
      borderRadius: 8,
      blur: 4,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      margin: EdgeInsets.zero,
      backgroundColor: Colors.white.withValues(alpha: 0.05),
      borderColor: Colors.white.withValues(alpha: 0.12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Colors.white54,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'PRONTO',
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.white54,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _FinishedBadge extends StatelessWidget {
  const _FinishedBadge();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassContainer(
      borderRadius: 8,
      blur: 4,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      margin: EdgeInsets.zero,
      backgroundColor: Colors.grey.withValues(alpha: 0.04),
      borderColor: Colors.grey.withValues(alpha: 0.1),
      child: Text(
        'FINALIZADO',
        style: theme.textTheme.labelSmall?.copyWith(
          color: Colors.grey[500],
          fontSize: 9,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

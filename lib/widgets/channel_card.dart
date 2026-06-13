import 'package:flutter/material.dart';
import '../models/stream_models.dart';
import 'glass_container.dart';

class ChannelCard extends StatefulWidget {
  final StreamChannel channel;
  final VoidCallback onTap;
  final bool adBlockerEnabled;
  final bool justCameOnline;
  final bool justWentOffline;

  const ChannelCard({
    super.key,
    required this.channel,
    required this.onTap,
    this.adBlockerEnabled = true,
    this.justCameOnline = false,
    this.justWentOffline = false,
  });

  @override
  State<ChannelCard> createState() => _ChannelCardState();
}

class _ChannelCardState extends State<ChannelCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.channel.isActive) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(ChannelCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.channel.isActive && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.channel.isActive && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = widget.channel.isActive;

    return GlassContainer(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      borderRadius: 16,
      blur: 12,
      padding: const EdgeInsets.all(12),
      backgroundColor: isActive
          ? Colors.white.withValues(alpha: 0.07)
          : Colors.white.withValues(alpha: 0.03),
      borderColor: isActive
          ? Colors.white.withValues(alpha: 0.15)
          : Colors.white.withValues(alpha: 0.05),
      boxShadow: isActive
          ? [
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.04),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ]
          : null,
      onTap: isActive ? widget.onTap : null,
      child: Row(
        children: [
          // Live pulse indicator — white pulse
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: isActive ? Colors.white : Colors.grey[700],
                  shape: BoxShape.circle,
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: Colors.white.withValues(
                                alpha: 0.4 * _pulseAnimation.value),
                            blurRadius: 10 * _pulseAnimation.value,
                            spreadRadius: 3 * _pulseAnimation.value,
                          ),
                        ]
                      : [],
                ),
              );
            },
          ),
          const SizedBox(width: 14),

          // Channel icon
          GlassContainer(
            borderRadius: 12,
            blur: 4,
            padding: EdgeInsets.zero,
            margin: EdgeInsets.zero,
            backgroundColor: isActive
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.grey.withValues(alpha: 0.05),
            borderColor: Colors.transparent,
            width: 44,
            height: 44,
            alignment: Alignment.center,
            child: Icon(
              Icons.live_tv_rounded,
              color: isActive ? Colors.white70 : Colors.grey[600],
              size: 22,
            ),
          ),
          const SizedBox(width: 14),

          // Channel info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.channel.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isActive ? null : Colors.grey[500],
                    letterSpacing: 0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _InfoChip(
                      label: widget.channel.quality,
                      color: Colors.white,
                      isActive: isActive,
                    ),
                    if (widget.channel.isAdFree && isActive) ...[
                      const SizedBox(width: 6),
                      const _InfoChip(
                        label: 'SIN ADS',
                        color: Colors.white,
                        isActive: true,
                      ),
                    ],
                    if (!isActive) ...[
                      const SizedBox(width: 6),
                      const _InfoChip(
                        label: 'OFFLINE',
                        color: Colors.grey,
                        isActive: false,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Play button
          if (isActive)
            GlassContainer(
              borderRadius: 12,
              blur: 6,
              padding: EdgeInsets.zero,
              margin: EdgeInsets.zero,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              borderColor: Colors.white.withValues(alpha: 0.15),
              width: 44,
              height: 44,
              alignment: Alignment.center,
              child: IconButton(
                icon: const Icon(Icons.play_arrow_rounded,
                    color: Colors.white, size: 26),
                onPressed: widget.onTap,
                tooltip: 'Ver canal',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),

          // Status change badges
          if (widget.justCameOnline)
            const Padding(
              padding: EdgeInsets.only(left: 6),
              child: _StatusBadge(
                icon: Icons.wifi_find,
                color: Colors.white,
                tooltip: '¡Acaba de activarse!',
              ),
            ),
          if (widget.justWentOffline)
            const Padding(
              padding: EdgeInsets.only(left: 6),
              child: _StatusBadge(
                icon: Icons.cloud_off,
                color: Colors.orange,
                tooltip: 'Se ha desconectado',
              ),
            ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool isActive;

  const _InfoChip({
    required this.label,
    required this.color,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isActive ? 0.10 : 0.06),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: color.withValues(alpha: isActive ? 0.15 : 0.08),
          width: 0.5,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: isActive ? color : color.withValues(alpha: 0.5),
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;

  const _StatusBadge({
    required this.icon,
    required this.color,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GlassContainer(
        borderRadius: 20,
        blur: 6,
        padding: const EdgeInsets.all(6),
        margin: EdgeInsets.zero,
        backgroundColor: color.withValues(alpha: 0.12),
        borderColor: color.withValues(alpha: 0.3),
        width: 30,
        height: 30,
        alignment: Alignment.center,
        child: Icon(icon, color: color, size: 16),
      ),
    );
  }
}

import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/theme_notifier.dart';

/// A reusable glassmorphism container with frosted glass effect.
/// When [ThemeNotifier.isGlass] is false, renders as a solid card instead.
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double blur;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color? borderColor;
  final Color backgroundColor;
  final List<BoxShadow>? boxShadow;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double borderWidth;
  final Alignment? alignment;
  final double? width;
  final double? height;

  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 16,
    this.blur = 12,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.borderColor,
    this.backgroundColor = const Color(0x1AFFFFFF),
    this.boxShadow,
    this.onTap,
    this.onLongPress,
    this.borderWidth = 0.5,
    this.alignment,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final useGlass = ThemeNotifier.isGlass.value;

    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: boxShadow ??
            [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: useGlass
            ? BackdropFilter(
                filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                child: _buildInner(),
              )
            : _buildInner(),
      ),
    );
  }

  Widget _buildInner() {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: ThemeNotifier.isGlass.value
              ? (borderColor ?? Colors.white.withValues(alpha: 0.12))
              : (borderColor ?? Colors.white.withValues(alpha: 0.08)),
          width: borderWidth,
        ),
      ),
      child: onTap != null || onLongPress != null
          ? Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(borderRadius),
                onTap: onTap,
                onLongPress: onLongPress,
                child: child,
              ),
            )
          : child,
    );
  }
}

/// A glass-styled AppBar. In solid mode, uses a solid background color.
class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget? title;
  final List<Widget>? actions;
  final Widget? leading;
  final double elevation;
  final double blur;
  final PreferredSizeWidget? bottom;
  final bool automaticallyImplyLeading;

  const GlassAppBar({
    super.key,
    this.title,
    this.actions,
    this.leading,
    this.elevation = 0,
    this.blur = 16,
    this.bottom,
    this.automaticallyImplyLeading = true,
  });

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom != null ? kTextTabBarHeight : 0));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final useGlass = ThemeNotifier.isGlass.value;

    if (useGlass) {
      return ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: 0.6),
              border: Border(
                bottom: BorderSide(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 0.5,
                ),
              ),
            ),
            child: _buildAppBar(theme),
          ),
        ),
      );
    }

    // Solid mode
    return Container(
      decoration: BoxDecoration(
        color: theme.appBarTheme.backgroundColor ?? const Color(0xFF161B22),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.06),
            width: 0.5,
          ),
        ),
      ),
      child: _buildAppBar(theme),
    );
  }

  Widget _buildAppBar(ThemeData theme) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: elevation,
      scrolledUnderElevation: 0,
      title: title,
      actions: actions,
      leading: leading,
      automaticallyImplyLeading: automaticallyImplyLeading,
      bottom: bottom,
      centerTitle: false,
    );
  }
}

/// A glass-styled FAB. In solid mode, uses a solid background.
class GlassFAB extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget? child;
  final String? tooltip;
  final Color? backgroundColor;
  final double size;
  final IconData? icon;
  final String? label;

  const GlassFAB({
    super.key,
    this.onPressed,
    this.child,
    this.tooltip,
    this.backgroundColor,
    this.size = 56,
    this.icon,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final useGlass = ThemeNotifier.isGlass.value;
    final bgColor =
        backgroundColor ?? theme.colorScheme.primary.withValues(alpha: 0.25);

    Widget fabContent;

    if (useGlass) {
      fabContent = Container(
        width: label != null ? null : size,
        height: size,
        padding: label != null
            ? const EdgeInsets.symmetric(horizontal: 20, vertical: 12)
            : EdgeInsets.zero,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                  width: 0.5,
                ),
              ),
              child: _buildContent(),
            ),
          ),
        ),
      );
    } else {
      // Solid mode FAB
      fabContent = Container(
        width: label != null ? null : size,
        height: size,
        padding: label != null
            ? const EdgeInsets.symmetric(horizontal: 20, vertical: 12)
            : EdgeInsets.zero,
        decoration: BoxDecoration(
          color: const Color(0xFF21262D),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: _buildContent(),
      );
    }

    if (tooltip != null) {
      return Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: fabContent,
        ),
      );
    }

    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(16),
      child: fabContent,
    );
  }

  Widget _buildContent() {
    return label != null
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: Colors.white70),
                const SizedBox(width: 8),
              ],
              Text(
                label!,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
            ],
          )
        : Center(
            child: child ??
                (icon != null
                    ? Icon(icon, color: Colors.white70)
                    : null),
          );
  }
}

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../config/app_icons.dart';
import '../config/theme.dart';

/// ConnectionBanner — mirrors `.banner` in styles.css.
/// Red error-container bar with cloud-off icon, message, and Retry button.
class ConnectionBanner extends StatelessWidget {
  final VoidCallback onRetry;
  const ConnectionBanner({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.errorContainer,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.l,
            AppSpacing.s,
            AppSpacing.s,
            AppSpacing.s,
          ),
          child: Row(
            children: [
              HugeIcon(
                icon: AppIcons.cloudOff,
                size: 18,
                color: scheme.onErrorContainer,
              ),
              const SizedBox(width: AppSpacing.s),
              Expanded(
                child: Text(
                  "Disconnected — couldn't reach Home Assistant",
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: scheme.onErrorContainer),
                ),
              ),
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(
                  foregroundColor: scheme.onErrorContainer,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Status dot — used in the plug card identity row and the detail screen.
/// Soft pulse when [pulse] is true (Handoff §7, 2400ms).
class StatusDot extends StatefulWidget {
  final bool online;
  final bool pulse;
  final double size;
  const StatusDot({
    super.key,
    required this.online,
    this.pulse = false,
    this.size = 8,
  });

  @override
  State<StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<StatusDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.statusDotPulse,
    );
    if (widget.pulse && widget.online) _controller.repeat();
  }

  @override
  void didUpdateWidget(StatusDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pulse && widget.online) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final base = widget.online
        ? (brightness == Brightness.dark
            ? AppStatus.successDark
            : AppStatus.success)
        : Theme.of(context).colorScheme.outline;
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        final t = _controller.value;
        final glowOpacity =
            widget.pulse && widget.online ? 0.35 * (1 - t) : 0.0;
        final scale = widget.pulse && widget.online
            ? 1 + (0.6 * (1 - (2 * t - 1).abs()))
            : 1.0;
        return SizedBox(
          width: widget.size * 2.2,
          height: widget.size * 2.2,
          child: Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (glowOpacity > 0)
                  Container(
                    width: widget.size * scale * 2,
                    height: widget.size * scale * 2,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: base.withValues(alpha: glowOpacity),
                    ),
                  ),
                Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: base,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

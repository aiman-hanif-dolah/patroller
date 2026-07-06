import 'package:flutter/material.dart';

import '../core/theme/patrol_colors.dart';

class PatrolEyebrow extends StatelessWidget {
  const PatrolEyebrow(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
        color: color ?? PatrolColors.steel,
      ),
    );
  }
}

class PatrolMetaChip extends StatelessWidget {
  const PatrolMetaChip({
    super.key,
    required this.label,
    this.icon,
    this.color = PatrolColors.steel,
    this.accent = false,
  });

  final String label;
  final IconData? icon;
  final Color color;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: accent
            ? PatrolColors.amber.withValues(alpha: 0.12)
            : PatrolColors.obsidian.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(PatrolRadius.badge),
        border: Border.all(
          color: accent
              ? PatrolColors.amber.withValues(alpha: 0.35)
              : PatrolColors.pebble.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: accent ? PatrolColors.amber : color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: accent ? PatrolColors.amberBright : color,
            ),
          ),
        ],
      ),
    );
  }
}

class PatrolFilterPill extends StatelessWidget {
  const PatrolFilterPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
    this.color,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? count;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PatrolRadius.pill),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            gradient: selected && color != null
                ? LinearGradient(colors: [color!, color!.withValues(alpha: 0.85)])
                : selected
                    ? PatrolGradients.brandGlow
                    : null,
            color: selected ? null : PatrolColors.mist,
            borderRadius: BorderRadius.circular(PatrolRadius.pill),
            border: Border.all(
              color: selected
                  ? (color ?? PatrolColors.amber).withValues(alpha: 0.5)
                  : PatrolColors.pebble,
            ),
            boxShadow: selected
                ? PatrolShadows.glow(color ?? PatrolColors.amber, blur: 8)
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? PatrolColors.obsidian : PatrolColors.steel,
                  letterSpacing: 0.2,
                ),
              ),
              if (count != null && count! > 0) ...[
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: selected
                        ? PatrolColors.obsidian.withValues(alpha: 0.2)
                        : PatrolColors.fog,
                    borderRadius: BorderRadius.circular(PatrolRadius.pill),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: selected ? PatrolColors.obsidian : PatrolColors.graphite,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class PatrolAvatar extends StatelessWidget {
  const PatrolAvatar({
    super.key,
    required this.icon,
    this.color = PatrolColors.amber,
    this.size = 32,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.25),
            color.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Icon(icon, size: size * 0.48, color: color),
    );
  }
}

class PatrolBrandMark extends StatelessWidget {
  const PatrolBrandMark({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.22),
        boxShadow: PatrolShadows.glow(PatrolColors.amber, blur: 10),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.22),
        child: Image.asset(
          'assets/branding/patroller-app-icon.jpg',
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            color: PatrolColors.amber,
            child: Icon(
              Icons.explore_rounded,
              size: size * 0.55,
              color: PatrolColors.obsidian,
            ),
          ),
        ),
      ),
    );
  }
}

class PatrolPanelTab extends StatelessWidget {
  const PatrolPanelTab({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.badge,
    this.color,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final String? badge;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: '$label tab',
        child: InkWell(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: selected ? (color ?? PatrolColors.amber) : Colors.transparent,
                  width: 2,
                ),
              ),
              color: selected
                  ? (color ?? PatrolColors.amber).withValues(alpha: 0.08)
                  : Colors.transparent,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 12,
                  color: selected ? (color ?? PatrolColors.amberBright) : PatrolColors.steel,
                ),
                const SizedBox(height: 4),
                Text(
                  badge ?? label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: selected ? (color ?? PatrolColors.amberBright) : PatrolColors.steel,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PatrolStatusDot extends StatefulWidget {
  const PatrolStatusDot({
    super.key,
    required this.color,
    this.pulse = false,
    this.size = 8,
  });

  final Color color;
  final bool pulse;
  final double size;

  @override
  State<PatrolStatusDot> createState() => _PatrolStatusDotState();
}

class _PatrolStatusDotState extends State<PatrolStatusDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    if (widget.pulse) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant PatrolStatusDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pulse && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.pulse && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size + 4,
      height: widget.size + 4,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (widget.pulse)
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final scale = 1.0 + (_controller.value * 1.4);
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      color: widget.color.withValues(
                        alpha: (1 - _controller.value) * 0.45,
                      ),
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              },
            ),
          Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
              boxShadow: PatrolShadows.glow(widget.color, blur: 5),
            ),
          ),
        ],
      ),
    );
  }
}
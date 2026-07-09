import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/patrol_colors.dart';
import '../providers/runner_provider.dart';
import 'accessible_icon_button.dart';

const _dismissMs = 3500;
const _animationMs = 220;

class SnackbarOverlay extends ConsumerStatefulWidget {
  const SnackbarOverlay({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<SnackbarOverlay> createState() => _SnackbarOverlayState();
}

class _SnackbarOverlayState extends ConsumerState<SnackbarOverlay> {
  Timer? _timer;
  int? _lastSnackbarId;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _scheduleDismiss() {
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: _dismissMs), () {
      if (mounted) {
        ref.read(runnerProvider.notifier).dismissSnackbar();
      }
    });
  }

  void _dismissNow() {
    _timer?.cancel();
    ref.read(runnerProvider.notifier).dismissSnackbar();
  }

  @override
  Widget build(BuildContext context) {
    final snackbar = ref.watch(runnerProvider).snackbar;

    if (snackbar != null && snackbar.id != _lastSnackbarId) {
      _lastSnackbarId = snackbar.id;
      _scheduleDismiss();
    } else if (snackbar == null) {
      _lastSnackbarId = null;
    }

    return Stack(
      children: [
        widget.child,
        Positioned(
          left: 24,
          bottom: 24,
          child: IgnorePointer(
            ignoring: snackbar == null,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: _animationMs),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                final slide = Tween<Offset>(
                  begin: const Offset(0, 0.35),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                  reverseCurve: Curves.easeInCubic,
                ));
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(position: slide, child: child),
                );
              },
              child: snackbar == null
                  ? const SizedBox.shrink(key: ValueKey('snackbar-empty'))
                  : _SnackbarBanner(
                      key: ValueKey(snackbar.id),
                      message: snackbar.message,
                      onDismiss: _dismissNow,
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SnackbarBanner extends StatelessWidget {
  const _SnackbarBanner({
    super.key,
    required this.message,
    required this.onDismiss,
  });

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: PatrolColors.ink,
          fontWeight: FontWeight.w500,
          height: 1.56,
        );

    return Material(
      color: Colors.transparent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: PatrolColors.mist,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: PatrolColors.pebble),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14FFFFFF),
              offset: Offset(0, 1),
            ),
            BoxShadow(
              color: Color(0x40000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onDismiss,
            hoverColor: PatrolColors.fog.withValues(alpha: 0.45),
            splashColor: PatrolColors.fog.withValues(alpha: 0.6),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: PatrolColors.ink,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x66FAFAFA),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        message,
                        style: textStyle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    AccessibleIconButton(
                      onPressed: onDismiss,
                      icon: Icons.close,
                      size: 14,
                      label: 'Dismiss',
                      color: PatrolColors.steel,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 28,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
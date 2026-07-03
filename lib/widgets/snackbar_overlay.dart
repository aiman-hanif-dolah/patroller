import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/patrol_colors.dart';
import '../providers/runner_provider.dart';

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

  @override
  Widget build(BuildContext context) {
    final snackbar = ref.watch(runnerProvider).snackbar;

    if (snackbar != null && snackbar.id != _lastSnackbarId) {
      _lastSnackbarId = snackbar.id;
      _timer?.cancel();
      _timer = Timer(const Duration(milliseconds: 3500), () {
        ref.read(runnerProvider.notifier).dismissSnackbar();
      });
    }

    return Stack(
      children: [
        widget.child,
        if (snackbar != null)
          Positioned(
            left: 24,
            bottom: 24,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: PatrolColors.mist,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: PatrolColors.pebble),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x40000000),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  snackbar.message,
                  style: const TextStyle(
                    color: PatrolColors.ink,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
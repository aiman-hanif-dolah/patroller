import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patroller/features/devices/simulator_preview_panel.dart';
import 'package:patroller/models/hierarchy.dart';
import 'package:patroller/models/preview_frame.dart';
import 'package:patroller/providers/preview_provider.dart';

final Uint8List _onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

void main() {
  Widget wrap(PreviewState state, Widget child) {
    return ProviderScope(
      overrides: [
        previewProvider.overrideWith(
          (ref) => PreviewNotifier(
            ref,
            initialState: state,
            disableSync: true,
          ),
        ),
      ],
      child: MaterialApp(home: Scaffold(body: child)),
    );
  }

  testWidgets('shows no-device state', (tester) async {
    await tester.pumpWidget(
      wrap(
        const PreviewState(readiness: PreviewReadiness.noDevice),
        const SimulatorPreviewPanel(collapsed: false, onToggleCollapse: _noop),
      ),
    );
    expect(find.text('Select a booted iOS Simulator.'), findsOneWidget);
  });

  testWidgets('shows image when frame bytes exist', (tester) async {
    final bytes = _onePixelPng;
    await tester.pumpWidget(
      wrap(
        PreviewState(
          readiness: PreviewReadiness.ready,
          frame: PreviewFrame(
            bytes: bytes,
            fingerprint: 'abc',
            capturedAt: DateTime.now(),
          ),
          deviceInfo: const XCTestDeviceInfo(
            widthPixels: 1170,
            heightPixels: 2532,
            widthPoints: 390,
            heightPoints: 844,
          ),
        ),
        const SimulatorPreviewPanel(collapsed: false, onToggleCollapse: _noop),
      ),
    );
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('draws highlight overlay when highlightFrame exists', (tester) async {
    final bytes = _onePixelPng;
    await tester.pumpWidget(
      wrap(
        PreviewState(
          readiness: PreviewReadiness.ready,
          frame: PreviewFrame(
            bytes: bytes,
            fingerprint: 'abc',
            capturedAt: DateTime.now(),
          ),
          deviceInfo: const XCTestDeviceInfo(
            widthPixels: 1170,
            heightPixels: 2532,
            widthPoints: 390,
            heightPoints: 844,
          ),
          highlightFrame: const ElementFrame(x: 20, y: 40, width: 100, height: 50),
        ),
        const SimulatorPreviewPanel(collapsed: false, onToggleCollapse: _noop),
      ),
    );
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);
    expect(find.byType(Positioned), findsWidgets);
  });

  testWidgets('draws touch feedback after interaction', (tester) async {
    final bytes = _onePixelPng;
    await tester.pumpWidget(
      wrap(
        PreviewState(
          readiness: PreviewReadiness.ready,
          frame: PreviewFrame(
            bytes: bytes,
            fingerprint: 'abc',
            capturedAt: DateTime.now(),
          ),
          deviceInfo: const XCTestDeviceInfo(
            widthPixels: 1170,
            heightPixels: 2532,
            widthPoints: 390,
            heightPoints: 844,
          ),
          interactionFeedback: PreviewInteractionFeedback(
            kind: PreviewGestureKind.tap,
            at: DateTime.now(),
            position: const Offset(100, 200),
          ),
        ),
        const SimulatorPreviewPanel(collapsed: false, onToggleCollapse: _noop),
      ),
    );
    await tester.pump();
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.constraints == const BoxConstraints.tightFor(width: 32, height: 32),
      ),
      findsOneWidget,
    );
  });
}

void _noop() {}
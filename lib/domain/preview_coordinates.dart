import 'dart:math' as math;
import 'dart:ui';

import '../models/hierarchy.dart';

class PreviewLayout {
  const PreviewLayout({
    required this.imageRect,
    required this.deviceWidth,
    required this.deviceHeight,
  });

  final Rect imageRect;
  final double deviceWidth;
  final double deviceHeight;
}

PreviewLayout computePreviewLayout({
  required Size containerSize,
  required double deviceWidth,
  required double deviceHeight,
}) {
  if (deviceWidth <= 0 || deviceHeight <= 0) {
    return PreviewLayout(
      imageRect: Offset.zero & containerSize,
      deviceWidth: deviceWidth,
      deviceHeight: deviceHeight,
    );
  }

  final imageAspect = deviceWidth / deviceHeight;
  final containerAspect = containerSize.width / containerSize.height;
  late double renderWidth;
  late double renderHeight;

  if (imageAspect > containerAspect) {
    renderWidth = containerSize.width;
    renderHeight = containerSize.width / imageAspect;
  } else {
    renderHeight = containerSize.height;
    renderWidth = containerSize.height * imageAspect;
  }

  final left = (containerSize.width - renderWidth) / 2;
  final top = (containerSize.height - renderHeight) / 2;
  return PreviewLayout(
    imageRect: Rect.fromLTWH(left, top, renderWidth, renderHeight),
    deviceWidth: deviceWidth,
    deviceHeight: deviceHeight,
  );
}

Offset? mapPreviewToDevice({
  required Offset local,
  required PreviewLayout layout,
}) {
  if (!layout.imageRect.contains(local)) return null;
  final relativeX =
      (local.dx - layout.imageRect.left) / layout.imageRect.width;
  final relativeY =
      (local.dy - layout.imageRect.top) / layout.imageRect.height;
  return Offset(
    relativeX * layout.deviceWidth,
    relativeY * layout.deviceHeight,
  );
}

Rect? mapDeviceFrameToPreview({
  required ElementFrame frame,
  required PreviewLayout layout,
}) {
  if (layout.deviceWidth <= 0 || layout.deviceHeight <= 0) return null;
  final scaleX = layout.imageRect.width / layout.deviceWidth;
  final scaleY = layout.imageRect.height / layout.deviceHeight;
  return Rect.fromLTWH(
    layout.imageRect.left + frame.x * scaleX,
    layout.imageRect.top + frame.y * scaleY,
    math.max(1, frame.width * scaleX),
    math.max(1, frame.height * scaleY),
  );
}

Offset? mapDeviceToPreview({
  required Offset device,
  required PreviewLayout layout,
}) {
  if (layout.deviceWidth <= 0 || layout.deviceHeight <= 0) return null;
  return Offset(
    layout.imageRect.left +
        (device.dx / layout.deviceWidth) * layout.imageRect.width,
    layout.imageRect.top +
        (device.dy / layout.deviceHeight) * layout.imageRect.height,
  );
}
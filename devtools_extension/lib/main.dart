import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:flutter/material.dart';

import 'patroller_panel.dart';

void main() {
  runApp(const PatrollerDevToolsExtension());
}

/// Root widget required by the Flutter DevTools extension framework.
class PatrollerDevToolsExtension extends StatelessWidget {
  const PatrollerDevToolsExtension({super.key});

  @override
  Widget build(BuildContext context) {
    return const DevToolsExtension(
      child: PatrollerPanel(),
    );
  }
}

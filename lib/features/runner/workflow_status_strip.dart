import 'package:flutter/material.dart';

/// Formerly a second toolbar row for Test All multi-select.
///
/// Test All queue scope now lives on [RunToolbar] as a flow-aware badge
/// so the shell keeps a single compact header.
@Deprecated('Selection chips moved to RunToolbar; strip removed from AppShell.')
class WorkflowStatusStrip extends StatelessWidget {
  const WorkflowStatusStrip({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

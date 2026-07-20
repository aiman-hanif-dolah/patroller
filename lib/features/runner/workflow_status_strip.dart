import 'package:flutter/material.dart';

/// Formerly a second toolbar row for Test All multi-select.
///
/// Multi-select count now lives on [RunToolbar] as "Test All: N files selected"
/// so the shell keeps a single compact header.
@Deprecated('Selection chips moved to RunToolbar; strip removed from AppShell.')
class WorkflowStatusStrip extends StatelessWidget {
  const WorkflowStatusStrip({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

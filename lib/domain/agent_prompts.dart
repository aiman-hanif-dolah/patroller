import 'dart:io';

import 'package:path/path.dart' as p;

/// Built-in agent routine prompts that Patroller can fill and hand off to
/// Cursor (with Patrol MCP + Marionette MCP already configured).
enum AgentPromptId {
  marionetteCoverageExploration,
}

class AgentPromptMeta {
  const AgentPromptMeta({
    required this.id,
    required this.title,
    required this.summary,
  });

  final AgentPromptId id;
  final String title;
  final String summary;
}

const agentPromptCatalog = <AgentPromptMeta>[
  AgentPromptMeta(
    id: AgentPromptId.marionetteCoverageExploration,
    title: 'Marionette coverage exploration',
    summary:
        'Systematically explore the live app with Marionette MCP, map coverage, '
        'and generate maintainable Patrol tests without duplicates.',
  ),
];

/// Runtime values substituted into prompt templates.
class AgentPromptContext {
  const AgentPromptContext({
    required this.projectName,
    required this.projectPath,
    required this.flutterExecutable,
    required this.deviceName,
    required this.entryTarget,
    required this.flavorArgs,
    required this.patrolTestDir,
    required this.loginEmail,
    required this.loginPassword,
    this.stagingAppLabel,
  });

  final String projectName;
  final String projectPath;
  final String flutterExecutable;
  final String deviceName;
  final String entryTarget;
  final String flavorArgs;
  final String patrolTestDir;
  final String loginEmail;
  final String loginPassword;

  /// Short app / env label (e.g. myastro_stg).
  final String? stagingAppLabel;

  String get launchCommand {
    final flavor = flavorArgs.trim().isEmpty ? '' : ' ${flavorArgs.trim()}';
    return '$flutterExecutable run -t $entryTarget$flavor '
        '-d "$deviceName" 2>&1';
  }

  String get appLabel =>
      stagingAppLabel?.trim().isNotEmpty == true
          ? stagingAppLabel!.trim()
          : projectName;
}

/// Resolve sensible defaults from the open project + selected device.
AgentPromptContext buildAgentPromptContext({
  required String projectName,
  required String projectPath,
  required String flutterExecutable,
  required String? deviceName,
  String patrolTestDir = 'patrol_test',
  String? loginEmail,
  String? loginPassword,
  String? entryTargetOverride,
  String? flavorArgsOverride,
  String? stagingAppLabelOverride,
}) {
  final entry = entryTargetOverride ?? _detectEntryTarget(projectPath);
  final flavor = flavorArgsOverride ?? _detectFlavorArgs(projectPath, projectName);
  final label = stagingAppLabelOverride ?? _detectStagingLabel(projectName, flavor);

  return AgentPromptContext(
    projectName: projectName,
    projectPath: projectPath,
    flutterExecutable: flutterExecutable,
    deviceName: (deviceName == null || deviceName.trim().isEmpty)
        ? 'iPhone 17 Pro Max'
        : deviceName.trim(),
    entryTarget: entry,
    flavorArgs: flavor,
    patrolTestDir: patrolTestDir,
    loginEmail: loginEmail ?? 'user@example.com',
    loginPassword: loginPassword ?? 'your_password',
    stagingAppLabel: label,
  );
}

String _detectEntryTarget(String projectPath) {
  const candidates = [
    'lib/main_stg.dart',
    'lib/main_staging.dart',
    'lib/main_dev.dart',
    'lib/main.dart',
  ];
  for (final rel in candidates) {
    if (File(p.join(projectPath, rel)).existsSync()) return rel;
  }
  return 'lib/main.dart';
}

String _detectFlavorArgs(String projectPath, String projectName) {
  // Prefer myastro staging flavor when the project name hints at it.
  final lower = projectName.toLowerCase();
  if (lower.contains('myastro')) {
    return '--flavor=myastro_stg';
  }
  // If only main_stg exists, leave flavor empty unless known.
  if (File(p.join(projectPath, 'lib/main_stg.dart')).existsSync() &&
      lower.contains('astro')) {
    return '--flavor=myastro_stg';
  }
  return '';
}

String? _detectStagingLabel(String projectName, String flavorArgs) {
  final m = RegExp(r'--flavor=([^\s]+)').firstMatch(flavorArgs);
  if (m != null) return m.group(1);
  final lower = projectName.toLowerCase();
  if (lower.contains('myastro')) return 'myastro_stg';
  return null;
}

/// Render a built-in agent prompt with [context] substituted.
String renderAgentPrompt(AgentPromptId id, AgentPromptContext context) {
  switch (id) {
    case AgentPromptId.marionetteCoverageExploration:
      return _marionetteCoverageExplorationPrompt(context);
  }
}

String _marionetteCoverageExplorationPrompt(AgentPromptContext c) {
  final flavorNote = c.flavorArgs.trim().isEmpty
      ? '(no flavor flag - add one if this app requires it)'
      : c.flavorArgs.trim();

  return '''
You are working inside:

${c.projectName}

Project path: ${c.projectPath}

## Objective

Systematically explore the live `${c.appLabel}` Flutter application and maximize maintainable Patrol test coverage using Marionette MCP.

Continue exploring until no additional stable, meaningful, non-duplicate user journeys can be identified.

---

## Current Environment

The project already contains (or should already contain):

- Temporary Marionette instrumentation in staging/debug entrypoints as needed
- `MarionetteBinding.ensureInitialized()` enabled only for debug
- `marionette_flutter` installed
- Patrol configured and working
- Cursor with both Patrol MCP and Marionette MCP enabled (configured by Patroller)

Patroller has prepared Patrol MCP + Marionette MCP for this project. Prefer those MCP tools over ad-hoc shell work when possible.

---

## Startup

Launch the existing staging/debug application using exactly:

${c.launchCommand}

Notes:
- Flutter binary: `${c.flutterExecutable}`
- Entry target: `${c.entryTarget}`
- Flavor args: $flavorNote
- Device: `${c.deviceName}`

Never launch a second simulator.

Never clone or duplicate the running application.

Use only the pinned simulator above.

Capture the Flutter VM Service URI from the terminal and connect Marionette MCP using that URI.

If Marionette disconnects or the VM Service becomes unavailable, rerun the launch command above yourself and reconnect automatically.

Never terminate the simulator unless absolutely required.

---

## Initial Steps

1. Read `AGENTS.md` if present.
2. Inspect the existing project structure.
3. Inspect every existing Patrol test under `${c.patrolTestDir}/`.
4. Learn naming conventions.
5. Learn helpers, fixtures, utilities and shared patterns.
6. Detect existing coverage before creating anything new.

Never create duplicate coverage.

---

## Exploration Workflow

Use Marionette MCP to continuously:

- inspect the widget tree
- enumerate interactive elements
- take screenshots
- inspect logs
- tap
- swipe
- scroll
- enter text
- navigate
- inspect state transitions

For every newly discovered screen:

- identify reachable features
- inspect navigation paths
- inspect dialogs
- inspect bottom sheets
- inspect permissions
- inspect tabs
- inspect forms
- inspect error states
- inspect loading states
- inspect empty states

Continue exploring recursively until all reachable application areas have been exhausted.

Do not stop after generating one or two tests.

---

## Areas To Explore

Explore every reachable area including but not limited to:

- Authentication
- Login
- Logout
- Registration
- Home
- Content
- Rewards
- Store
- Search
- Profile
- Settings
- Onboarding
- Terms & Conditions
- Deep Links
- Native dialogs
- Permissions
- Bottom sheets
- Modals
- Tabs

Also discover any additional areas not listed above.

---

## Marionette Instrumentation

If Marionette cannot detect custom widgets:

Inspect the design system.

Locate custom:

- buttons
- text fields
- cards
- tabs
- lists
- bottom sheets
- custom gesture widgets

Only if necessary:

Add reusable Marionette semantics or metadata that improves discoverability.

Requirements:

- debug only
- staging only
- zero production impact
- reusable
- minimal
- isolated

Never modify:

- production behaviour
- APIs
- navigation
- business logic
- feature flags
- release builds

---

## Patrol Test Generation

Generate Patrol tests only for meaningful uncovered scenarios.

Rules:

- one user journey per test file
- merge only when the journey is identical and only test data differs
- place tests inside the appropriate `${c.patrolTestDir}/` feature folder
- reuse helpers whenever possible
- follow existing architecture
- keep changes small and additive

Coverage should include where applicable:

- navigation
- screen entry
- authentication boundaries
- back navigation
- loading states
- empty states
- retry flows
- pull-to-refresh
- pagination
- search
- filtering
- forms
- validation
- dialogs
- bottom sheets
- permissions
- scrolling
- deep links
- state transitions
- session restoration
- feature-specific actions

Prefer deterministic mock-based tests.

Use hybrid live tests only when mocks cannot reasonably reproduce the behaviour.

Never assert:

- live titles
- backend text
- timestamps
- item counts
- ordering
- dynamic content

Instead assert:

- navigation
- visibility
- structure
- interaction capability
- state transitions

---

## Existing Coverage

Before writing any new test:

Inspect all Patrol tests under `${c.patrolTestDir}/`.

Determine:

- already covered scenarios
- partially covered scenarios
- uncovered scenarios

Never duplicate existing coverage.

---

## Blockers

If automation is blocked because of:

- OTP
- CAPTCHA
- authentication
- third-party integrations
- backend instability
- feature flags
- environment limitations

Document the blocker and continue exploring everything else.

Never stop exploration because one flow is blocked.

---

## Patrol MCP

Use Patrol MCP when appropriate to:

- inspect status
- execute focused tests
- inspect native hierarchy
- capture screenshots
- terminate sessions cleanly

Avoid unnecessary full-suite execution.

---

## Login Credentials

For authenticated exploration, use:

Email:
${c.loginEmail}

Password:
${c.loginPassword}

Use these credentials only when authentication is required.
Treat them as staging/test credentials only.

---

## Hard Rules

Read `AGENTS.md` first.

Never:

- commit
- push
- pull
- merge
- rebase
- branch
- reset
- stash

Do not modify:

- dev entrypoints
- preprod entrypoints
- production entrypoints

Only temporary staging/debug Marionette instrumentation is permitted.

Do not introduce:

- production-only keys
- feature flags
- routes
- APIs
- test hooks

Keep every modification minimal, reusable and maintainable.

---

## Final Report

Provide a comprehensive report including:

- Marionette connection status
- VM Service URI format (without secrets)
- exploration summary
- Patrol MCP operations performed
- files changed
- instrumentation added
- new Patrol tests created
- existing coverage discovered
- remaining coverage gaps
- blocked scenarios and reasons
- focused Patrol execution results
- confirmation that production behaviour was untouched
- estimated coverage improvement

Do not finish until exploration has converged and no further stable, meaningful Patrol scenarios remain.
'''.trim();
}

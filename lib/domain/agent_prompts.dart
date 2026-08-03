import 'dart:io';

import 'package:path/path.dart' as p;

/// Built-in agent routine prompts that Patroller can fill and hand off to
/// OpenCode or any AI IDE (with Patrol MCP + Marionette MCP already configured).
enum AgentPromptId {
  patrolCoverageExploration,
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
    id: AgentPromptId.patrolCoverageExploration,
    title: 'Patrol coverage exploration',
    summary:
        'A filled homework sheet for your AI: explore the live app with MCP, '
        'find scenarios, and write Patrol tests (no duplicates).',
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

  /// Portable Flutter invocation for prompts (`flutter` or `fvm flutter`).
  String get portableFlutterCommand {
    if (_projectUsesFvm(projectPath) ||
        flutterExecutable.toLowerCase().contains('fvm')) {
      return 'fvm flutter';
    }
    return 'flutter';
  }

  /// Portable launch line (PATH / FVM — no absolute host paths).
  String get launchCommand {
    final flavor = flavorArgs.trim().isEmpty ? '' : ' ${flavorArgs.trim()}';
    return '$portableFlutterCommand run -t $entryTarget$flavor';
  }

  /// `package:<name>/<entry under lib/>` for the detected entry target.
  String get packageEntryImport {
    var rel = entryTarget.replaceAll('\\', '/');
    if (rel.startsWith('lib/')) {
      rel = rel.substring(4);
    }
    return 'package:$projectName/$rel';
  }

  String get appLabel =>
      stagingAppLabel?.trim().isNotEmpty == true
          ? stagingAppLabel!.trim()
          : projectName;

  String get deviceHintLine {
    final name = deviceName.trim();
    if (name.isEmpty) {
      return 'the currently selected simulator in Patroller';
    }
    return 'the currently selected simulator in Patroller '
        '(soft hint: `$name`)';
  }
}

bool _projectUsesFvm(String projectPath) {
  return Directory(p.join(projectPath, '.fvm')).existsSync() ||
      File(p.join(projectPath, '.fvmrc')).existsSync();
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
    deviceName: deviceName?.trim() ?? '',
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
    case AgentPromptId.patrolCoverageExploration:
      return _patrolCoverageExplorationPrompt(context);
  }
}

String _patrolCoverageExplorationPrompt(AgentPromptContext c) {
  final flavorNote = c.flavorArgs.trim().isEmpty
      ? '(no flavor flag - add one if this app requires it)'
      : c.flavorArgs.trim();

  return '''
You are a senior QA engineer systematically exploring a Flutter application to
discover and create Patrol end-to-end tests.

## Project

- Name: ${c.projectName}
- Patrol test directory: `${c.patrolTestDir}/`
- Entry target: `${c.entryTarget}`
- Flavor: $flavorNote

Prefer project-relative paths (`lib/`, `${c.patrolTestDir}/`) over absolute host paths.

## Objective

Explore the live Flutter app exhaustively, discover every testable user journey,
and create Patrol tests that provide maximum coverage. Continue until no new
meaningful, non-duplicate scenarios can be found.

---

## Phase 0: Reconnaissance (do this first, before any exploration)

1. Read \`AGENTS.md\` if present.
2. List the project structure: \`lib/\`, \`test/\`, \`${c.patrolTestDir}/\`.
3. Read \`pubspec.yaml\` to understand dependencies (especially patrol, marionette_flutter).
4. Read every existing Patrol test file under \`${c.patrolTestDir}/\`. For each file:
   - Note the test name and what it covers
   - Note helpers, fixtures, and shared utilities
   - Note the naming convention
5. Read \`${c.entryTarget}\` (and any other flavor entry points) to understand app structure.
6. Identify the navigation graph: routes, named routes, go_router, auto_route, etc.
7. Identify state management: Provider, Riverpod, Bloc, GetX, etc.
8. Produce a coverage map: list every screen/feature you know exists, and mark
   which ones already have Patrol tests.

Never create duplicate coverage. If a scenario is already tested, skip it.

---

## Phase 1: Launch and connect

From the project root, launch with the project's Flutter SDK / FVM if configured
(prefer \`${c.portableFlutterCommand}\` on PATH — do not require an absolute Flutter binary):

\`\`\`
${c.launchCommand}
\`\`\`

- Entry target: \`${c.entryTarget}\`
- Flavor: $flavorNote
- Device: ${c.deviceHintLine}

Target the selected simulator with \`-d\` only if needed; treat any device name as a
soft hint, not a machine-locked launch recipe.

Capture the VM Service URI and connect Marionette MCP.

If Marionette disconnects, relaunch and reconnect automatically.
Never launch a second simulator. Never terminate the simulator.

---

## Phase 2: Systematic screen-by-screen exploration

For EVERY screen in the app, perform this checklist:

### 2a: Screen inventory
- What is the screen name / route?
- What widgets are on screen?
- What interactive elements exist (buttons, inputs, lists, tabs, etc.)?

### 2b: User journey discovery
For each screen, discover ALL possible user journeys:

- **Entry paths**: How can a user reach this screen? (tap, deep link, navigation)
- **Exit paths**: Where can a user go from here? (back button, tab switch, link)
- **Actions**: What can the user DO on this screen? (tap buttons, fill forms, scroll)
- **State changes**: What happens after an action? (navigation, dialog, refresh, error)
- **Edge cases**: What happens with empty state, loading, error, retry?

### 2c: Widget interaction matrix
Use Marionette MCP to inspect the widget tree. For each interactive widget:
- What type is it? (ElevatedButton, TextButton, IconButton, GestureDetector, etc.)
- What does it do when tapped?
- Is it conditionally visible? (depends on state, feature flag, auth)
- Does it trigger navigation, API call, dialog, or state change?

### 2d: Navigation graph
Map the complete navigation graph:
- Screen A → tap X → Screen B
- Screen B → back → Screen A
- Screen B → tab 3 → Screen C
- Deep link \`myapp://settings\` → Settings screen

---

## Phase 3: Coverage gap analysis

After exploring each screen, update your coverage map:

| Screen | Has Patrol Test | User Journeys | Priority |
|--------|----------------|---------------|----------|
| Login  | Yes (login_test.dart) | email+password, social login, forgot password | medium |
| Home   | No | feed scroll, pull refresh, tap article | high |
| ...    | ... | ... | ... |

Priority rules:
- **High**: Core user journeys (auth, main content, checkout, etc.)
- **Medium**: Secondary features (search, settings, profile)
- **Low**: Rarely used features, edge cases

Focus on HIGH priority gaps first.

---

## Phase 4: Test creation

For each uncovered scenario, create a Patrol test.

### Test structure rules:
- One user journey per test file
- Place tests in \`${c.patrolTestDir}/<feature>/\`
- Follow existing naming conventions
- Reuse existing helpers and fixtures
- Use \`patrolTest()\` (not \`testWidgets()\`)
- Each test should be independent and deterministic

### Test file template:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import '${c.packageEntryImport}';

void main() {
  patrolTest('<descriptive name>', (PatrolIntegrationTester \$) async {
    await \$.pumpWidgetAndSettle(const MyApp());
    // ... steps ...
  });
}
```

### Assertion rules:
- Assert navigation, visibility, structure, interaction capability
- Assert state transitions
- NEVER assert: live titles, backend text, timestamps, item counts, ordering, dynamic content

### What to test per screen:
- Screen renders without error
- All interactive elements are tappable
- Navigation works (forward and back)
- Forms validate correctly
- Loading states appear and resolve
- Empty states render
- Error states render with retry
- Pull-to-refresh works
- Pagination works
- Search/filter works
- Dialogs/bottom sheets open and dismiss
- Permissions are requested when needed
- Deep links navigate correctly

---

## Phase 5: Validation

After creating each test:
1. Run it with Patrol MCP: \`patrol develop\` for that specific test
2. Verify it passes
3. If it fails, fix and re-run
4. Only mark as complete when the test passes

---

## MCP Tools

Use Patrol MCP when appropriate:
- \`patrol develop\` - run a specific test interactively
- \`native-tree\` - inspect native iOS/Android hierarchy
- \`screenshot\` - capture current screen state
- \`run\` - execute test files

Use Marionette MCP for:
- Inspecting Flutter widget tree
- Finding interactive elements
- Tapping, scrolling, entering text
- Taking screenshots

---

## Login Credentials

For authenticated exploration:
- Email: ${c.loginEmail}
- Password: ${c.loginPassword}

Use only when authentication is required. Treat as staging/test credentials.

---

## Local binding (optional)

Patroller filled these machine-local values for MCP / session binding on this host.
Prefer the portable instructions above when sharing or reusing this prompt.

- Project path: \`${c.projectPath}\`
- Resolved Flutter binary (this machine): \`${c.flutterExecutable}\`
- Selected device name: ${c.deviceName.trim().isEmpty ? '(none selected)' : '`${c.deviceName}`'}

---

## Blockers

If blocked by OTP, CAPTCHA, auth, third-party integrations, or backend issues:
1. Document the blocker
2. Continue exploring everything else
3. Never stop because one flow is blocked

---

## Hard Rules

Read \`AGENTS.md\` first.

Never: commit, push, pull, merge, rebase, branch, reset, stash.

Do not modify: dev entrypoints, preprod entrypoints, production entrypoints.

Only temporary staging/debug Marionette instrumentation is permitted.

Do not introduce: production-only keys, feature flags, routes, APIs, test hooks.

Keep every modification minimal, reusable, and maintainable.

---

## Final Report

Provide a comprehensive report:

- **Coverage map**: Every screen explored, test status, gaps identified
- **Tests created**: File paths, what each tests, line count
- **Existing tests discovered**: File paths, what each covers
- **Navigation graph**: Complete screen-to-screen map
- **Blocked scenarios**: What couldn't be tested and why
- **Coverage improvement**: Before/after estimate
- **Confirmation**: Production code untouched

Do not finish until exploration has converged and no further stable, meaningful
Patrol scenarios remain.
'''.trim();
}

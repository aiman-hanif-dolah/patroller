import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/landing/landing_screen.dart';
import 'features/shell/app_shell.dart';
import 'models/enums.dart';
import 'providers/app_provider.dart';
import 'providers/log_provider.dart';
import 'providers/runner_provider.dart';
import 'providers/settings_provider.dart';
import 'core/theme/patrol_theme.dart';

class PatrollerApp extends ConsumerWidget {
  const PatrollerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsLoaded = ref.watch(settingsProvider).loaded;
    final theme = ref.watch(settingsProvider.select((s) => s.settings.theme));
    final activeView = ref.watch(appProvider).activeView;

    // Extension server lifecycle is owned by settingsProvider
    // (_applyExtensionServer). Do not start it here - that orphans servers.

    return MaterialApp(
      title: 'Patroller',
      debugShowCheckedModeBanner: false,
      theme: PatrolTheme.light(),
      darkTheme: PatrolTheme.dark(),
      themeMode: switch (theme) {
        AppTheme.light => ThemeMode.light,
        AppTheme.dark => ThemeMode.dark,
        AppTheme.system => ThemeMode.system,
      },
      home: settingsLoaded
          ? Shortcuts(
              shortcuts: _shortcuts,
              child: Actions(
                actions: _buildActions(ref),
                child: Focus(
                  autofocus: true,
                  child: activeView == AppView.landing
                      ? const LandingScreen()
                      : const AppShell(),
                ),
              ),
            )
          : const Scaffold(
              body: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
    );
  }

  static final _shortcuts = <ShortcutActivator, Intent>{
    const SingleActivator(LogicalKeyboardKey.keyO, meta: true):
        OpenProjectIntent(),
    const SingleActivator(LogicalKeyboardKey.keyR, meta: true):
        RunSelectedIntent(),
    const SingleActivator(
      LogicalKeyboardKey.keyR,
      meta: true,
      shift: true,
    ): RunAllIntent(),
    const SingleActivator(LogicalKeyboardKey.keyD, meta: true):
        DevelopIntent(),
    const SingleActivator(LogicalKeyboardKey.period, meta: true): StopIntent(),
    const SingleActivator(LogicalKeyboardKey.keyK, meta: true):
        ClearLogsIntent(),
    const SingleActivator(LogicalKeyboardKey.keyF, meta: true):
        FocusLogSearchIntent(),
  };

  static Map<Type, Action<Intent>> _buildActions(WidgetRef ref) {
    return {
      OpenProjectIntent: CallbackAction<OpenProjectIntent>(
        onInvoke: (_) {
          ref.read(appProvider.notifier).openProject();
          return null;
        },
      ),
      RunSelectedIntent: CallbackAction<RunSelectedIntent>(
        onInvoke: (_) {
          ref.read(runnerProvider.notifier).runSelected();
          return null;
        },
      ),
      RunAllIntent: CallbackAction<RunAllIntent>(
        onInvoke: (_) {
          ref.read(runnerProvider.notifier).runAll();
          return null;
        },
      ),
      DevelopIntent: CallbackAction<DevelopIntent>(
        onInvoke: (_) {
          ref.read(runnerProvider.notifier).develop();
          return null;
        },
      ),
      StopIntent: CallbackAction<StopIntent>(
        onInvoke: (_) {
          ref.read(runnerProvider.notifier).stop();
          return null;
        },
      ),
      ClearLogsIntent: CallbackAction<ClearLogsIntent>(
        onInvoke: (_) {
          ref.read(logProvider.notifier).clearLogs();
          return null;
        },
      ),
      FocusLogSearchIntent: CallbackAction<FocusLogSearchIntent>(
        onInvoke: (_) => null,
      ),
    };
  }
}

class OpenProjectIntent extends Intent {
  const OpenProjectIntent();
}

class RunSelectedIntent extends Intent {
  const RunSelectedIntent();
}

class RunAllIntent extends Intent {
  const RunAllIntent();
}

class DevelopIntent extends Intent {
  const DevelopIntent();
}

class StopIntent extends Intent {
  const StopIntent();
}

class ClearLogsIntent extends Intent {
  const ClearLogsIntent();
}

class FocusLogSearchIntent extends Intent {
  const FocusLogSearchIntent();
}
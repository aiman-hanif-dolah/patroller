import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/patrol_studio_facade.dart';
import 'facade_provider.dart';
import 'health_provider.dart';
import 'runner_provider.dart';
import 'settings_provider.dart';

enum AppView { landing, project }

class AppState {
  const AppState({
    this.currentProject,
    this.recentProjects = const [],
    this.testFiles = const [],
    this.selectedFile,
    this.selectedTestCase,
    this.selectedFileIds = const {},
    this.isLoadingProject = false,
    this.isScanning = false,
    this.error,
    this.projectError,
    this.scanError,
    this.healthStale = false,
    this.healthWarningCount,
    this.activeView = AppView.landing,
  });

  final ProjectMetadata? currentProject;
  final List<RecentProject> recentProjects;
  final List<TestFile> testFiles;
  final TestFile? selectedFile;
  final TestCase? selectedTestCase;
  final Set<String> selectedFileIds;
  final bool isLoadingProject;
  final bool isScanning;
  final String? error;
  final String? projectError;
  final String? scanError;
  final bool healthStale;
  final int? healthWarningCount;
  final AppView activeView;

  AppState copyWith({
    ProjectMetadata? currentProject,
    List<RecentProject>? recentProjects,
    List<TestFile>? testFiles,
    TestFile? selectedFile,
    TestCase? selectedTestCase,
    Set<String>? selectedFileIds,
    bool? isLoadingProject,
    bool? isScanning,
    String? error,
    String? projectError,
    String? scanError,
    bool? healthStale,
    int? healthWarningCount,
    AppView? activeView,
    bool clearProject = false,
    bool clearSelectedFile = false,
    bool clearSelectedTestCase = false,
    bool clearError = false,
    bool clearProjectError = false,
    bool clearScanError = false,
  }) {
    return AppState(
      currentProject: clearProject
          ? null
          : (currentProject ?? this.currentProject),
      recentProjects: recentProjects ?? this.recentProjects,
      testFiles: testFiles ?? this.testFiles,
      selectedFile: clearSelectedFile
          ? null
          : (selectedFile ?? this.selectedFile),
      selectedTestCase: clearSelectedTestCase
          ? null
          : (selectedTestCase ?? this.selectedTestCase),
      selectedFileIds: selectedFileIds ?? this.selectedFileIds,
      isLoadingProject: isLoadingProject ?? this.isLoadingProject,
      isScanning: isScanning ?? this.isScanning,
      error: clearError ? null : (error ?? this.error),
      projectError:
          clearProjectError ? null : (projectError ?? this.projectError),
      scanError: clearScanError ? null : (scanError ?? this.scanError),
      healthStale: healthStale ?? this.healthStale,
      healthWarningCount: healthWarningCount ?? this.healthWarningCount,
      activeView: activeView ?? this.activeView,
    );
  }
}

class AppNotifier extends StateNotifier<AppState> {
  AppNotifier(this._ref) : super(const AppState());

  final Ref _ref;

  PatrolStudioFacade get _facade => _ref.read(patrolStudioFacadeProvider);

  Future<void> _restoreLastProject() async {
    final settingsState = _ref.read(settingsProvider);
    if (!settingsState.loaded) {
      await _ref.read(settingsProvider.notifier).load();
    }
    final lastPath = _ref.read(settingsProvider).settings.lastProjectPath;
    if (lastPath == null) return;
    try {
      final project = await _facade.project.validate(lastPath);
      if (!project.hasPubspecYaml) return;
      _showProject(project);
      await _finishProjectLoad(project);
    } catch (_) {}
  }

  void ensureInitialized() {
    if (state.currentProject == null && state.activeView == AppView.landing) {
      unawaited(_restoreLastProject());
      unawaited(loadRecentProjects());
    }
  }

  Future<void> loadRecentProjects() async {
    final projects = await _facade.project.getRecent();
    state = state.copyWith(recentProjects: projects);
  }

  Future<void> openProject() async {
    state = state.copyWith(
      isLoadingProject: true,
      clearError: true,
      clearProjectError: true,
    );
    try {
      final result = await _facade.project.open();
      if (result == null) return;
      if (!result.hasPubspecYaml) {
        state = state.copyWith(
          projectError:
              'No pubspec.yaml found. Choose a Flutter project root folder.',
        );
        return;
      }
      _showProject(result);
      unawaited(_finishProjectLoad(result));
    } catch (e) {
      final message = e.toString();
      state = state.copyWith(error: message);
      _ref.read(runnerProvider.notifier).showSnackbar(message);
    } finally {
      state = state.copyWith(isLoadingProject: false);
    }
  }

  Future<void> openRecent(RecentProject recent) async {
    if (!recent.exists) return;
    state = state.copyWith(
      isLoadingProject: true,
      clearError: true,
      clearProjectError: true,
    );
    try {
      final result = await _facade.project.validate(recent.path);
      _showProject(result);
      unawaited(_finishProjectLoad(result));
    } catch (e) {
      state = state.copyWith(error: e.toString());
    } finally {
      state = state.copyWith(isLoadingProject: false);
    }
  }

  Future<void> removeRecent(String path) async {
    await _facade.project.removeRecent(path);
    state = state.copyWith(
      recentProjects:
          state.recentProjects.where((p) => p.path != path).toList(),
    );
  }

  void _showProject(ProjectMetadata project) {
    _ref.read(healthProvider.notifier).markUnchecked();
    state = state.copyWith(
      currentProject: project,
      activeView: AppView.project,
      testFiles: [],
      selectedFileIds: {},
      clearSelectedFile: true,
      clearSelectedTestCase: true,
      clearScanError: true,
      healthStale: true,
      healthWarningCount: null,
      isScanning: true,
    );
  }

  Future<void> _finishProjectLoad(ProjectMetadata project) async {
    try {
      await _facade.project.addRecent(project);
      await _ref.read(settingsProvider.notifier).updatePartial({
        'lastProjectPath': project.projectPath,
      });
      await scanTests();
      await _ref.read(runnerProvider.notifier).loadDevices();
      await loadRecentProjects();
    } catch (e) {
      state = state.copyWith(
        projectError: e.toString(),
        isScanning: false,
      );
      _ref.read(runnerProvider.notifier).showSnackbar(e.toString());
    }
  }

  Future<void> scanTests() async {
    final project = state.currentProject;
    if (project == null) return;
    state = state.copyWith(isScanning: true, clearScanError: true);
    try {
      final files = await _facade.project.scan(project.projectPath);
      state = state.copyWith(testFiles: files, clearError: true);
    } catch (e) {
      state = state.copyWith(
        testFiles: [],
        scanError: e.toString(),
      );
    } finally {
      state = state.copyWith(isScanning: false);
    }
  }

  void setSelectedFile(TestFile? file) {
    state = state.copyWith(
      selectedFile: file,
      clearSelectedTestCase: file == null,
    );
  }

  void setSelectedTestCase(TestCase? testCase) {
    state = state.copyWith(selectedTestCase: testCase);
  }

  void toggleFileSelection(String fileId) {
    final next = Set<String>.from(state.selectedFileIds);
    if (next.contains(fileId)) {
      next.remove(fileId);
    } else {
      next.add(fileId);
    }
    state = state.copyWith(selectedFileIds: next);
  }

  void selectAllFiles(bool select) {
    state = state.copyWith(
      selectedFileIds: select
          ? state.testFiles
              .where((f) => f.detectedTestCount > 0)
              .map((f) => f.absolutePath)
              .toSet()
          : {},
    );
  }

  void setHealthWarningCount(int? count) {
    state = state.copyWith(healthWarningCount: count);
  }

  void setHealthStale(bool stale) {
    state = state.copyWith(healthStale: stale);
  }

  void updateTestFileRunResult(
    String filePath,
    TestStatus status,
    int? durationMs,
  ) {
    final now = DateTime.now().toUtc().toIso8601String();
    TestFile patchFile(TestFile file) => TestFile(
          absolutePath: file.absolutePath,
          relativePath: file.relativePath,
          fileName: file.fileName,
          folderPath: file.folderPath,
          fileSize: file.fileSize,
          lastModified: file.lastModified,
          detectedTestCount: file.detectedTestCount,
          detectedGroups: file.detectedGroups,
          detectedTests: file.detectedTests,
          lastRunStatus: status,
          lastRunDuration: durationMs,
          lastRunTime: now,
          content: file.content,
        );

    final files = state.testFiles
        .map((file) => file.absolutePath == filePath ? patchFile(file) : file)
        .toList();
    final selected = state.selectedFile?.absolutePath == filePath
        ? patchFile(state.selectedFile!)
        : state.selectedFile;
    state = state.copyWith(testFiles: files, selectedFile: selected);
  }
}

final appProvider = StateNotifierProvider<AppNotifier, AppState>(
  (ref) {
    final notifier = AppNotifier(ref);
    Future.microtask(notifier.ensureInitialized);
    return notifier;
  },
);
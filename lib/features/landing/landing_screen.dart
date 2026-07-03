import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/patrol_colors.dart';
import '../../providers/app_provider.dart';
import '../../widgets/patrol_card.dart';

class LandingScreen extends ConsumerStatefulWidget {
  const LandingScreen({super.key});

  @override
  ConsumerState<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends ConsumerState<LandingScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(appProvider.notifier).loadRecentProjects(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appProvider);
    final isLoading = app.isLoadingProject;

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.keyO &&
            HardwareKeyboard.instance.isMetaPressed) {
          ref.read(appProvider.notifier).openProject();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        backgroundColor: PatrolColors.obsidian,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: PatrolColors.snow,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.layers_outlined,
                      size: 36,
                      color: PatrolColors.obsidian,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Patroller',
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          color: PatrolColors.ink,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'A local visual runner for Flutter Patrol tests',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: PatrolColors.steel,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),
                  if (app.projectError != null || app.error != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: PatrolColors.rose300.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: PatrolColors.rose300.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        app.projectError ?? app.error ?? '',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: PatrolColors.rose300,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: isLoading
                          ? null
                          : () => ref.read(appProvider.notifier).openProject(),
                      icon: const Icon(Icons.folder_open, size: 20),
                      label: Text(
                        isLoading ? 'Opening...' : 'Open Flutter Project',
                        style: const TextStyle(fontSize: 16),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: PatrolColors.snow,
                        foregroundColor: PatrolColors.obsidian,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(36),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text.rich(
                    TextSpan(
                      style: const TextStyle(
                        color: PatrolColors.steel,
                        fontSize: 10,
                      ),
                      children: [
                        const TextSpan(text: 'or press '),
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: PatrolColors.fog,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              '⌘O',
                              style: TextStyle(
                                color: PatrolColors.graphite,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (app.recentProjects.isNotEmpty) ...[
                    const SizedBox(height: 64),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'RECENT PROJECTS',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...app.recentProjects.map((project) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: PatrolCard(
                          child: InkWell(
                            onTap: project.exists
                                ? () => ref
                                    .read(appProvider.notifier)
                                    .openRecent(project)
                                : null,
                            borderRadius: BorderRadius.circular(20),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: PatrolColors.fog,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: const Icon(
                                      Icons.folder_open,
                                      color: PatrolColors.steel,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                project.name,
                                                style: const TextStyle(
                                                  color: PatrolColors.ink,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (!project.exists)
                                              Container(
                                                margin: const EdgeInsets.only(
                                                  left: 8,
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: const Color(0x667C2D12),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: const Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons.warning_amber,
                                                      size: 10,
                                                      color:
                                                          PatrolColors.orange400,
                                                    ),
                                                    SizedBox(width: 4),
                                                    Text(
                                                      'Missing',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color: PatrolColors
                                                            .orange400,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          project.path,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: PatrolColors.steel,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Text(
                                    'Open →',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: PatrolColors.steel,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                  const SizedBox(height: 64),
                  const Text(
                    'Unofficial local developer tool for Flutter Patrol tests',
                    style: TextStyle(fontSize: 10, color: PatrolColors.pebble),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
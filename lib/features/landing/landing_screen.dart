import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/patrol_colors.dart';
import '../../providers/app_provider.dart';
import '../../widgets/patrol_card.dart';
import '../../widgets/patrol_components.dart';

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
        body: Stack(
          children: [
            Positioned(
              top: -120,
              right: -80,
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      PatrolColors.amber.withValues(alpha: 0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 580),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const PatrolBrandMark(size: 88),
                      const SizedBox(height: 28),
                      Text(
                        'Patroller',
                        style: Theme.of(context).textTheme.displayLarge?.copyWith(
                              color: PatrolColors.ink,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1,
                            ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'A local visual runner for Flutter Patrol tests',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: PatrolColors.steel,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 40),
                      if (app.projectError != null || app.error != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: PatrolColors.psFailed.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(PatrolRadius.card),
                            border: Border.all(
                              color: PatrolColors.psFailed.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                size: 18,
                                color: PatrolColors.red400,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  app.projectError ?? app.error ?? '',
                                  style: const TextStyle(
                                    color: PatrolColors.rose300,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                      SizedBox(
                        width: double.infinity,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: PatrolGradients.brandGlow,
                            borderRadius: BorderRadius.circular(PatrolRadius.pill),
                            boxShadow: PatrolShadows.glow(PatrolColors.amber, blur: 20),
                          ),
                          child: FilledButton.icon(
                            onPressed: isLoading
                                ? null
                                : () => ref.read(appProvider.notifier).openProject(),
                            icon: isLoading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.folder_open_rounded, size: 20),
                            label: Text(
                              isLoading ? 'Opening...' : 'Open Flutter Project',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: PatrolColors.obsidian,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(PatrolRadius.pill),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      PatrolMetaChip(
                        label: '⌘O to open',
                        icon: Icons.keyboard_command_key,
                        accent: true,
                      ),
                      if (app.recentProjects.isNotEmpty) ...[
                        const SizedBox(height: 56),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: PatrolEyebrow('Recent projects'),
                        ),
                        const SizedBox(height: 14),
                        ...app.recentProjects.map((project) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: PatrolCard(
                              accentStrip: project.exists,
                              child: InkWell(
                                onTap: project.exists
                                    ? () => ref
                                        .read(appProvider.notifier)
                                        .openRecent(project)
                                    : null,
                                borderRadius: BorderRadius.circular(PatrolRadius.panel),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Row(
                                    children: [
                                      PatrolAvatar(
                                        icon: Icons.folder_rounded,
                                        color: project.exists
                                            ? PatrolColors.amber
                                            : PatrolColors.steel,
                                        size: 40,
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    project.name,
                                                    style: const TextStyle(
                                                      color: PatrolColors.ink,
                                                      fontWeight: FontWeight.w600,
                                                      fontSize: 14,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                if (!project.exists)
                                                  const PatrolMetaChip(
                                                    label: 'Missing',
                                                    icon: Icons.warning_amber_rounded,
                                                    color: PatrolColors.orange400,
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
                                      Icon(
                                        Icons.arrow_forward_rounded,
                                        size: 14,
                                        color: project.exists
                                            ? PatrolColors.amber
                                            : PatrolColors.ash,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                      const SizedBox(height: 56),
                      const Text(
                        'Unofficial local developer tool for Flutter Patrol tests',
                        style: TextStyle(fontSize: 10, color: PatrolColors.pebble),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
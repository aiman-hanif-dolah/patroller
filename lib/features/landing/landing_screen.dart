import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

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
    final p = PatrolPalette.of(context);
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
        backgroundColor: p.surface,
        body: Stack(
          children: [
            Positioned(
              top: -140,
              right: -100,
              child: Container(
                width: 360,
                height: 360,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      PatrolColors.brandViolet.withValues(alpha: 0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -80,
              left: -60,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      PatrolColors.signalBlue.withValues(alpha: 0.06),
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
                              color: p.textDisplay,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1.6,
                            ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'A local visual runner for Flutter Patrol tests',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: p.textSecondary,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 40),
                      if (app.projectError != null || app.error != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: PatrolColors.psFailed.withValues(alpha: 0.08),
                            borderRadius:
                                BorderRadius.circular(PatrolRadius.card),
                            border: Border.all(
                              color: PatrolColors.psFailed.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                size: 18,
                                color: PatrolColors.psFailed,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  app.projectError ?? app.error ?? '',
                                  style: const TextStyle(
                                    color: PatrolColors.psFailed,
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
                        child: FilledButton.icon(
                          onPressed: isLoading
                              ? null
                              : () =>
                                  ref.read(appProvider.notifier).openProject(),
                          icon: const Icon(Icons.folder_open_rounded, size: 20),
                          label: Text(
                            isLoading ? 'Opening...' : 'Open Flutter Project',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: p.text,
                            foregroundColor: p.surface,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(PatrolRadius.pill),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const PatrolMetaChip(
                        label: '⌘O to open',
                        icon: Icons.keyboard_command_key,
                        accent: true,
                        color: PatrolColors.signalBlue,
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
                                borderRadius:
                                    BorderRadius.circular(PatrolRadius.panel),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Row(
                                    children: [
                                      PatrolAvatar(
                                        icon: Icons.folder_rounded,
                                        color: project.exists
                                            ? PatrolColors.brandViolet
                                            : p.textMuted,
                                        size: 40,
                                      ),
                                      const SizedBox(width: 14),
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
                                                    style: GoogleFonts
                                                        .plusJakartaSans(
                                                      color: p.text,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 14,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                if (!project.exists)
                                                  const PatrolMetaChip(
                                                    label: 'Missing',
                                                    icon: Icons
                                                        .warning_amber_rounded,
                                                    color:
                                                        PatrolColors.orange400,
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              project.path,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: p.textMuted,
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
                                            ? PatrolColors.signalBlue
                                            : p.textFaint,
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
                      Text(
                        'Unofficial local developer tool for Flutter Patrol tests',
                        style: TextStyle(fontSize: 11, color: p.textFaint),
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

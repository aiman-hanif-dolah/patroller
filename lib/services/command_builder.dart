import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/models.dart';

class PatrolCommand {
  const PatrolCommand({
    required this.cmd,
    required this.args,
    required this.display,
  });

  final String cmd;
  final List<String> args;
  final String display;
}

class PatrolCommandInput {
  const PatrolCommandInput({
    required this.config,
    required this.patrolExecutable,
    this.extraPatrolArgs,
  });

  final RunConfig config;
  final String patrolExecutable;
  final List<String>? extraPatrolArgs;
}

String toProjectRelativePath(String projectPath, String filePath) {
  if (!p.isAbsolute(filePath)) {
    return filePath.replaceAll('\\', '/');
  }

  try {
    final project = Directory(projectPath).resolveSymbolicLinksSync();
    final file = File(filePath).resolveSymbolicLinksSync();
    final relative = p.relative(file, from: project);
    return relative.replaceAll('\\', '/');
  } catch (_) {
    return filePath.replaceAll('\\', '/');
  }
}

List<String> _developTargetArgs(RunConfig config) {
  final target = config.targetFile?.trim() ?? '';
  if (target.isEmpty) {
    throw ArgumentError(
      'Patrol develop requires exactly one --target test file.',
    );
  }
  return [
    '--target',
    toProjectRelativePath(config.projectPath, target),
  ];
}

PatrolCommand buildPatrolCommand(PatrolCommandInput input) {
  final config = input.config;
  final args = <String>[];

  switch (config.runMode) {
    case RunMode.fullSuite:
      args.add('test');
      break;
    case RunMode.develop:
      args.add('develop');
      args.addAll(_developTargetArgs(config));
      break;
    case RunMode.developSuite:
      args.add('develop');
      args.addAll(_developTargetArgs(config));
      break;
    case RunMode.test:
      args.addAll([
        'test',
        '--target',
        toProjectRelativePath(
          config.projectPath,
          config.targetFile ?? '',
        ),
      ]);
      break;
  }

  if (input.extraPatrolArgs != null && input.extraPatrolArgs!.isNotEmpty) {
    args.addAll(input.extraPatrolArgs!);
  }

  if (config.extraArgs != null) {
    args.addAll(config.extraArgs!);
  }

  if (config.deviceId != null && config.deviceId!.isNotEmpty) {
    args.addAll(['-d', config.deviceId!]);
  }

  final display = '${input.patrolExecutable} ${args.join(' ')}';
  return PatrolCommand(cmd: input.patrolExecutable, args: args, display: display);
}
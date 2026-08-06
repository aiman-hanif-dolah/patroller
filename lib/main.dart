import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'services/crash_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  CrashService.instance.initialize();
  runApp(
    const ProviderScope(
      child: PatrollerApp(),
    ),
  );
}
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_provider.dart';
import 'health_provider.dart';

void markHealthStale(Ref ref) {
  ref.read(healthProvider.notifier).markStale();
  ref.read(appProvider.notifier).setHealthStale(true);
}
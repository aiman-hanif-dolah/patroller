import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/patrol_studio_facade.dart';

final patrolStudioFacadeProvider = Provider<PatrolStudioFacade>(
  (ref) => PatrolStudioFacade.instance,
);
import 'package:flutter_test/flutter_test.dart';
import 'package:patroller/domain/simulator_user_apps.dart';
import 'package:patroller/models/hierarchy.dart';

void main() {
  group('parseSimulatorUserBundleIds', () {
    test('extracts user apps and excludes Apple bundles', () {
      const output = '''
== Apps installed on ABC ==
    com.apple.springboard = {
    };
    com.example.myapp = {
    };
    studio.patrol.PatrolSimulatorDriverUITests.xctrunner = {
    };
''';
      expect(
        parseSimulatorUserBundleIds(
          output,
          excludeBundleId:
              'studio.patrol.PatrolSimulatorDriverUITests.xctrunner',
        ),
        ['com.example.myapp'],
      );
    });
  });

  group('isInspectableHierarchyEmpty', () {
    test('returns true for stub nodes', () {
      expect(
        isInspectableHierarchyEmpty(const HierarchyNode(type: 'stub')),
        isTrue,
      );
    });
  });
}
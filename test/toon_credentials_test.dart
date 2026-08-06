import 'package:flutter_test/flutter_test.dart';
import 'package:patroller/models/test_user_credential.dart';

void main() {
  group('TestUserCredential TOON format', () {
    test('serializes and parses list of user credentials accurately', () {
      final creds = [
        const TestUserCredential(
          id: 'user_1',
          name: 'User 1 / Prareg097',
          username: 'prareg-097@yopmail.com',
          password: 'Astro@123',
          env: TargetEnvironment.stg,
          userMode: UserMode.live,
        ),
        const TestUserCredential(
          id: 'user_2',
          name: 'Mock User Default',
          username: 'mock-user@example.com',
          password: 'MockPassword123',
          env: TargetEnvironment.prod,
          userMode: UserMode.mock,
        ),
      ];

      final toonString = TestUserCredential.encodeToonList(creds);
      expect(toonString, contains('[User: User 1 / Prareg097]'));
      expect(toonString, contains('username: prareg-097@yopmail.com'));
      expect(toonString, contains('password: Astro@123'));
      expect(toonString, contains('env: stg'));
      expect(toonString, contains('mode: live'));

      final parsed = TestUserCredential.parseToonList(toonString);
      expect(parsed.length, 2);
      expect(parsed[0].name, 'User 1 / Prareg097');
      expect(parsed[0].username, 'prareg-097@yopmail.com');
      expect(parsed[0].password, 'Astro@123');
      expect(parsed[0].env, TargetEnvironment.stg);
      expect(parsed[0].userMode, UserMode.live);

      expect(parsed[1].name, 'Mock User Default');
      expect(parsed[1].env, TargetEnvironment.prod);
      expect(parsed[1].userMode, UserMode.mock);
    });
  });
}

import 'package:test/test.dart';
import 'package:cozy_focus_app/domain/services/focus_clock.dart';

void main() {
  group('SystemFocusClock', () {
    test('now() returns a DateTime close to real time', () {
      final clock = SystemFocusClock();
      final before = DateTime.now();
      final result = clock.now();
      final after = DateTime.now();
      expect(result.isAfter(before.subtract(const Duration(seconds: 1))), isTrue);
      expect(result.isBefore(after.add(const Duration(seconds: 1))), isTrue);
    });
  });
}

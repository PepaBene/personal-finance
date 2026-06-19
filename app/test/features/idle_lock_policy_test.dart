import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerly_app/src/features/lock/auto_lock_scope.dart';

void main() {
  test('disabled when minutes is zero', () {
    const p = IdleLockPolicy(0);
    expect(p.enabled, isFalse);
    expect(p.timeout, isNull);
    expect(p.exceeded(const Duration(hours: 1)), isFalse);
  });

  test('enabled produces a matching timeout', () {
    const p = IdleLockPolicy(5);
    expect(p.enabled, isTrue);
    expect(p.timeout, const Duration(minutes: 5));
  });

  test('exceeded is true only at/over the timeout', () {
    const p = IdleLockPolicy(5);
    expect(p.exceeded(const Duration(minutes: 4, seconds: 59)), isFalse);
    expect(p.exceeded(const Duration(minutes: 5)), isTrue);
    expect(p.exceeded(const Duration(minutes: 10)), isTrue);
  });
}

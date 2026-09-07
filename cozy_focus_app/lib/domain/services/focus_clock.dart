/// Abstraction over time — injectable for tests.
/// Production implementation uses DateTime.now() directly.
/// Never use Timer.periodic ticks as elapsed-time fact source.
abstract interface class FocusClock {
  DateTime now();
}

class SystemFocusClock implements FocusClock {
  const SystemFocusClock();

  @override
  DateTime now() => DateTime.now();
}

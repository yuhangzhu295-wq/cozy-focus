import 'dart:math';

/// The injectable source of randomness behind behaviour selection.
///
/// ## Why this is an interface and not `Random()`
///
/// `docs/01_Companion_Runtime_Architecture_SPEC.md` §8 requires that production
/// uses natural randomness while tests inject a fixed seed, so a behaviour test
/// can never be flaky. A bare `Random()` reached from inside the director would
/// make "which pose did Mochi pick" untestable.
///
/// The interface is intentionally tiny — two draws — so a test double is trivial
/// and a future weighted sampler does not have to widen the contract.
abstract class RandomSource {
  /// A double in `[0.0, 1.0)`.
  double nextDouble();

  /// An int in `[0, max)`; `max` must be positive.
  int nextInt(int max);

  /// A duration uniformly distributed across `[min, max]` inclusive.
  Duration durationBetween(Duration min, Duration max);
}

/// Production randomness.
class SystemRandomSource implements RandomSource {
  final Random _random;

  SystemRandomSource([Random? random]) : _random = random ?? Random();

  @override
  double nextDouble() => _random.nextDouble();

  @override
  int nextInt(int max) => _random.nextInt(max);

  @override
  Duration durationBetween(Duration min, Duration max) {
    final lo = min.inMilliseconds;
    final hi = max.inMilliseconds;
    if (hi <= lo) return min;
    return Duration(milliseconds: lo + _random.nextInt(hi - lo + 1));
  }
}

/// Deterministic randomness for tests.
///
/// Same contract, fixed seed, so two runs of the same test produce the same
/// behaviour sequence.
class SeededRandomSource implements RandomSource {
  final Random _random;

  SeededRandomSource(int seed) : _random = Random(seed);

  @override
  double nextDouble() => _random.nextDouble();

  @override
  int nextInt(int max) => _random.nextInt(max);

  @override
  Duration durationBetween(Duration min, Duration max) {
    final lo = min.inMilliseconds;
    final hi = max.inMilliseconds;
    if (hi <= lo) return min;
    return Duration(milliseconds: lo + _random.nextInt(hi - lo + 1));
  }
}

/// A random source that always answers the same way.
///
/// Used where a test needs a *specific* decision rather than merely a repeatable
/// one — for example to force the deepest eligible behaviour or to make a
/// probability gate always open or always closed.
class FixedRandomSource implements RandomSource {
  /// Returned by [nextDouble]; also used as the fraction for durations.
  final double value;

  /// Returned by [nextInt], clamped into range.
  final int index;

  const FixedRandomSource({this.value = 0.0, this.index = 0});

  @override
  double nextDouble() => value;

  @override
  int nextInt(int max) => max <= 0 ? 0 : index.clamp(0, max - 1);

  @override
  Duration durationBetween(Duration min, Duration max) {
    final lo = min.inMilliseconds;
    final hi = max.inMilliseconds;
    if (hi <= lo) return min;
    return Duration(milliseconds: lo + ((hi - lo) * value).round());
  }
}

/// Stable identity for a companion.
///
/// Deliberately a plain value type rather than a closed enum: the whole point of
/// the V4.2.1 runtime is that a fourth companion is a *data* addition (one
/// profile, one pose pack, one visual-provider registration) rather than a code
/// edit. A closed enum would force every `switch` to grow a case — exactly the
/// generic-species-branch the spec forbids.
///
/// Nothing in the generic runtime may compare against a literal id. Pages ask
/// the catalog for a profile; only leaf visual providers know a species by name.
class CompanionId {
  /// The wire id. Matches the profile key in `assets/companion/companion_profiles.json`.
  final String value;

  const CompanionId(this.value);

  /// The companion a fresh install starts with.
  static const CompanionId dog = CompanionId('dog');
  static const CompanionId cat = CompanionId('cat');
  static const CompanionId rabbit = CompanionId('rabbit');

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CompanionId &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'CompanionId($value)';
}

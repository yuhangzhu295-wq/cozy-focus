import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/presentation/companion/pack/companion_pack_archive_policy.dart';
import 'package:cozy_focus_app/presentation/companion/pack/companion_pack_validator.dart';

/// P32 — a pack archive is hostile input until it proves otherwise.
///
/// Every case here is an archive that is *well formed*: a reader will list it,
/// and the entries are real. They are refused because of what extracting them
/// would do, which is the class of failure a malformed-file check does not catch.
void main() {
  PackArchiveEntry file(String name, {int size = 1024, int compressed = 512}) =>
      PackArchiveEntry(
        name: name,
        uncompressedSize: size,
        compressedSize: compressed,
      );

  PackValidationResult inspect(
    List<PackArchiveEntry> entries, {
    PackArchiveLimits limits = PackArchiveLimits.standard,
  }) =>
      CompanionPackArchivePolicy.inspect(entries: entries, limits: limits);

  test('an ordinary pack is allowed', () {
    final result = inspect([
      file('manifest.json', size: 900, compressed: 400),
      file('idle_000.png'),
      file('idle_001.png'),
      file('walk_000.png'),
    ]);
    expect(result.ok, isTrue, reason: '$result');
  });

  group('sandbox escape', () {
    test('a traversal entry is refused', () {
      expect(inspect([file('../../etc/passwd')]).codes,
          contains('unsafe_entry_path'));
    });

    test('an absolute entry is refused', () {
      expect(
          inspect([file('/etc/passwd')]).codes, contains('unsafe_entry_path'));
      expect(inspect([file(r'C:\Windows\system32\x.dll')]).codes,
          contains('unsafe_entry_path'));
    });

    test('a null byte in a name is refused', () {
      expect(inspect([file('idle\u0000.png')]).codes,
          contains('unsafe_entry_path'));
    });
  });

  group('resource exhaustion', () {
    test('too many entries is refused', () {
      final many = [for (var i = 0; i < 40; i++) file('f_$i.png')];
      const tight = PackArchiveLimits(
        maxEntries: 16,
        maxEntryBytes: 1 << 20,
        maxTotalBytes: 1 << 30,
        maxExpansionRatio: 200,
      );
      expect(inspect(many, limits: tight).codes, contains('too_many_entries'));
    });

    test('a single oversized entry is refused', () {
      const tight = PackArchiveLimits(
        maxEntries: 16,
        maxEntryBytes: 4096,
        maxTotalBytes: 1 << 30,
        maxExpansionRatio: 200,
      );
      expect(inspect([file('big.png', size: 1 << 20)], limits: tight).codes,
          contains('entry_too_large'));
    });

    test('a total that exceeds the cap is refused', () {
      const tight = PackArchiveLimits(
        maxEntries: 100,
        maxEntryBytes: 1 << 20,
        maxTotalBytes: 8192,
        maxExpansionRatio: 200,
      );
      final entries = [
        for (var i = 0; i < 20; i++) file('f_$i.png', size: 4096)
      ];
      expect(
          inspect(entries, limits: tight).codes, contains('archive_too_large'));
    });

    test('a compression bomb is refused even under the total cap', () {
      // The case the total-size cap alone misses: one entry that expands hugely
      // but stays just under the byte limit.
      const tight = PackArchiveLimits(
        maxEntries: 16,
        maxEntryBytes: 1 << 20,
        maxTotalBytes: 1 << 30,
        maxExpansionRatio: 50,
      );
      final bomb = file('bomb.png', size: 900 * 1024, compressed: 1024);
      expect(inspect([bomb], limits: tight).codes,
          contains('expansion_ratio_bomb'));
    });

    test('a negative size is refused', () {
      const entry = PackArchiveEntry(
        name: 'a.png',
        uncompressedSize: -1,
        compressedSize: 10,
      );
      expect(inspect([entry]).codes, contains('invalid_entry_size'));
    });
  });

  group('entries a pack has no use for', () {
    test('a non-regular entry is refused', () {
      const link = PackArchiveEntry(
        name: 'idle_000.png',
        uncompressedSize: 10,
        compressedSize: 10,
        isRegularFile: false,
      );
      expect(inspect([link]).codes, contains('non_regular_entry'));
    });

    test('a duplicate entry is refused', () {
      // Well-formed, and the second write silently wins.
      expect(inspect([file('idle_000.png'), file('idle_000.png')]).codes,
          contains('duplicate_entry'));
    });

    test('an empty name is refused', () {
      expect(inspect([file('   ')]).codes, contains('empty_entry_name'));
    });

    test('an empty archive is refused', () {
      expect(inspect(const []).codes, contains('empty_archive'));
    });
  });

  test('the policy reports every reason, not just the first', () {
    final result = inspect([
      file('../escape.png'),
      file('/absolute.png'),
      file('dup.png'),
      file('dup.png'),
    ]);
    expect(result.codes, contains('unsafe_entry_path'));
    expect(result.codes, contains('duplicate_entry'));
    expect(result.violations.length, greaterThan(1));
  });

  test('the policy is pure: it decides without touching anything', () {
    // The point of the split. Nothing here needs an archive library or a disk,
    // so the dangerous judgement is testable on its own and the extractor has no
    // policy of its own to get wrong.
    final entries = [file('idle_000.png')];
    final first = inspect(entries);
    final second = inspect(entries);
    expect(first.codes, second.codes);
    expect(entries.single.name, 'idle_000.png',
        reason: 'the policy must not rewrite the entries it is given');
  });
}

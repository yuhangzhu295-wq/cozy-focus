import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/presentation/companion/pack/companion_pack_import.dart';
import 'package:cozy_focus_app/presentation/companion/pack/companion_pack_install_plan.dart';
import 'package:cozy_focus_app/presentation/companion/pack/generation/companion_generation_contract.dart';
import 'package:cozy_focus_app/presentation/companion/pack/generation/companion_generation_policy.dart';
import 'package:cozy_focus_app/presentation/companion/pack/generation/companion_generation_prompt.dart';
import 'package:cozy_focus_app/presentation/companion/pack/generation/unconfigured_generation_provider.dart';

/// P37 — the generation contract, and the honest answer of a build without one.
///
/// ## What can be established without credentials
///
/// Everything except a real generation. The shape of the request, the shape of
/// the result, the prompt that states the pack contract, the retry and cost
/// rules, and — the one that matters most — that a pack produced through this
/// path is a pack the importer accepts. A harness that builds a real `.cozy_pet`
/// proves the contract is complete; if the contract were missing a field, the
/// harness could not produce an installable pack and this file would fail.
///
/// ## What cannot, and is therefore not claimed
///
/// `REAL_PROVIDER_GENERATION = BLOCKED_EXTERNAL`. No provider is configured, no
/// credentials exist, and **nothing here fabricates a generation**. The harness
/// is a test double that says so in its own name, and the production provider
/// returns [CompanionGenerationStatus.blockedExternal] with no bytes — so there
/// is nothing a caller could install by ignoring the status.
void main() {
  CompanionGenerationRequest request({
    String packId = 'mimi',
    String displayName = '咪咪',
    String species = 'cat',
    String description = 'a sleepy grey cat who likes rain',
    Set<String>? actions,
  }) =>
      CompanionGenerationRequest(
        packId: packId,
        displayName: displayName,
        species: species,
        description: description,
        actions: actions ?? const {'idle', 'walk'},
      );

  // ───────────────────────── the request pre-flight ─────────────────────────

  group('a request is checked before it is sent', () {
    test('a well formed request has no problems', () {
      expect(request().problems(), isEmpty);
    });

    test('an id that is not usable as a directory name is refused', () {
      expect(request(packId: '../escape').problems(),
          contains(contains('directory name')));
    });

    test('a name, a species and a description are required', () {
      expect(request(displayName: '  ').problems(),
          contains(contains('needs a name')));
      expect(request(species: 'dragon').problems(),
          contains(contains('not one of')));
      expect(request(description: '  ').problems(),
          contains(contains('what the generation is for')));
    });

    test('idle must be requested, and something must be', () {
      expect(request(actions: const {}).problems(),
          contains(contains('no actions')));
      expect(request(actions: const {'walk'}).problems(),
          contains(contains('idle')));
    });

    test('a partial action set is a normal request, not a degraded one', () {
      // P33's premise: four actions is a legitimate companion.
      expect(request(actions: const {'idle', 'walk', 'sleep'}).problems(),
          isEmpty);
    });
  });

  // ──────────────────────── the build has no provider ────────────────────────

  group('this build reports the capability as missing', () {
    test('the provider is not configured and says why', () {
      const provider = UnconfiguredGenerationProvider();
      expect(provider.isConfigured, isFalse);
      expect(provider.unavailableReason, isNotEmpty);
      expect(provider.providerId, 'unconfigured');
    });

    test('the runner reports blockedExternal without calling the provider',
        () async {
      const provider = UnconfiguredGenerationProvider();
      final result = await const CompanionGenerationRunner(provider: provider)
          .run(request());

      expect(result.status, CompanionGenerationStatus.blockedExternal);
      expect(result.ok, isFalse);
      expect(result.packBytes, isNull,
          reason: 'a caller must not be able to install anything by ignoring '
              'the status');
      expect(result.detail, contains('not configured'));
      expect(result.attempts, 0,
          reason: 'nothing was attempted, because there is nothing to attempt');
    });

    test('the availability provider answers false', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(companionGenerationAvailableProvider), isFalse);
    });

    test('a request that is refused never reaches the provider', () async {
      final probe = _CountingProvider();
      final result = await CompanionGenerationRunner(provider: probe)
          .run(request(packId: '../escape'));

      expect(result.status, CompanionGenerationStatus.refused);
      expect(probe.calls, 0, reason: 'a refusal must not cost anything');
      expect(result.packBytes, isNull);
    });
  });

  // ────────────────────────── retry and cost policy ──────────────────────────

  group('the policy decides when to stop', () {
    test('a transient failure is retried up to the ceiling', () async {
      final probe = _CountingProvider(failures: 10);
      final waited = <Duration>[];

      final result = await CompanionGenerationRunner(
        provider: probe,
        policy: const CompanionGenerationPolicy(
            maxAttempts: 3, baseBackoff: Duration(milliseconds: 4)),
        delay: (d) async => waited.add(d),
      ).run(request());

      expect(probe.calls, 3);
      expect(result.status, CompanionGenerationStatus.failed);
      expect(result.attempts, 3);
      // Doubling, so a rate limit is not hammered.
      expect(waited,
          [const Duration(milliseconds: 4), const Duration(milliseconds: 8)]);
    });

    test('a success on the second attempt reports two attempts', () async {
      final probe = _CountingProvider(failures: 1);
      final result = await CompanionGenerationRunner(
        provider: probe,
        policy: const CompanionGenerationPolicy(maxAttempts: 3),
        delay: (_) async {},
      ).run(request());

      expect(probe.calls, 2);
      expect(result.ok, isTrue);
      expect(result.attempts, 2);
    });

    test('a refusal is not retried', () async {
      final probe = _CountingProvider(refuse: true);
      final result = await CompanionGenerationRunner(
        provider: probe,
        policy: const CompanionGenerationPolicy(maxAttempts: 5),
        delay: (_) async {},
      ).run(request());

      expect(probe.calls, 1,
          reason: 'asking again does not change a refusal, and it would cost '
              'money to be refused twice');
      expect(result.status, CompanionGenerationStatus.refused);
    });

    test('the cost ceiling stops a retry loop', () async {
      final probe = _CountingProvider(failures: 10, costPerCall: 0.4);
      final result = await CompanionGenerationRunner(
        provider: probe,
        policy: const CompanionGenerationPolicy(
            maxAttempts: 10, maxCostUsd: 0.8, baseBackoff: Duration.zero),
        delay: (_) async {},
      ).run(request());

      expect(probe.calls, 2,
          reason: 'the third attempt would cross the ceiling');
      expect(result.status, CompanionGenerationStatus.failed);
      expect(result.detail, contains('cost ceiling'));
      expect(result.costUsd, closeTo(0.8, 1e-9));
    });

    test('the single-attempt policy never waits', () async {
      final probe = _CountingProvider(failures: 10);
      final result = await CompanionGenerationRunner(
        provider: probe,
        policy: CompanionGenerationPolicy.singleAttempt,
        delay: (_) async => fail('a single-attempt policy must not wait'),
      ).run(request());

      expect(probe.calls, 1);
      expect(result.status, CompanionGenerationStatus.failed);
    });
  });

  // ───────────────────────────── the prompt ─────────────────────────────────

  group('the prompt states the contract, not just the wish', () {
    final prompt = CompanionGenerationPrompt.forRequest(
      request(actions: const {'idle', 'walk'}),
    );

    test('the player is quoted, and not paraphrased', () {
      expect(prompt.description, 'a sleepy grey cat who likes rain');
      expect(prompt.text, contains('a sleepy grey cat who likes rain'));
    });

    test('the canvas and the anchors are stated', () {
      // Without these a provider would invent them, and a pack that does not sit
      // on the template cannot be installed.
      expect(prompt.contract, contains('512x512'));
      expect(prompt.contract, contains('y=458'));
      expect(prompt.contract, contains('x=255'));
    });

    test('the requested actions are stated, and only those', () {
      expect(prompt.contract, contains('idle'));
      expect(prompt.contract, contains('walk'));
      expect(
          prompt.contract,
          contains('Do not produce frames for actions that '
              'were not requested'));
    });

    test('the frame naming and the duplicate rule are stated', () {
      expect(prompt.contract, contains('<action>_<index>.png'));
      expect(prompt.contract, contains('starting at 000'));
      expect(prompt.contract, contains('Duplicated frames are rejected'));
      expect(prompt.contract, contains('two distinct frames'));
    });

    test('the frame counts come from the app contract, not from this file', () {
      // The dog's contract says idle carries six frames. The prompt must say so,
      // because a prompt that promised a different count would produce a pack
      // whose animation does not match the app's expectation.
      expect(prompt.contract, contains('idle (6 frames)'));
      expect(prompt.contract, contains('walk (6 frames)'));
    });

    test('the vocabulary is the app\'s, and includes the production set', () {
      final vocabulary = generationActionVocabulary;
      expect(vocabulary, contains('idle'));
      expect(vocabulary, contains('focus_read'));
      expect(vocabulary.length, greaterThanOrEqualTo(13));
    });
  });

  // ──────────────────── a generated pack is an installable pack ──────────────

  group('the output contract is a real pack', () {
    test('the harness produces a pack the importer accepts', () {
      // The point of this test is not the harness. It is that the *contract* is
      // complete: if the request, the result or the pack shape were missing a
      // field, this could not produce something the real importer accepts.
      final bytes = _DeterministicHarnessPack.build(
        packId: 'mimi',
        displayName: '咪咪',
        species: 'cat',
        actions: const ['idle', 'walk'],
      );

      final preview = CompanionPackImporter.inspect(bytes);

      expect(preview.ok, isTrue,
          reason: 'a generated pack must be a pack: ${preview.validation}');
      expect(preview.packId, 'mimi');
      expect(preview.declaredName, '咪咪');
      expect(preview.declaredSpecies, 'cat');
      expect(preview.actionIds..sort(), ['idle', 'walk']);
      expect(preview.canvasWidth, 512);
      expect(preview.canvasHeight, 512);
      expect(preview.completeness!.summary, '2 / 13');
    });

    test('a generated pack goes through the same install rules', () {
      // Nothing about the install path knows where the bytes came from, which is
      // the P31 rule: origin is recorded and consulted by nothing.
      final bytes = _DeterministicHarnessPack.build(
        packId: 'mimi',
        displayName: '咪咪',
        species: 'cat',
        actions: const ['idle', 'walk'],
      );

      final read = CompanionPackImporter.inspect(bytes);
      final plan = CompanionPackInstallRulesPlanProbe.planFor(read);

      expect(plan.ok, isTrue, reason: '${plan.validation}');
      expect(plan.plan!.packId, 'mimi');
    });

    test('a generated pack that claims a built-in id is refused', () {
      final bytes = _DeterministicHarnessPack.build(
        packId: 'dog',
        displayName: 'Mochi',
        species: 'dog',
        actions: const ['idle', 'walk'],
      );

      final read = CompanionPackImporter.inspect(bytes);
      final plan = CompanionPackInstallRulesPlanProbe.planFor(read);

      expect(plan.ok, isFalse);
      expect(plan.validation.codes, contains('pack_id_reserved'));
    });
  });
}

/// A provider that counts its calls, for the policy tests.
class _CountingProvider implements CompanionGenerationProvider {
  _CountingProvider({
    this.failures = 0,
    this.refuse = false,
    this.costPerCall = 0.0,
  });

  /// How many calls should fail before one succeeds.
  final int failures;
  final bool refuse;
  final double costPerCall;

  int calls = 0;

  @override
  String get providerId => 'counting';

  @override
  bool get isConfigured => true;

  @override
  String get unavailableReason => '';

  @override
  Future<CompanionGenerationResult> generate(
    CompanionGenerationRequest request,
  ) async {
    calls++;
    if (refuse) {
      return const CompanionGenerationResult.refused('the harness refuses');
    }
    if (calls <= failures) {
      return CompanionGenerationResult(
        status: CompanionGenerationStatus.failed,
        detail: 'transient failure $calls',
        costUsd: costPerCall,
      );
    }
    return CompanionGenerationResult(
      status: CompanionGenerationStatus.generated,
      packBytes: Uint8List.fromList([1, 2, 3]),
      attempts: 1,
      costUsd: costPerCall,
    );
  }
}

/// A deterministic stand-in that produces a real `.cozy_pet`.
///
/// **Test-only, and named so.** It is not a mock of a generation — it is a
/// demonstration that the output contract is complete, and it cannot be reached
/// from the app: the production provider is
/// [UnconfiguredGenerationProvider], which returns no bytes at all. If this class
/// were ever wired into the app, a user would see a companion appear and believe
/// the feature worked, which is exactly the fake success P37 forbids.
abstract final class _DeterministicHarnessPack {
  const _DeterministicHarnessPack._();

  /// A 1x1 transparent PNG. Real bytes, so the importer's signature check passes
  /// for the reason it would for a real frame.
  static final Uint8List _png = Uint8List.fromList(<int>[
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
    0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
    0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
    0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
    0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
    0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
    0x42, 0x60, 0x82,
  ]);

  static Uint8List build({
    required String packId,
    required String displayName,
    required String species,
    required List<String> actions,
  }) {
    final archive = Archive();
    archive.addFile(ArchiveFile.typedData(
      'manifest.json',
      utf8.encode(jsonEncode({
        'packFormatVersion': 1,
        'companionId': packId,
        'displayName': displayName,
        'species': species,
        'posePack': '${packId}_art',
        'canvas': {'width': 512, 'height': 512},
        'groundBaseline': 458,
        'centerAnchor': 255,
        'actions': {
          for (final action in actions)
            action: {
              'frames': ['${action}_000.png', '${action}_001.png'],
              'fps': 5,
              'loopMode': 'loop',
            },
        },
      })),
    ));
    for (final action in actions) {
      for (final frame in ['${action}_000.png', '${action}_001.png']) {
        archive.addFile(ArchiveFile.typedData(frame, _png));
      }
    }
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }
}

/// Reaches the install rules without an install, for the tests above.
abstract final class CompanionPackInstallRulesPlanProbe {
  const CompanionPackInstallRulesPlanProbe._();

  static CompanionPackInstallDecision planFor(CompanionPackPreview preview) =>
      CompanionPackInstallRules.plan(
        manifest: preview.manifest!,
        displayName: preview.declaredName ?? preview.suggestedName,
        speciesId: preview.declaredSpecies ?? 'cat',
        source: CompanionPackSource.cloudGenerated,
        builtInIds: const {'dog', 'cat', 'rabbit'},
        installedIds: const {},
      );
}

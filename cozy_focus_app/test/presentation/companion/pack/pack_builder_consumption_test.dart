import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/presentation/companion/companion_selection.dart';
import 'package:cozy_focus_app/presentation/companion/focus_phase.dart';
import 'package:cozy_focus_app/presentation/companion/pack/companion_availability_provider.dart';
import 'package:cozy_focus_app/presentation/companion/pack/companion_pack_archive_reader.dart';
import 'package:cozy_focus_app/presentation/companion/pack/companion_pack_exporter.dart';
import 'package:cozy_focus_app/presentation/companion/pack/companion_pack_import.dart';
import 'package:cozy_focus_app/presentation/companion/pack/companion_pack_root.dart';
import 'package:cozy_focus_app/presentation/companion/pack/installed_packs_provider.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_action_manifest.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_behavior_director.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_context.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/companion_id.dart';
import 'package:cozy_focus_app/presentation/companion/runtime/random_source.dart';

/// P34 — the builder's output, judged by the importer.
///
/// ## The rule this file enforces
///
/// The pack builder is not allowed to declare itself successful. A tool that
/// certifies its own output has proven nothing: the question is whether the
/// **app** accepts what it produced, through the same reader, the same validator
/// and the same install rules a user's file goes through.
///
/// So this test runs the real Python builder as a subprocess and then hands the
/// bytes to `CompanionPackImporter` — no shortcuts, no fixtures that skip the
/// builder, and no second implementation of any rule.
///
/// The builder's own checks are a pre-flight courtesy. If the two ever disagree,
/// this test fails, and the importer is right.
void main() {
  late Directory work;

  setUp(() {
    work = Directory.systemTemp.createTempSync('cozy_builder_');
  });

  tearDown(() {
    if (work.existsSync()) work.deleteSync(recursive: true);
  });

  /// Copies a shipped companion's frames into a builder input directory.
  ///
  /// Real approved art, used as source material. This is a tooling proof that the
  /// builder can produce a valid pack — it is not new production art, and the
  /// shipped assets are never written to.
  Directory sourceFrames(List<String> actions) {
    final manifest = jsonDecode(
      File('assets/companions/cat/manifest.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final actionsJson = manifest['actions'] as Map<String, dynamic>;

    final input = Directory('${work.path}/source')..createSync(recursive: true);
    for (final action in actions) {
      final frames = (actionsJson[action] as Map)['frames'] as List;
      final dir = Directory('${input.path}/$action')
        ..createSync(recursive: true);
      for (var i = 0; i < frames.length; i++) {
        File('assets/companions/cat/${frames[i]}')
            .copySync('${dir.path}/${i.toString().padLeft(3, '0')}.png');
      }
    }
    return input;
  }

  /// Runs the builder. Returns the output path, or fails with its stderr.
  File runBuilder(
    Directory input, {
    String packId = 'mimi',
    String name = '咪咪',
    String species = 'cat',
    bool fallbackToIdle = false,
    String outputName = 'mimi.cozy_pet',
  }) {
    final output = File('${work.path}/$outputName');
    final result = Process.runSync(
      Platform.isWindows ? 'python' : 'python3',
      [
        'tools/cozy_pet_builder/build.py',
        '--input',
        input.path,
        '--pack-id',
        packId,
        '--name',
        name,
        '--species',
        species,
        '--output',
        output.path,
        if (fallbackToIdle) '--fallback-to-idle',
      ],
    );
    expect(result.exitCode, 0,
        reason: 'the builder refused a valid source:\n${result.stderr}');
    expect(output.existsSync(), isTrue);
    return output;
  }

  ProviderContainer container(Directory installRoot) {
    final c = ProviderContainer(overrides: [
      companionPackRootProvider.overrideWithValue(installRoot.path),
      companionSelectionStoreProvider
          .overrideWithValue(InMemoryCompanionSelectionStore()),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 60));

  group('the importer accepts what the builder produces', () {
    test('a two-action pack is inspected, installed and selectable', () async {
      final input = sourceFrames(['idle', 'walk']);
      final pack = runBuilder(input, fallbackToIdle: true);

      // ── the same reader and the same validator the app uses ──────────────
      final preview = CompanionPackImporter.inspect(pack.readAsBytesSync());
      expect(preview.ok, isTrue,
          reason: 'the importer refused the builder output: '
              '${preview.validation}');
      expect(preview.packId, 'mimi');
      expect(preview.declaredName, '咪咪');
      expect(preview.declaredSpecies, 'cat');
      expect(preview.actionIds..sort(), ['idle', 'walk']);
      expect(preview.frameCount, 12);

      // Two of the app's thirteen actions, reported truthfully before install.
      expect(preview.completeness!.summary, '2 / 13');
      expect(preview.completeness!.ready, {'idle', 'walk'});
      expect(preview.completeness!.missing, isNot(contains('idle')));

      // ── and the same install rules ───────────────────────────────────────
      final installRoot = Directory('${work.path}/packs');
      final c = container(installRoot);
      final report = await CompanionPackImporter.install(
        preview: preview,
        displayName: '咪咪',
        speciesId: 'cat',
        installRoot: installRoot,
        packs: c.read(installedPacksProvider.notifier),
        builtInIds: const {'dog', 'cat', 'rabbit'},
      );
      expect(report.status, CompanionPackImportStatus.installed,
          reason: '${report.validation}');

      await settle();
      expect(
        c.read(companionCatalogProvider).profiles.keys.map((id) => id.value),
        contains('mimi'),
        reason: 'the built pack must become a companion the app offers',
      );
      expect(
        await c
            .read(companionSelectionProvider.notifier)
            .select(const CompanionId('mimi')),
        isTrue,
      );
    });

    test('a pack with no declared fallbacks still installs', () async {
      final input = sourceFrames(['idle', 'walk']);
      final pack = runBuilder(input, outputName: 'plain.cozy_pet');

      final preview = CompanionPackImporter.inspect(pack.readAsBytesSync());
      expect(preview.ok, isTrue, reason: '${preview.validation}');
      // Nothing declared, so eight actions are simply absent rather than
      // promised as something else.
      expect(preview.completeness!.fallback, isEmpty);
      expect(preview.completeness!.missing, isNotEmpty);
    });

    test('a complete thirteen-action pack reports 13 / 13', () async {
      final manifest = jsonDecode(
        File('assets/companions/cat/manifest.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final input = sourceFrames(
          (manifest['actions'] as Map).keys.cast<String>().toList());
      final pack = runBuilder(input, outputName: 'full.cozy_pet');

      final preview = CompanionPackImporter.inspect(pack.readAsBytesSync());
      expect(preview.ok, isTrue, reason: '${preview.validation}');
      expect(preview.completeness!.summary, '13 / 13');
      expect(preview.completeness!.isComplete, isTrue);
      expect(preview.frameCount, 49);
    });
  });

  group('the runtime treats a built pack as a real companion', () {
    /// Installs a built pack and returns a container holding it.
    Future<ProviderContainer> installed(File pack) async {
      final installRoot = Directory('${work.path}/packs');
      final c = container(installRoot);
      final preview = CompanionPackImporter.inspect(pack.readAsBytesSync());
      expect(preview.ok, isTrue, reason: '${preview.validation}');
      await CompanionPackImporter.install(
        preview: preview,
        displayName: '咪咪',
        speciesId: 'cat',
        installRoot: installRoot,
        packs: c.read(installedPacksProvider.notifier),
        builtInIds: const {'dog', 'cat', 'rabbit'},
      );
      await settle();
      return c;
    }

    /// Every pose the director picks over a long focus session.
    Set<String> scheduled(ProviderContainer c) {
      final availability = c.read(companionAvailabilityProvider)('mimi');
      final director = CompanionBehaviorDirector(
        catalog: c.read(companionCatalogProvider),
        context: const CompanionContext(
          companionId: CompanionId('mimi'),
          baseContext: CompanionBaseContext.focus,
          focusPhase: FocusPhase.working,
          hasActiveSession: true,
        ),
        random: SeededRandomSource(11),
        availabilityOf: c.read(companionAvailabilityProvider),
      );
      final seen = <String>{};
      for (var i = 0; i < 200; i++) {
        director.advanceTo(Duration(milliseconds: i * 1000));
        final macro = director.currentMacroBehavior;
        if (macro == null) continue;
        expect(availability.canSchedule(macro.pose), isTrue,
            reason: 'scheduled ${macro.id}, which this pack cannot serve');
        seen.add(macro.pose.id);
      }
      return seen;
    }

    test('with no declared fallbacks, only idle is schedulable', () async {
      // Nothing is promised for the actions the pack does not ship, so the gate
      // is strict and the director has one thing to pick.
      final pack = runBuilder(sourceFrames(['idle', 'walk']),
          outputName: 'strict.cozy_pet');
      final c = await installed(pack);

      expect(
          c.read(companionAvailabilityProvider)('mimi').schedulable, {'idle'});
      expect(scheduled(c).difference({'idle'}), isEmpty);
    });

    test('a declared fallback is schedulable, and still not ready', () async {
      // With `--fallback-to-idle` the pack promises to draw idle for the actions
      // it does not ship. So those *are* schedulable - and the report must still
      // say the pack ships two actions, not ten. Schedulable is what the director
      // may ask for; ready is what the pack actually has.
      final pack = runBuilder(sourceFrames(['idle', 'walk']),
          fallbackToIdle: true, outputName: 'fallback.cozy_pet');
      final c = await installed(pack);

      final availability = c.read(companionAvailabilityProvider)('mimi');
      expect(availability.schedulable.length, 10);
      expect(availability.schedulable, contains('focus_read'));

      final completeness = c.read(companionCompletenessProvider)('mimi');
      expect(completeness.ready, {'idle', 'walk'});
      expect(completeness.summary, '2 / 13');
      expect(completeness.fallback, contains('focus_read'));

      // And every pose it picks is one the pack can serve.
      expect(scheduled(c).difference(availability.schedulable), isEmpty);
    });
  });

  group('round trip', () {
    test('build -> import -> install -> export -> re-import preserves the pack',
        () async {
      final input = sourceFrames(['idle', 'walk']);
      final pack = runBuilder(input, fallbackToIdle: true);
      final installRoot = Directory('${work.path}/packs');
      final c = container(installRoot);

      final built = CompanionPackImporter.inspect(pack.readAsBytesSync());
      await CompanionPackImporter.install(
        preview: built,
        displayName: '咪咪',
        speciesId: 'cat',
        installRoot: installRoot,
        packs: c.read(installedPacksProvider.notifier),
        builtInIds: const {'dog', 'cat', 'rabbit'},
      );
      await settle();

      // ── the app exports what it installed ────────────────────────────────
      final exported = CompanionPackExporter.export(
        packDirectory: '${installRoot.path}/mimi',
        packId: 'mimi',
      );
      expect(exported.ok, isTrue, reason: '${exported.refusal}');

      // ── and the exported bytes read back as the same pack ────────────────
      final again = CompanionPackImporter.inspect(exported.bytes!);
      expect(again.ok, isTrue, reason: '${again.validation}');
      expect(again.packId, built.packId);
      expect(again.declaredName, built.declaredName);
      expect(again.declaredSpecies, built.declaredSpecies);
      expect(again.actionIds..sort(), built.actionIds..sort());
      expect(again.frameCount, built.frameCount);
      expect(again.canvasWidth, built.canvasWidth);
      expect(again.canvasHeight, built.canvasHeight);
      expect(again.completeness!.summary, built.completeness!.summary);

      // Geometry semantics survive: the exported manifest declares the same
      // anchors the builder was held to, not ones re-derived from the frames.
      final manifest = CompanionActionManifest.fromJson(again.manifest!);
      expect(manifest.groundBaseline, 458);
      expect(manifest.centerAnchor, 255);
    });

    test('the export carries the pack and nothing else', () async {
      final input = sourceFrames(['idle', 'walk']);
      final pack = runBuilder(input, fallbackToIdle: true);

      final read = CompanionPackArchiveReader.read(pack.readAsBytesSync());
      expect(read.ok, isTrue);
      // A manifest and frames. No source videos, no absolute paths, no
      // credentials, no database rows - the builder's output is the pack.
      for (final file in read.files) {
        expect(file.name, isNot(contains(':')));
        expect(file.name, isNot(startsWith('/')));
        expect(file.name, isNot(contains('..')));
        expect(
          file.name == 'manifest.json' || file.name.endsWith('.png'),
          isTrue,
          reason: '${file.name} is not part of a pack',
        );
      }
      expect(read.files.map((f) => f.name), contains('manifest.json'));
    });
  });

  group('the video path', () {
    /// Renders a clip from the cat's frames and returns the builder input dir.
    ///
    /// One pass of the cycle, so the clip itself contains no repeated picture:
    /// a looped clip sampled back down lands on the repeat, and the QA would
    /// (correctly) refuse it. The alpha is composited onto a flat background
    /// because recovering alpha from a clip is the stage under test.
    Directory sourceVideo() {
      final frames = jsonDecode(
        File('assets/companions/cat/manifest.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final names =
          ((frames['actions'] as Map)['idle'] as Map)['frames'] as List;

      final clipDir = Directory('${work.path}/clip')
        ..createSync(recursive: true);
      final list = StringBuffer();
      for (var i = 0; i < names.length; i++) {
        // Copied rather than composited: ffmpeg's `-pix_fmt yuv420p` flattens the
        // alpha onto black anyway, which is the same starting point a real
        // recording gives the pipeline.
        File('assets/companions/cat/${names[i]}')
            .copySync('${clipDir.path}/${i.toString().padLeft(3, '0')}.png');
        list.writeln("file '${i.toString().padLeft(3, '0')}.png'");
      }
      File('${clipDir.path}/list.txt').writeAsStringSync(list.toString());

      final input = Directory('${work.path}/video_source')..createSync();
      final render = Process.runSync(
        'ffmpeg',
        [
          '-y',
          '-loglevel',
          'error',
          '-f',
          'concat',
          '-safe',
          '0',
          '-r',
          '15',
          '-i',
          'list.txt',
          '-pix_fmt',
          'yuv420p',
          '-c:v',
          'libx264',
          '-crf',
          '12',
          '${input.path}/idle.mp4',
        ],
        workingDirectory: clipDir.path,
      );
      expect(render.exitCode, 0, reason: 'ffmpeg: ${render.stderr}');
      return input;
    }

    File runVideoBuilder(Directory input,
        {String outputName = 'video.cozy_pet'}) {
      final output = File('${work.path}/$outputName');
      final result = Process.runSync(
        Platform.isWindows ? 'python' : 'python3',
        [
          'tools/cozy_pet_builder/build.py',
          '--input', input.path,
          '--pack-id', 'mimi',
          '--name', '咪咪',
          '--species', 'cat',
          '--output', output.path,
          // A clip rendered locally from frames that already ship is a round trip
          // of existing art, not new production material, and the classification
          // is what stops it being written over the shipped assets.
          '--source-kind', 'test_video',
        ],
      );
      expect(result.exitCode, 0,
          reason: 'the video path refused a valid clip:\n${result.stderr}');
      return output;
    }

    test('a clip becomes a pack the importer accepts', () async {
      if (Process.runSync('ffmpeg', ['-version']).exitCode != 0) {
        markTestSkipped(
            'ffmpeg is not available, so the video path cannot run');
        return;
      }

      final pack = runVideoBuilder(sourceVideo());

      final preview = CompanionPackImporter.inspect(pack.readAsBytesSync());
      expect(preview.ok, isTrue,
          reason: 'the importer refused the video-built pack: '
              '${preview.validation}');
      expect(preview.packId, 'mimi');
      expect(preview.actionIds, ['idle']);
      expect(preview.frameCount, 6);
      // The whole chain - probe, decode, sample, alpha, normalise - landed on the
      // declared template, not on one derived from its own output.
      expect(preview.canvasWidth, 512);
      expect(preview.completeness!.ready, {'idle'});
    });
  });

  group('the builder refuses what the importer would refuse', () {
    test('a pack id that is not usable as a directory name', () {
      final input = sourceFrames(['idle', 'walk']);
      final output = File('${work.path}/bad.cozy_pet');
      final result = Process.runSync(
        Platform.isWindows ? 'python' : 'python3',
        [
          'tools/cozy_pet_builder/build.py',
          '--input',
          input.path,
          '--pack-id',
          '../escape',
          '--name',
          'x',
          '--species',
          'cat',
          '--output',
          output.path,
        ],
      );
      expect(result.exitCode, isNot(0));
      expect(output.existsSync(), isFalse,
          reason: 'a refused build must not leave a pack behind');
    });

    test('an unsupported species', () {
      final input = sourceFrames(['idle', 'walk']);
      final output = File('${work.path}/bad_species.cozy_pet');
      final result = Process.runSync(
        Platform.isWindows ? 'python' : 'python3',
        [
          'tools/cozy_pet_builder/build.py',
          '--input',
          input.path,
          '--pack-id',
          'mimi',
          '--name',
          'x',
          '--species',
          'dragon',
          '--output',
          output.path,
        ],
      );
      expect(result.exitCode, isNot(0));
      expect(output.existsSync(), isFalse);
    });
  });
}

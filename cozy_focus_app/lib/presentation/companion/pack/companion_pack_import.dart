/// Turns a picked `.cozy_pet` into an installed, selectable companion.
///
/// ## Where this sits
///
/// Every rule the import obeys was decided by an earlier, purer component: the
/// archive policy judges the archive, the validator judges the pack, the install
/// rules judge the name and the species, and the installer does the writing.
/// This file adds no rules of its own. What it adds is the *order*, and the two
/// questions that only make sense once those parts are together:
///
/// 1. **Inspect before installing.** A user who picks a bad file should learn why
///    before anything is written, and should be able to see what they are about
///    to install. So the archive is read and described first, and the description
///    is what the preview screen draws.
/// 2. **Already-installed before planning.** `CompanionPackInstallRules` refuses
///    a re-install of an existing id, which is right — but the two cases behind
///    that refusal are not the same to a user. Importing the pack you already
///    have is a no-op worth saying out loud; importing a *different* pack under
///    an id you already have is a conflict worth naming. The checksum tells them
///    apart, and it is the installer's own checksum so the two cannot disagree.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'companion_pack_archive_reader.dart';
import 'companion_pack_completeness.dart';
import 'companion_pack_install_plan.dart';
import 'companion_pack_installer.dart';
import 'companion_pack_validator.dart';
import 'installed_pack_registry.dart';
import 'installed_packs_provider.dart';
import '../runtime/companion_action_manifest.dart';

/// What an archive turned out to contain, before anything is written.
///
/// Carries the read result so the install does not decode the archive a second
/// time — and so the bytes the user previewed are the bytes that get installed.
class CompanionPackPreview {
  /// The files the archive would write, or a refusal with none.
  final CompanionPackReadResult read;

  /// The decoded manifest, when there is one.
  final Map<String, dynamic>? manifest;

  /// The id the pack claims. Null when the manifest is missing or unusable.
  final String? packId;

  /// The name the pack declares for itself, when it declares one.
  ///
  /// Optional in the format: the shipped manifests carry no name, because the
  /// name lives in the app's profile table. A user's pack has no profile table,
  /// so it may declare one here — and when it does not, the user names it at
  /// import rather than the app inventing something.
  final String? declaredName;

  /// The species the pack declares, when it declares one.
  final String? declaredSpecies;

  final int? canvasWidth;
  final int? canvasHeight;

  /// Every action the pack ships, in manifest order.
  final List<String> actionIds;

  /// How many distinct frame files the pack's actions reference.
  final int frameCount;

  /// The first idle frame, so the preview can draw the companion from the bytes
  /// in hand rather than from a pack that has not been installed yet.
  final Uint8List? idleFrame;

  /// How complete this pack's action set is, against the app's own vocabulary.
  ///
  /// Shown before the install, because "this companion ships four of the
  /// thirteen actions" is something a user should know while they can still
  /// change their mind, not after.
  final CompanionPackCompleteness? completeness;

  final PackValidationResult validation;

  const CompanionPackPreview({
    required this.read,
    required this.validation,
    this.manifest,
    this.packId,
    this.declaredName,
    this.declaredSpecies,
    this.canvasWidth,
    this.canvasHeight,
    this.actionIds = const [],
    this.frameCount = 0,
    this.idleFrame,
    this.completeness,
  });

  /// True when this pack could be installed, subject to a name and a species.
  bool get ok => read.ok && validation.ok && manifest != null;

  /// The name to prefill the import form with, when the pack offers one.
  String get suggestedName => declaredName?.trim().isNotEmpty == true
      ? declaredName!.trim()
      : (packId ?? '');

  @override
  String toString() => ok
      ? 'CompanionPackPreview($packId, ${actionIds.length} actions, '
          '$frameCount frames)'
      : 'CompanionPackPreview(refused): $validation';
}

/// What an import attempt did.
enum CompanionPackImportStatus {
  /// Written, recorded, and now selectable.
  installed,

  /// The same pack is already installed. Not an error, and not a write.
  alreadyInstalled,

  /// A different pack already occupies this id.
  conflict,

  /// Refused. Nothing was written.
  refused,
}

/// The outcome, with the reasons when it is not [CompanionPackImportStatus.installed].
class CompanionPackImportReport {
  final CompanionPackImportStatus status;
  final PackValidationResult validation;

  /// The recorded pack, when the install succeeded.
  final InstalledCompanionPack? pack;

  const CompanionPackImportReport({
    required this.status,
    this.validation = const PackValidationResult([]),
    this.pack,
  });

  bool get ok => status == CompanionPackImportStatus.installed;

  @override
  String toString() => 'CompanionPackImportReport(${status.name})'
      '${pack == null ? '' : ': ${pack!.packId}'}';
}

/// Reads a picked pack and describes it, or explains why it cannot be installed.
abstract final class CompanionPackImporter {
  const CompanionPackImporter._();

  /// The staging directory for an install into [installRoot].
  ///
  /// A sibling of the pack root, not a subdirectory of it: the install finishes
  /// with a rename, and a rename across filesystems fails. Keeping staging beside
  /// the destination makes that rename a same-filesystem move, and keeps a
  /// half-written pack out of the directory the runtime reads.
  static Directory stagingRootFor(Directory installRoot) =>
      Directory('${installRoot.parent.path}/companion_pack_staging');

  /// Reads [bytes] and describes the pack inside.
  ///
  /// Never throws for a bad archive: a refusal is a result, because a user
  /// picking the wrong file is an ordinary event and not an exception.
  static CompanionPackPreview inspect(List<int> bytes) {
    final read = CompanionPackArchiveReader.read(bytes);
    if (!read.ok) {
      return CompanionPackPreview(
        read: read,
        validation: read.validation,
      );
    }

    final manifestFile = read.files
        .where((f) => f.name == CompanionPackInstaller.manifestName)
        .firstOrNull;
    if (manifestFile == null) {
      return CompanionPackPreview(
        read: read,
        validation: const PackValidationResult([
          PackViolation(
              'no_manifest', 'the pack has no manifest.json at its root'),
        ]),
      );
    }

    final Map<String, dynamic> manifest;
    try {
      final decoded = jsonDecode(utf8.decode(manifestFile.bytes));
      if (decoded is! Map<String, dynamic>) throw const FormatException();
      manifest = decoded;
    } catch (error) {
      return CompanionPackPreview(
        read: read,
        validation: PackValidationResult([
          PackViolation(
              'unreadable_manifest', 'manifest.json is not valid JSON: $error'),
        ]),
      );
    }

    // `expectedId` is null here on purpose. At this point the manifest is the
    // only thing that knows what the pack is called; the install step is where
    // the id becomes a commitment and is checked against the plan.
    final nameValidation = CompanionPackValidator.validate(
      manifest: manifest,
      availableFiles: {for (final f in read.files) f.name},
    );

    final canvas = manifest['canvas'];
    final actions = manifest['actions'];

    final actionIds = <String>[];
    final frames = <String>{};
    if (actions is Map) {
      for (final entry in actions.entries) {
        actionIds.add(entry.key as String);
        final spec = entry.value;
        if (spec is Map && spec['frames'] is List) {
          for (final frame in spec['frames'] as List) {
            if (frame is String) frames.add(frame);
          }
        }
      }
    }

    // The canvas the frames are supposed to sit on, read once and used both to
    // describe the pack and to bound what its frames may cost.
    final declaredWidth =
        canvas is Map && canvas['width'] is int ? canvas['width'] as int : null;
    final declaredHeight = canvas is Map && canvas['height'] is int
        ? canvas['height'] as int
        : null;

    // Names first, then contents. The validator deliberately never sees bytes -
    // it judges paths and structure - so the one thing it cannot check is whether
    // a file called `idle_000.png` is a PNG. That gap matters: the pack format
    // says frames are PNGs, the policy enforces only the *extension*, and a
    // corrupt or mislabelled frame would install cleanly and then fail at render
    // time, which is the worst place to find out.
    final validation = PackValidationResult([
      ...nameValidation.violations,
      ..._frameContentViolations(
        read,
        frames,
        canvasWidth: declaredWidth,
        canvasHeight: declaredHeight,
      ),
    ]);

    return CompanionPackPreview(
      read: read,
      validation: validation,
      manifest: manifest,
      packId: manifest['companionId'] is String
          ? manifest['companionId'] as String
          : null,
      declaredName: manifest['displayName'] is String
          ? manifest['displayName'] as String
          : null,
      declaredSpecies:
          manifest['species'] is String ? manifest['species'] as String : null,
      canvasWidth: declaredWidth,
      canvasHeight: declaredHeight,
      actionIds: actionIds,
      frameCount: frames.length,
      idleFrame: _firstIdleFrame(read, actions),
      completeness: CompanionPackCompleteness.of(
        CompanionActionManifest.fromJson(manifest),
      ),
    );
  }

  /// Installs an inspected pack.
  ///
  /// [displayName] and [speciesId] come from the user, because the format treats
  /// both as optional: a pack may declare them, and when it does not, the person
  /// importing it is the only authority on what they just added.
  static Future<CompanionPackImportReport> install({
    required CompanionPackPreview preview,
    required String displayName,
    required String speciesId,
    required Directory installRoot,
    required InstalledPacksController packs,
    required Set<String> builtInIds,
  }) async {
    final read = preview.read;
    final manifest = preview.manifest;
    if (!read.ok || !preview.validation.ok || manifest == null) {
      return CompanionPackImportReport(
        status: CompanionPackImportStatus.refused,
        validation: preview.validation,
      );
    }

    final packId = preview.packId;
    if (packId == null) {
      return const CompanionPackImportReport(
        status: CompanionPackImportStatus.refused,
        validation: PackValidationResult([
          PackViolation('missing_companion_id', 'the pack declares no id'),
        ]),
      );
    }

    // ── already installed, decided before the plan ──────────────────────────
    // The install rules refuse *any* re-install of a known id. That is the right
    // rule, but the two cases behind it read very differently to a user, so they
    // are separated here and the rule below is left to do its own job.
    final existing = packs.registry[packId];
    if (existing != null) {
      final incoming = CompanionPackInstaller.checksumOf(read.files);
      return CompanionPackImportReport(
        status: existing.checksum == incoming
            ? CompanionPackImportStatus.alreadyInstalled
            : CompanionPackImportStatus.conflict,
        pack: existing,
      );
    }

    final decision = CompanionPackInstallRules.plan(
      manifest: manifest,
      displayName: displayName,
      speciesId: speciesId,
      source: CompanionPackSource.localImport,
      builtInIds: builtInIds,
      installedIds: packs.installedIds,
    );
    if (!decision.ok) {
      return CompanionPackImportReport(
        status: CompanionPackImportStatus.refused,
        validation: decision.validation,
      );
    }

    final report = await CompanionPackInstaller.install(
      read: read,
      plan: decision.plan!,
      stagingRoot: stagingRootFor(installRoot),
      installRoot: installRoot,
      installedIds: packs.installedIds,
      installedChecksums: {
        for (final pack in packs.registry.packs) pack.packId: pack.checksum,
      },
    );

    if (!report.ok || report.pack == null) {
      return CompanionPackImportReport(
        status: switch (report.status) {
          CompanionPackInstallStatus.alreadyInstalled =>
            CompanionPackImportStatus.alreadyInstalled,
          CompanionPackInstallStatus.conflict =>
            CompanionPackImportStatus.conflict,
          _ => CompanionPackImportStatus.refused,
        },
        validation: report.validation,
      );
    }

    // The write succeeded; now the app has to be told. This is the single
    // revision bump every consumer watches, so the catalog, the visual registry
    // and the selection list all learn about the pack from one signal.
    final outcome = packs.install(report.pack!);
    if (outcome != PackInstallOutcome.installed) {
      // The registry disagrees with a check that was made moments ago. Rather
      // than leave files the app does not know about, the directory goes and the
      // import is reported as the conflict it turned out to be.
      await CompanionPackInstaller.uninstall(
        packId: packId,
        installRoot: installRoot,
      );
      return CompanionPackImportReport(
        status: outcome == PackInstallOutcome.alreadyInstalled
            ? CompanionPackImportStatus.alreadyInstalled
            : CompanionPackImportStatus.conflict,
      );
    }

    return CompanionPackImportReport(
      status: CompanionPackImportStatus.installed,
      pack: report.pack,
    );
  }

  /// The bytes of the idle action's first frame, or null when there is none.
  static Uint8List? _firstIdleFrame(
    CompanionPackReadResult read,
    Object? actions,
  ) {
    if (actions is! Map) return null;
    final idle = actions['idle'];
    if (idle is! Map) return null;
    final frames = idle['frames'];
    if (frames is! List || frames.isEmpty) return null;
    final first = frames.first;
    if (first is! String) return null;
    for (final file in read.files) {
      if (file.name == first) return file.bytes;
    }
    return null;
  }

  /// The eight bytes every PNG starts with.
  ///
  /// The signature only, not a decode. A full decode would mean pulling a codec
  /// into the install path to answer a question the player will answer anyway,
  /// and the failure this is here to catch is a file that is not a PNG at all —
  /// a text file renamed, a truncated download, a placeholder that never got
  /// filled in. Those are caught by the header; a PNG that is well-formed but
  /// subtly broken is a render-time problem and pretending otherwise would be
  /// the kind of check that looks like verification without being it.
  static const List<int> _pngSignature = [
    0x89,
    0x50,
    0x4E,
    0x47,
    0x0D,
    0x0A,
    0x1A,
    0x0A
  ];

  /// Frames whose bytes are not a PNG, or whose pixels do not fit the canvas.
  ///
  /// Only frames the manifest actually references are checked: an unreferenced
  /// file in the archive is dead weight the pack never plays, and the policy
  /// already restricts what may travel with a pack.
  ///
  /// The dimensions matter as much as the signature. The player precaches the
  /// active sequence in full, so what a pack costs in memory is *canvas pixels
  /// times frames*, and a frame count bound alone does not bound that: a pack may
  /// declare a 512x512 canvas and ship 8000x8000 frames, which the manifest check
  /// would never see because it reads the declaration, not the images. Reading
  /// the PNG header is cheap and needs no decode — the width and height are four
  /// bytes each at a fixed offset — and it turns "frames are bounded" into a
  /// statement about memory rather than about a list length.
  static List<PackViolation> _frameContentViolations(
    CompanionPackReadResult read,
    Set<String> referencedFrames, {
    int? canvasWidth,
    int? canvasHeight,
  }) {
    final violations = <PackViolation>[];
    for (final file in read.files) {
      if (!referencedFrames.contains(file.name)) continue;
      if (!file.name.toLowerCase().endsWith('.png')) continue;
      final bytes = file.bytes;
      final looksLikePng = bytes.length >= _pngSignature.length &&
          _pngSignature.asMap().entries.every((e) => bytes[e.key] == e.value);
      if (!looksLikePng) {
        violations.add(PackViolation(
          'frame_not_a_png',
          '"${file.name}" is used as a frame but its bytes are not a PNG',
        ));
        continue;
      }

      final size = _pngSize(bytes);
      if (size == null) {
        violations.add(PackViolation(
          'frame_header_unreadable',
          '"${file.name}" has a PNG signature but no readable header',
        ));
        continue;
      }
      if (canvasWidth != null &&
          canvasHeight != null &&
          (size.width > canvasWidth || size.height > canvasHeight)) {
        violations.add(PackViolation(
          'frame_larger_than_canvas',
          '"${file.name}" is ${size.width}x${size.height}, larger than the '
              'declared ${canvasWidth}x$canvasHeight canvas; the player holds a '
              'whole sequence in memory, so a frame bigger than the canvas it '
              'is drawn on is a memory cost the pack does not declare',
        ));
      }
    }
    return violations;
  }

  /// The pixel size from a PNG's IHDR, or null when the header is not there.
  ///
  /// The layout is fixed: eight signature bytes, then the IHDR chunk's four-byte
  /// length, four-byte type, then width and height as big-endian 32-bit integers.
  /// So the two numbers sit at offsets 16 and 20 and reading them needs no codec.
  static ({int width, int height})? _pngSize(List<int> bytes) {
    if (bytes.length < 24) return null;
    // "IHDR" must be where the format says it is, or these are not dimensions.
    if (bytes[12] != 0x49 ||
        bytes[13] != 0x48 ||
        bytes[14] != 0x44 ||
        bytes[15] != 0x52) {
      return null;
    }
    int read32(int at) =>
        (bytes[at] << 24) |
        (bytes[at + 1] << 16) |
        (bytes[at + 2] << 8) |
        bytes[at + 3];
    final width = read32(16);
    final height = read32(20);
    if (width <= 0 || height <= 0) return null;
    return (width: width, height: height);
  }
}

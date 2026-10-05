import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/presentation/companion/pack/companion_pack_archive_reader.dart';
import 'package:cozy_focus_app/presentation/companion/pack/companion_pack_exporter.dart';

/// P32F — taking your companion with you.
///
/// Two properties matter. An export carries the pack and nothing else, so it is
/// not a backup of the app by accident. And what comes out goes back in, which is
/// what makes export a real feature rather than a file.
void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('cozy_pack_export_');
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  final png = <int>[0x89, 0x50, 0x4E, 0x47, 1, 2, 3];

  /// An installed pack on disk, as the installer would have left it.
  void writePack({bool withStrayFile = false, bool withManifest = true}) {
    if (withManifest) {
      File('${root.path}/manifest.json').writeAsStringSync(jsonEncode({
        'companionId': 'mimi',
        'posePack': 'mimi_art',
        'canvas': {'width': 512, 'height': 512},
        'groundBaseline': 458,
        'centerAnchor': 255,
        'actions': {
          'idle': {
            'frames': ['idle_000.png', 'idle_001.png'],
            'fps': 5,
            'loopMode': 'loop',
          },
        },
      }));
    }
    Directory('${root.path}/frames').createSync();
    File('${root.path}/frames/idle_000.png').writeAsBytesSync(png);
    File('${root.path}/frames/idle_001.png').writeAsBytesSync(png);
    if (withStrayFile) {
      File('${root.path}/debug.log').writeAsStringSync('not part of the pack');
      File('${root.path}/notes.txt').writeAsStringSync('nor this');
    }
  }

  CompanionPackExportResult export() =>
      CompanionPackExporter.export(packDirectory: root.path, packId: 'mimi');

  test('a pack exports with its manifest and its frames', () {
    writePack();
    final result = export();

    expect(result.ok, isTrue, reason: '${result.refusal}');
    final read = CompanionPackArchiveReader.read(result.bytes!);
    expect(read.ok, isTrue, reason: '$read');
    expect(
      read.files.map((f) => f.name).toSet(),
      {'manifest.json', 'frames/idle_000.png', 'frames/idle_001.png'},
    );
  });

  test('the exported bytes come back through the importer unchanged', () {
    // The round trip, which is what makes export a real feature. Not
    // byte-identical archives - a ZIP carries timestamps - but the same content.
    writePack();
    final first = export();
    final read = CompanionPackArchiveReader.read(first.bytes!);

    final pngFrame =
        read.files.firstWhere((f) => f.name == 'frames/idle_000.png');
    expect(pngFrame.bytes, png,
        reason: 'the frame must survive the round trip byte for byte');

    final manifest = jsonDecode(
      utf8.decode(
          read.files.firstWhere((f) => f.name == 'manifest.json').bytes),
    ) as Map<String, dynamic>;
    expect(manifest['posePack'], 'mimi_art');
    expect(manifest['groundBaseline'], 458);
  });

  group('what an export leaves out', () {
    test('a file that is not part of the pack is not included', () {
      // A stray log or an editor's backup is not the user's companion, and an
      // export is not a backup of the app.
      writePack(withStrayFile: true);
      final read = CompanionPackArchiveReader.read(export().bytes!);

      expect(read.files.map((f) => f.name), isNot(contains('debug.log')));
      expect(read.files.map((f) => f.name), isNot(contains('notes.txt')));
    });

    test('a directory with no manifest is refused', () {
      writePack(withManifest: false);
      final result = export();
      expect(result.ok, isFalse);
      expect(result.refusal, contains('manifest'));
    });

    test('a missing directory is refused rather than thrown', () {
      final result = CompanionPackExporter.export(
        packDirectory: '${root.path}/nobody',
        packId: 'nobody',
      );
      expect(result.ok, isFalse);
    });
  });

  test('the entry order is fixed, so the content is reproducible', () {
    // Two exports of one pack must describe the same pack. Sorting does not make
    // the archives byte-identical - a ZIP carries timestamps - but it makes the
    // content reproducible, which is what a comparison needs.
    writePack();
    final first = CompanionPackArchiveReader.read(export().bytes!);
    final second = CompanionPackArchiveReader.read(export().bytes!);
    expect(first.files.map((f) => f.name).toList(),
        second.files.map((f) => f.name).toList());
  });

  test('the extension is the one the brief names', () {
    expect(CompanionPackExporter.extension, '.cozy_pet');
  });
}

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cozy_focus_app/presentation/companion/companion_selection.dart';
import 'package:cozy_focus_app/presentation/companion/pack/companion_pack_picker.dart';
import 'package:cozy_focus_app/presentation/companion/pack/companion_pack_root.dart';
import 'package:cozy_focus_app/presentation/companion/pack/installed_packs_provider.dart';
import 'package:cozy_focus_app/presentation/pages/companion_import_page.dart';
import 'package:cozy_focus_app/presentation/theme/app_theme.dart';

/// P32 — the import screen, driven through its own widgets.
///
/// ## What is faked, and what is not
///
/// Only the two platform edges: the file picker, which cannot open a system
/// dialog in a test, and the share sheet. Everything between the picked bytes and
/// the installed pack is the real code, writing to a real temporary directory.
///
/// That boundary is the point. A test that faked the installer would prove the
/// screen can call a method; this one proves the screen, given a file, leaves a
/// companion on disk and says so.
void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('cozy_import_ui_');
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  final png = Uint8List.fromList(<int>[
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

  /// A valid pack, as the exporter would have written it.
  Uint8List goodPack({String id = 'mimi', String? name}) {
    final archive = Archive();
    archive.addFile(ArchiveFile.typedData(
      'manifest.json',
      utf8.encode(jsonEncode({
        'companionId': id,
        if (name != null) 'displayName': name,
        'posePack': '${id}_art',
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
      })),
    ));
    archive.addFile(ArchiveFile.typedData('idle_000.png', png));
    archive.addFile(ArchiveFile.typedData('idle_001.png', png));
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  Widget app(ProviderContainer c) => UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const CompanionImportPage(),
        ),
      );

  ProviderContainer containerWith(CompanionPackPicker picker) {
    final c = ProviderContainer(overrides: [
      companionPackRootProvider.overrideWithValue(root.path),
      companionPackPickerProvider.overrideWithValue(picker),
      companionSelectionStoreProvider
          .overrideWithValue(InMemoryCompanionSelectionStore()),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  testWidgets('a picked pack is described before anything is written',
      (tester) async {
    final c = containerWith(_FakePicker(
      PickedCompanionPack('mimi.cozy_pet', goodPack(name: '小豆')),
    ));
    await tester.pumpWidget(app(c));

    expect(find.text('选择宠物包文件'), findsOneWidget);

    await tester.tap(find.text('选择宠物包文件'));
    await tester.pump();
    await tester.pump();

    // The preview: what the user is about to install, and the two things only
    // they can answer.
    expect(find.text('mimi'), findsOneWidget);
    expect(find.text('动作 1'), findsOneWidget);
    expect(find.text('帧 2'), findsOneWidget);
    expect(find.text('画布 512×512'), findsOneWidget);
    expect(find.text('安装这个伙伴'), findsOneWidget);

    // Nothing was written: a preview is not an install.
    expect(root.listSync(), isEmpty);
  });

  testWidgets('the name the pack declares is prefilled, and install writes it',
      (tester) async {
    final c = containerWith(_FakePicker(
      PickedCompanionPack('mimi.cozy_pet', goodPack(name: '小豆')),
    ));
    await tester.pumpWidget(app(c));
    await tester.tap(find.text('选择宠物包文件'));
    await tester.pump();
    await tester.pump();

    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '小豆',
    );

    // Install is gated on the species, which the format leaves optional and the
    // user therefore has to supply.
    await tester.tap(find.text('狗狗'));
    await tester.pump();

    // The tap is made *inside* `runAsync` on purpose. The install writes real
    // files, and a future chain created under the fake test clock has its
    // continuations parked there; only a chain created in the real zone finishes
    // while the test waits.
    await tester.runAsync(() async {
      await tester.tap(find.text('安装这个伙伴'));
      await Future<void>.delayed(const Duration(milliseconds: 400));
    });
    await tester.pump();
    await tester.pump();

    final onScreen = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .whereType<String>()
        .toList();

    expect(onScreen, contains('小豆 已经住进来啦 🌱'), reason: 'on screen: $onScreen');
    expect(find.text('现在就换成它'), findsOneWidget);

    // And the pack is really on disk, with the name the user confirmed.
    expect(File('${root.path}/mimi/manifest.json').existsSync(), isTrue);
    expect(File('${root.path}/mimi/idle_000.png').existsSync(), isTrue);
    expect(c.read(installedPacksProvider.notifier).installedIds, {'mimi'});
  });

  testWidgets('a bad file is refused in words, and nothing is written',
      (tester) async {
    final c = containerWith(_FakePicker(
      PickedCompanionPack(
        'not-a-pack.cozy_pet',
        Uint8List.fromList(utf8.encode('this is not a zip')),
      ),
    ));
    await tester.pumpWidget(app(c));
    await tester.tap(find.text('选择宠物包文件'));
    await tester.pump();
    await tester.pump();

    expect(find.text('这个文件装不了'), findsOneWidget);
    // The code is `empty_archive`; the user reads a sentence, not a code.
    expect(find.text('这个包是空的，里面什么都没有。'), findsOneWidget);
    expect(root.listSync(), isEmpty);
  });

  testWidgets('a frame that is not really a PNG is refused before install',
      (tester) async {
    final archive = Archive();
    archive.addFile(ArchiveFile.typedData(
      'manifest.json',
      utf8.encode(jsonEncode({
        'companionId': 'mimi',
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
      })),
    ));
    archive.addFile(ArchiveFile.typedData(
        'idle_000.png', Uint8List.fromList(utf8.encode('nope'))));
    archive.addFile(ArchiveFile.typedData('idle_001.png', png));

    final c = containerWith(_FakePicker(PickedCompanionPack(
      'bad.cozy_pet',
      Uint8List.fromList(ZipEncoder().encode(archive)),
    )));
    await tester.pumpWidget(app(c));
    await tester.tap(find.text('选择宠物包文件'));
    await tester.pump();
    await tester.pump();

    expect(find.text('这个文件装不了'), findsOneWidget);
    expect(find.text('这个包里有张图其实不是图片文件，装进来会显示不出来。'), findsOneWidget);
    expect(root.listSync(), isEmpty);
  });

  testWidgets('closing the picker is not an error', (tester) async {
    final picker = _FakePicker(null);
    final c = containerWith(picker);
    await tester.pumpWidget(app(c));

    await tester.tap(find.text('选择宠物包文件'));
    await tester.pump();
    await tester.pump();

    expect(picker.calls, 1);
    // Still on the first step, with nothing said about a cancelled dialog.
    expect(find.text('选择宠物包文件'), findsOneWidget);
    expect(find.text('这个文件装不了'), findsNothing);
  });
}

class _FakePicker implements CompanionPackPicker {
  _FakePicker(this.result);

  final PickedCompanionPack? result;
  int calls = 0;

  @override
  Future<PickedCompanionPack?> pick() async {
    calls++;
    return result;
  }
}

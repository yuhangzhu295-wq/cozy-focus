import 'dart:io';

/// An install root whose parent is unique to this test.
///
/// ## Why this exists
///
/// `CompanionPackImporter.stagingRootFor` puts staging **beside** the install root
/// — `installRoot.parent/companion_pack_staging`. On a device that is correct: the
/// parent is the app's own directory and there is one app.
///
/// A test that creates its install root directly in the system temp directory
/// gives it the *shared* temp directory as a parent, so every test file in a
/// parallel run used the same `companion_pack_staging`. Two things followed, and
/// both showed up as failures that passed when the file was run alone:
///
/// * `install leaves no staging directory behind` found another file's leftover
///   `import_<timestamp>` and failed with "Expected: empty".
/// * A teardown failed with `OS Error 32: 另一个程序正在使用此文件` because the other
///   test still held the directory.
///
/// This was recorded twice as an unexplained flake before the mechanism was found.
/// Nesting the install root one level down gives each test its own parent, so the
/// staging directory is private and the teardown deletes both together.
Directory createIsolatedInstallRoot([String prefix = 'cozy_packs_']) {
  final base = Directory.systemTemp.createTempSync(prefix);
  return Directory('${base.path}/companion_packs')..createSync();
}

/// Removes an install root and the directory that holds it, staging included.
void deleteIsolatedInstallRoot(Directory installRoot) {
  final base = installRoot.parent;
  if (base.existsSync()) base.deleteSync(recursive: true);
}

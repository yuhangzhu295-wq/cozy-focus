import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'data/backup/backup_service.dart';
import 'data/local/app_database.dart';
import 'presentation/app_localization.dart';
import 'presentation/companion/pack/companion_pack_install_plan.dart';
import 'presentation/companion/pack/companion_pack_root.dart';
import 'presentation/navigation/app_router.dart';
import 'presentation/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Where installed companion packs live. Resolved once, here, rather than in a
  // provider: the catalog is synchronous and a build must not await a path. Until
  // this runs, `companionPackRootProvider` is null and nothing is installed -
  // which is true, and a better answer than a guess.
  final documents = await getApplicationDocumentsDirectory();
  final packRoot =
      Directory('${documents.path}/${CompanionPackInstallRules.root}');

  // A restore is the one operation that changes the database and the pack
  // directory together, and a process can die between the two. The journal is
  // resolved here, before the app opens its own connection, so no screen can
  // read a half-restored state.
  //
  // The outcome is kept, not discarded: a recovery that could not finish leaves
  // the two halves in a state only the next start can resolve, and the owner
  // is told rather than the app pretending the restore completed.
  final recovery = await _recoverInterruptedRestore(packRoot);

  runApp(
    ProviderScope(
      overrides: [
        companionPackRootProvider.overrideWithValue(
          '${documents.path}/${CompanionPackInstallRules.root}',
        ),
        recoveryIncompleteProvider.overrideWithValue(!recovery.isResolved),
      ],
      child: const CozyFocusApp(),
    ),
  );
}

/// Runs startup recovery, swallowing only what must not stop the app opening.
Future<BackupRecoveryOutcome> _recoverInterruptedRestore(
  Directory packRoot,
) async {
  final recoveryDb = AppDatabase();
  try {
    return await BackupService.recoverInterruptedRestore(
      db: recoveryDb,
      packRoot: packRoot,
    );
  } catch (_) {
    // Recovery is best-effort at startup: a failure here must not stop the app
    // from opening. The journal stays for the next attempt.
    return BackupRecoveryOutcome.rollbackFailed;
  } finally {
    await recoveryDb.close();
  }
}

class CozyFocusApp extends StatelessWidget {
  const CozyFocusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Cozy Focus',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      locale: appLocale,
      supportedLocales: appSupportedLocales,
      localizationsDelegates: appLocalizationsDelegates,
      routerConfig: appRouter,
    );
  }
}

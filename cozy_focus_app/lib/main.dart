import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

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

  runApp(
    ProviderScope(
      overrides: [
        companionPackRootProvider.overrideWithValue(
          '${documents.path}/${CompanionPackInstallRules.root}',
        ),
      ],
      child: const CozyFocusApp(),
    ),
  );
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

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'app/app.dart';
import 'core/db/database.dart';
import 'data/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(const [
      'Work Sans',
      'Eczar',
      'Merriweather',
    ], await rootBundle.loadString('assets/fonts/OFL.txt'));
  });
  await initializeDateFormatting('de_DE');
  Intl.defaultLocale = 'de_DE';

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  final db = AppDatabase();
  final onboarded = await (db.select(
    db.settings,
  )..where((s) => s.key.equals(SettingKeys.onboarded))).getSingleOrNull().then((row) => row?.value == 'true');

  runApp(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: ZoezasApp(initialLocation: onboarded ? '/' : '/onboarding'),
    ),
  );
}

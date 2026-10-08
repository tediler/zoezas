import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/theme.dart';
import '../data/providers.dart';
import '../platform/platform_integration.dart';
import 'router.dart';

class ZoezasApp extends ConsumerStatefulWidget {
  const ZoezasApp({super.key, required this.initialLocation});

  final String initialLocation;

  @override
  ConsumerState<ZoezasApp> createState() => _ZoezasAppState();
}

class _ZoezasAppState extends ConsumerState<ZoezasApp> with WidgetsBindingObserver {
  late final GoRouter _router = buildRouter(widget.initialLocation);
  bool _autoBooking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(settingsRepoProvider).markActive(DateTime.now());
      ref.read(platformIntegrationProvider).init();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(clockProvider.notifier).refresh();
      ref.read(settingsRepoProvider).markActive(DateTime.now());
    }
  }

  @override
  Widget build(BuildContext context) {
    // Fällige Termine automatisch gebuchter Daueraufträge eintragen, sobald die
    // Daten (oder das Datum) sich ändern. Der eindeutige Schlüssel in der
    // Datenbank verhindert Doppelbuchungen, auch wenn das hier mehrfach läuft.
    ref.listen(ledgerProvider, (_, ledger) async {
      if (ledger == null || _autoBooking) return;
      final due = ledger.autoBookDue;
      if (due.isEmpty) return;
      _autoBooking = true;
      try {
        await ref.read(bookingsRepoProvider).autoBook(due);
      } finally {
        _autoBooking = false;
      }
    });
    // Homescreen-Widget aktuell halten.
    ref.listen(ledgerProvider, (_, ledger) {
      if (ledger != null) ref.read(platformIntegrationProvider).updateHomeWidget(ledger);
    });

    return MaterialApp.router(
      title: 'Zoëzas',
      debugShowCheckedModeBanner: false,
      theme: buildZoezasTheme(),
      routerConfig: _router,
      // Tipp auf eine freie Fläche schließt die Tastatur (iOS-Ziffernblock hat
      // keine „Fertig“-Taste). Buttons und Felder gewinnen die Geste selbst.
      builder: (context, child) => GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Stack(
          children: [
            ?child,
            // Hinter der Statusleiste: Inhalte scrollen weich darunter weg,
            // statt mit Uhrzeit und Symbolen zu kollidieren.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: MediaQuery.paddingOf(context).top,
              child: const IgnorePointer(child: ColoredBox(color: Color(0xF2F9EAF1))),
            ),
          ],
        ),
      ),
      locale: const Locale('de', 'DE'),
      supportedLocales: const [Locale('de', 'DE')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}

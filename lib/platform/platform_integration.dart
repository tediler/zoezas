import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:quick_actions/quick_actions.dart';

import '../core/format/dates.dart';
import '../core/format/money.dart';
import '../domain/enums.dart';
import '../domain/ledger.dart';
import '../features/bookings/quick_add.dart';
import 'web_support.dart';

final platformIntegrationProvider = Provider<PlatformIntegration>((ref) => PlatformIntegration(ref));

/// Verbindung zu den nativen Homescreen-Funktionen:
///
/// * **Homescreen-Widget** (Android: AppWidget in Kotlin, iOS: WidgetKit in
///   Swift). Flutter schreibt den aktuellen Stand in den gemeinsamen Speicher;
///   das native Widget zeigt ihn an und öffnet per Link `zoezas://add` direkt
///   die Schnelleingabe.
/// * **App-Shortcuts** (langes Drücken auf das App-Icon) für „Ausgabe“ und
///   „Einnahme“ – auf Android und iOS ohne weiteren nativen Code.
/// * **Browser (PWA):** Shortcuts aus `web/manifest.json` öffnen die App mit
///   `?add=expense`; außerdem bittet die App um dauerhaften Speicher, damit der
///   Browser die Daten nicht von sich aus löscht.
class PlatformIntegration {
  PlatformIntegration(this.ref);

  final Ref ref;

  static const androidWidget = 'ZoezasWidgetProvider';
  static const iOSWidget = 'ZoezasWidget';
  static const appGroup = 'group.de.hilsenbeck.zoezas';

  bool _initialized = false;
  String? _lastWidgetState;

  bool get _supported =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    if (kIsWeb) return _initWeb();
    if (!_supported) return;
    try {
      await HomeWidget.setAppGroupId(appGroup);
      _handleUri(await HomeWidget.initiallyLaunchedFromHomeWidget());
      HomeWidget.widgetClicked.listen(_handleUri);
    } catch (e) {
      debugPrint('HomeWidget nicht verfügbar: $e');
    }
    try {
      const actions = QuickActions();
      await actions.initialize(_handleShortcut);
      await actions.setShortcutItems(const [
        ShortcutItem(type: 'add_expense', localizedTitle: 'Ausgabe hinzufügen', icon: 'ic_shortcut_expense'),
        ShortcutItem(type: 'add_income', localizedTitle: 'Einnahme hinzufügen', icon: 'ic_shortcut_income'),
      ]);
    } catch (e) {
      debugPrint('Quick Actions nicht verfügbar: $e');
    }
  }

  Future<void> _initWeb() async {
    final base = Uri.base;
    final add = base.queryParameters['add'] ?? Uri.tryParse(base.fragment)?.queryParameters['add'];
    if (add != null) {
      final t = add == 'income' ? BookingType.income : BookingType.expense;
      ref.read(quickAddRequestProvider.notifier).request(QuickAddRequest(type: t));
      WebSupport.removeQuery();
    }
    await WebSupport.requestPersistentStorage();
  }

  void _handleShortcut(String type) {
    final t = type == 'add_income' ? BookingType.income : BookingType.expense;
    ref.read(quickAddRequestProvider.notifier).request(QuickAddRequest(type: t));
  }

  /// `zoezas://add?type=expense` (iOS hängt `&homeWidget` an).
  void _handleUri(Uri? uri) {
    if (uri == null) return;
    if (uri.host == 'add' || uri.pathSegments.contains('add')) {
      final t = uri.queryParameters['type'] == 'income' ? BookingType.income : BookingType.expense;
      ref.read(quickAddRequestProvider.notifier).request(QuickAddRequest(type: t));
    }
  }

  /// Schreibt den aktuellen Stand für das Homescreen-Widget (nur bei Änderung).
  Future<void> updateHomeWidget(Ledger ledger) async {
    if (!_initialized || !_supported) return;
    final available = ledger.available;
    final forecast = ledger.forecastMonthEnd;
    final month = ledger.month(YearMonth.of(ledger.today));
    final data = <String, String>{
      'available': Money.format(available),
      'available_whole': '${available < 0 ? '−' : ''}${Money.wholePart(available)}',
      'available_cents': Money.centsPart(available),
      'forecast': forecast.items.isEmpty
          ? 'Im ${month.month.monthName}: ${Money.format(month.expenses, compact: true)} ausgegeben'
          : 'Bis ${Dates.short(forecast.until)}: ${Money.format(forecast.end, compact: true)}',
      'negative': available < 0 ? 'true' : 'false',
    };
    final signature = data.values.join('|');
    if (signature == _lastWidgetState) return;
    _lastWidgetState = signature;
    try {
      for (final e in data.entries) {
        await HomeWidget.saveWidgetData<String>(e.key, e.value);
      }
      await HomeWidget.updateWidget(androidName: androidWidget, iOSName: iOSWidget);
    } catch (e) {
      debugPrint('Widget-Update fehlgeschlagen: $e');
    }
  }

  /// Android: Widget direkt aus der App auf den Homescreen legen.
  Future<bool> requestPinWidget() async {
    if (!_supported || defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      if (await HomeWidget.isRequestPinWidgetSupported() == true) {
        await HomeWidget.requestPinWidget(androidName: androidWidget);
        return true;
      }
    } catch (e) {
      debugPrint('Pin-Widget nicht möglich: $e');
    }
    return false;
  }
}

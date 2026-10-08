import 'dart:js_interop';

import 'package:web/web.dart' as web;

// Safari kennt `navigator.standalone` für Apps vom Home-Bildschirm.
@JS('navigator.standalone')
external JSBoolean? get _iosStandalone;

/// Browser-Hilfen für die PWA.
abstract final class WebSupport {
  static bool get isStandalone =>
      web.window.matchMedia('(display-mode: standalone)').matches || (_iosStandalone?.toDart ?? false);

  static bool get isAppleMobile {
    final ua = web.window.navigator.userAgent;
    final iPadOs = ua.contains('Macintosh') && web.window.navigator.maxTouchPoints > 1;
    return ua.contains('iPhone') || ua.contains('iPad') || iPadOs;
  }

  static Future<bool> requestPersistentStorage() async {
    try {
      return (await web.window.navigator.storage.persist().toDart).toDart;
    } catch (_) {
      return false;
    }
  }

  static void removeQuery() {
    final loc = web.window.location;
    if (loc.search.isEmpty) return;
    web.window.history.replaceState(null, '', '${loc.pathname}${loc.hash}');
  }

  static Future<bool> isStoragePersisted() async {
    try {
      return (await web.window.navigator.storage.persisted().toDart).toDart;
    } catch (_) {
      return false;
    }
  }
}

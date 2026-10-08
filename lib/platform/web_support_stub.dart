/// Platzhalter außerhalb des Browsers.
abstract final class WebSupport {
  /// Läuft die App als installierte PWA (vom Home-Bildschirm gestartet)?
  static bool get isStandalone => false;

  /// iPhone oder iPad (auch iPadOS, das sich als Mac ausgibt).
  static bool get isAppleMobile => false;

  /// Bittet den Browser, die Daten nicht automatisch zu löschen.
  static Future<bool> requestPersistentStorage() async => false;

  /// Hat der Browser dauerhaften Speicher zugesagt?
  static Future<bool> isStoragePersisted() async => false;

  /// Entfernt `?add=…` aus der Adresse, damit ein Neuladen nicht erneut die
  /// Schnelleingabe öffnet.
  static void removeQuery() {}
}

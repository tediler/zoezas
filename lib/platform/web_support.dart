// Browser-spezifische Hilfen für die PWA. Auf Android/iOS wird nur der Stub
// geladen, damit dort kein Web-Code mitkompiliert wird.
export 'web_support_stub.dart' if (dart.library.js_interop) 'web_support_web.dart';

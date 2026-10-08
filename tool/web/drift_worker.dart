// Quelle für web/drift_worker.js: der Web Worker, in dem drift die
// SQLite-Datenbank im Browser betreibt (IndexedDB bzw. OPFS als Speicher).
//
//   dart compile js -O4 tool/web/drift_worker.dart -o web/drift_worker.js
//
// Muss neu kompiliert werden, wenn drift aktualisiert wird.
import 'package:drift/wasm.dart';

void main() => WasmDatabase.workerMainForOpen();

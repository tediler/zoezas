import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/enums.dart';

/// Wunsch, die Schnelleingabe zu öffnen – aus dem Homescreen-Widget, einem
/// App-Shortcut oder der Tipp-Karte. Die Shell reagiert darauf.
class QuickAddRequest {
  const QuickAddRequest({this.type = BookingType.expense, this.title, this.amount});

  final BookingType type;
  final String? title;
  final int? amount;
}

final quickAddRequestProvider = NotifierProvider<QuickAddNotifier, QuickAddRequest?>(QuickAddNotifier.new);

class QuickAddNotifier extends Notifier<QuickAddRequest?> {
  @override
  QuickAddRequest? build() => null;

  void request(QuickAddRequest r) => state = r;

  void clear() => state = null;

  // Jede Anfrage soll ein neues Ereignis sein, auch wenn sie gleich aussieht.
  @override
  bool updateShouldNotify(QuickAddRequest? previous, QuickAddRequest? next) => !identical(previous, next);
}

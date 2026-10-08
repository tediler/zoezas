import '../core/format/dates.dart';

abstract final class Streak {
  /// Tage in Folge mit App-Nutzung, endend heute (oder gestern, falls heute
  /// noch nichts passiert ist – dann ist die Serie noch nicht gerissen).
  static int current(Set<int> activeDays, DateTime today) {
    var day = Dates.dateOnly(today);
    if (!activeDays.contains(Dates.dayKey(day))) {
      day = DateTime(day.year, day.month, day.day - 1);
      if (!activeDays.contains(Dates.dayKey(day))) return 0;
    }
    var count = 0;
    while (activeDays.contains(Dates.dayKey(day))) {
      count++;
      day = DateTime(day.year, day.month, day.day - 1);
    }
    return count;
  }
}

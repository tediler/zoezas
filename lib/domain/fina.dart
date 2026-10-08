import '../core/db/database.dart';
import '../core/format/dates.dart';
import '../core/format/money.dart';
import 'budgets.dart';
import 'enums.dart';
import 'ledger.dart';

/// Gesichtsausdruck der kleinen Fina-Figur.
enum FinaMood { happy, proud, calm, concerned, sleepy }

class FinaLine {
  const FinaLine(this.text, this.mood);
  final String text;
  final FinaMood mood;
}

/// Inhalt der Tipp-Karte. [quickTitle]/[quickAmount] füllen beim Antippen die
/// Schnelleingabe vor.
class FinaTip {
  const FinaTip({required this.emoji, required this.text, this.quickTitle, this.quickAmount, this.action});

  final String emoji;
  final String text;
  final String? quickTitle;
  final int? quickAmount;
  final FinaTipAction? action;
}

enum FinaTipAction { quickAdd, showDue, openBudgets, openGoals }

/// Was Fina über die aktuelle Lage weiß.
class FinaContext {
  const FinaContext({
    required this.now,
    required this.name,
    required this.tone,
    required this.focus,
    required this.hasBookings,
    required this.available,
    required this.forecastEnd,
    required this.month,
    required this.budgets,
    required this.streak,
    required this.dueCount,
    required this.goals,
    required this.frequentSmallExpense,
    required this.categoryNames,
  });

  final DateTime now;
  final String name;
  final FinaTone tone;
  final MoneyFocus focus;
  final bool hasBookings;
  final int available;
  final int forecastEnd;
  final MonthSummary month;
  final List<BudgetStatus> budgets;
  final int streak;
  final int dueCount;
  final List<GoalProgress> goals;

  /// Häufigste kleine Ausgabe der letzten Wochen (Titel, typischer Betrag).
  final (String, int)? frequentSmallExpense;
  final Map<int, String> categoryNames;
}

/// Finas Stimme. Alles lokal und regelbasiert: Die Lage bestimmt die Situation,
/// der Tonfall aus dem Onboarding die Formulierung. Varianten werden pro Tag
/// stabil gewählt, damit sich der Text nicht bei jedem Neuaufbau ändert.
abstract final class Fina {
  static String greeting(DateTime now) {
    final h = now.hour;
    if (h < 5) return 'Na, noch wach';
    if (h < 11) return 'Guten Morgen';
    if (h < 14) return 'Schönen Mittag';
    if (h < 18) return 'Schönen Nachmittag';
    if (h < 22) return 'Schönen Abend';
    return 'Gute Nacht';
  }

  static String greetingEmoji(DateTime now) {
    final h = now.hour;
    if (h < 5 || h >= 22) return '🌙';
    if (h < 11) return '☀️';
    return '👋';
  }

  // ---------------------------------------------------------------------------
  // Kommentar unter dem Kontostand
  // ---------------------------------------------------------------------------

  static FinaLine comment(FinaContext c) {
    final t = c.tone;
    final n = c.name;
    final seed = Dates.dayKey(c.now);
    String pick(List<String> options, String situation) => options[(seed + situation.hashCode).abs() % options.length];

    if (!c.hasBookings) {
      return FinaLine(
        pick(switch (t) {
          FinaTone.cheeky => [
            'Frisch eingezogen! Füttere mich mit deiner ersten Ausgabe 🍪',
            'Leere Liste, volle Möglichkeiten. Leg los, $n!',
          ],
          FinaTone.warm => [
            'Schön, dass du da bist, $n! Trag einfach deine erste Ausgabe ein 🌷',
            'Ich bin bereit, wenn du es bist – ganz in deinem Tempo.',
          ],
          FinaTone.calm => [
            'Noch keine Buchungen. Tippe auf +, um zu starten.',
            'Alles eingerichtet. Erste Ausgabe über das Plus.',
          ],
        }, 'empty'),
        FinaMood.happy,
      );
    }

    if (c.available < 0) {
      return FinaLine(
        pick(switch (t) {
          FinaTone.cheeky => [
            'Upsi, wir sind im Minus. Kein Drama – das kriegen wir zusammen hin 💪',
            'Minus ist auch nur ein Zustand. Wir drehen das, $n.',
          ],
          FinaTone.warm => [
            'Gerade ist es etwas knapp. Atme durch – wir schauen gemeinsam drauf 🫶',
            'Kleines Minus, großes Herz. Schritt für Schritt wird das wieder.',
          ],
          FinaTone.calm => [
            'Dein verfügbares Guthaben ist negativ.',
            'Du bist im Minus. Ein Blick auf die Ausgaben hilft.',
          ],
        }, 'negative'),
        FinaMood.concerned,
      );
    }

    if (c.forecastEnd < 0) {
      return FinaLine(
        pick(switch (t) {
          FinaTone.cheeky => [
            'Mit allem Geplanten wird’s Ende des Monats eng. Vielleicht was schieben? 🤏',
            'Spoiler: Das Geplante passt gerade nicht ganz rein 👀',
          ],
          FinaTone.warm => [
            'Wenn alles Geplante abgeht, wird es knapp. Magst du ein, zwei Dinge verschieben? 🌸',
            'Bis Monatsende wird’s eng – aber du hast es in der Hand.',
          ],
          FinaTone.calm => ['Prognose zum Monatsende: unter null.', 'Geplante Ausgaben übersteigen das Verfügbare.'],
        }, 'forecast'),
        FinaMood.concerned,
      );
    }

    final over = c.budgets.where((b) => b.level == BudgetLevel.over).toList();
    if (over.isNotEmpty) {
      final name = over.first.isTotal ? 'Dein Monatsbudget' : over.first.category!.name;
      return FinaLine(
        pick(switch (t) {
          FinaTone.cheeky => [
            '$name hat das Budget gesprengt. Passiert den Besten 😅',
            '$name ist drüber – ich sag nix… okay, doch: ein bisschen 🙈',
          ],
          FinaTone.warm => [
            '$name liegt über dem Plan. Nicht schlimm – wir passen einfach auf 💗',
            '$name ist drüber. Sei lieb zu dir, der nächste Monat kommt bestimmt.',
          ],
          FinaTone.calm => ['$name: Budget überschritten.', '$name liegt über dem Budget.'],
        }, 'over'),
        FinaMood.concerned,
      );
    }

    if (c.now.hour >= 23 || c.now.hour < 5) {
      return FinaLine(
        pick(switch (t) {
          FinaTone.cheeky => [
            'Noch wach? Online-Shops nach Mitternacht sind gefährlich 🌙',
            'Dein Geld schläft schon. Du auch bald? 😴',
          ],
          FinaTone.warm => [
            'Zeit, den Tag loszulassen. Dein Geld ist gut aufgehoben 🌙',
            'Schlaf schön, $n – morgen ist ein neuer Tag.',
          ],
          FinaTone.calm => ['Alles erledigt für heute.', 'Gute Nacht.'],
        }, 'night'),
        FinaMood.sleepy,
      );
    }

    final day = c.now.day;
    final daysInMonth = c.month.month.daysInMonth;
    final income = c.month.income + c.month.plannedIncome;
    final pace = income > 0 ? c.month.expenses / income : null;
    final dayRatio = day / daysInMonth;

    final almostGoal = c.goals.where((g) => !g.completed && !g.reached && g.ratio >= 0.8).toList();
    if (almostGoal.isNotEmpty) {
      final g = almostGoal.first;
      final rest = Money.format(g.remaining, compact: true);
      return FinaLine(
        pick(switch (t) {
          FinaTone.cheeky => [
            'Nur noch $rest bis ${g.goal.name}! Ich hör schon die Sektkorken 🍾',
            '${g.goal.emoji} ${g.goal.name} ist sooo nah. Noch $rest!',
          ],
          FinaTone.warm => [
            'Nur noch $rest bis ${g.goal.name} – du bist so nah dran ✨',
            'Ich freu mich schon mit dir: ${g.goal.name} ist fast geschafft!',
          ],
          FinaTone.calm => ['${g.goal.name}: noch $rest.', '${g.goal.name} zu ${(g.ratio * 100).round()} % erreicht.'],
        }, 'goal'),
        FinaMood.proud,
      );
    }

    if (c.streak >= 3 && c.streak % 7 == 0) {
      return FinaLine(
        pick(switch (t) {
          FinaTone.cheeky => [
            '🔥 ${c.streak} Tage am Stück! Wer bist du und was hast du mit dem alten $n gemacht?',
            '${c.streak} Tage Streak. Ich bin offiziell beeindruckt 😎',
          ],
          FinaTone.warm => [
            '${c.streak} Tage in Folge – ich bin richtig stolz auf dich 💗',
            'Eine ganze Serie! ${c.streak} Tage dranbleiben ist großartig.',
          ],
          FinaTone.calm => ['${c.streak} Tage in Folge.', 'Serie: ${c.streak} Tage.'],
        }, 'streak'),
        FinaMood.proud,
      );
    }

    if (day <= 3) {
      return FinaLine(
        pick(switch (t) {
          FinaTone.cheeky => [
            'Neuer Monat, neues Glück – und frisches Konto ✨',
            'Hallo ${c.month.month.monthName}! Wir starten sauber, oder? 😏',
          ],
          FinaTone.warm => [
            'Ein frischer Monat liegt vor dir. Mach ihn zu deinem 🌱',
            'Willkommen im ${c.month.month.monthName}, $n. Schön, dass du dranbleibst.',
          ],
          FinaTone.calm => [
            'Neuer Monat. Budgets sind zurückgesetzt.',
            'Monatsanfang – guter Moment für einen Überblick.',
          ],
        }, 'start'),
        FinaMood.happy,
      );
    }

    if (pace != null && dayRatio > 0.3 && pace < dayRatio * 0.85) {
      return FinaLine(
        pick(switch (t) {
          FinaTone.cheeky => [
            'Du gibst weniger aus, als der Kalender erlaubt. Sparfuchs-Modus aktiviert 🦊',
            'So entspannt war dein Konto lange nicht. Respekt, $n!',
          ],
          FinaTone.warm => [
            'Du liegst richtig gut in der Zeit – weiter so 💚',
            'Ganz ruhig und gut im Plan. Das fühlt sich schön an, oder?',
          ],
          FinaTone.calm => ['Ausgaben unter dem Monatsdurchschnitt.', 'Du liegst gut im Plan.'],
        }, 'pace_good'),
        FinaMood.proud,
      );
    }

    if (pace != null && pace > dayRatio * 1.25 && dayRatio < 0.9) {
      return FinaLine(
        pick(switch (t) {
          FinaTone.cheeky => [
            'Der Monat ist noch jung, dein Geld schon etwas müde 🥲',
            'Hui, ganz schön Tempo diesen Monat. Kurz bremsen? 🚲',
          ],
          FinaTone.warm => [
            'Du bist diesen Monat etwas schneller unterwegs. Ein paar ruhige Tage tun gut 🌷',
            'Kleiner Hinweis mit Liebe: Die Ausgaben laufen dem Monat etwas voraus.',
          ],
          FinaTone.calm => ['Ausgaben über dem Monatsdurchschnitt.', 'Du gibst schneller aus als üblich.'],
        }, 'pace_fast'),
        FinaMood.calm,
      );
    }

    if (daysInMonth - day < 3) {
      final left = daysInMonth - day;
      return FinaLine(
        pick(switch (t) {
          FinaTone.cheeky => [
            'Endspurt! Noch ${left == 0 ? 'heute' : '$left Tage'} – halt durch, Champion 🏁',
            'Fast geschafft. Der Monat gehört dir 💅',
          ],
          FinaTone.warm => [
            'Der Monat ist fast geschafft – du hast das schön gemacht ✨',
            'Noch ein kleines Stück. Ich bin stolz auf dich, $n.',
          ],
          FinaTone.calm => ['Noch ${left == 0 ? 'heute' : '$left Tage'} bis Monatsende.', 'Monatsende naht.'],
        }, 'end'),
        FinaMood.happy,
      );
    }

    final weekend = c.now.weekday >= DateTime.friday;
    if (weekend) {
      return FinaLine(
        pick(switch (t) {
          FinaTone.cheeky => [
            'Wochenende! Gönn dir – aber erzähl mir davon 😉',
            'Freitagsgefühl. Dein Konto sagt: Ein Eis geht klar 🍦',
          ],
          FinaTone.warm => [
            'Genieß dein Wochenende – du hast es dir verdient 🌸',
            'Zeit für schöne Dinge. Alles im grünen Bereich.',
          ],
          FinaTone.calm => ['Wochenende. Alles im Rahmen.', 'Alles im grünen Bereich.'],
        }, 'weekend'),
        FinaMood.happy,
      );
    }

    return FinaLine(
      pick(switch (t) {
        FinaTone.cheeky => [
          'Alles im grünen Bereich. Ich behalte das für dich im Auge 👀',
          'Dein Konto und ich verstehen uns heute prima 💅',
          'Läuft bei dir, $n. Ehrlich.',
        ],
        FinaTone.warm => [
          'Alles im grünen Bereich – du machst das gut 💚',
          'Ruhige Finanzen, ruhiges Herz. Schön, dass du reinschaust 🌷',
          'Ich bin da, falls du was brauchst, $n.',
        ],
        FinaTone.calm => ['Alles im Rahmen.', 'Keine Auffälligkeiten.', 'Stand aktuell.'],
      }, 'default'),
      FinaMood.happy,
    );
  }

  // ---------------------------------------------------------------------------
  // Tipp-Karte
  // ---------------------------------------------------------------------------

  static FinaTip tip(FinaContext c) {
    final seed = Dates.dayKey(c.now);
    final t = c.tone;

    if (c.dueCount > 0) {
      final s = c.dueCount == 1 ? 'Zahlung wartet' : 'Zahlungen warten';
      return FinaTip(
        emoji: '📌',
        text: switch (t) {
          FinaTone.cheeky => '${c.dueCount} $s auf dein OK – schau kurz drüber?',
          FinaTone.warm => '${c.dueCount} $s auf deine Bestätigung. Ganz in Ruhe.',
          FinaTone.calm => '${c.dueCount} $s auf Bestätigung.',
        },
        action: FinaTipAction.showDue,
      );
    }

    final almost = c.budgets.where((b) => !b.isTotal && b.level == BudgetLevel.almost).toList();
    final candidates = <FinaTip>[];

    if (almost.isNotEmpty) {
      final b = almost.first;
      candidates.add(
        FinaTip(
          emoji: b.category!.emoji,
          text: switch (t) {
            FinaTone.cheeky =>
              'Bei ${b.category!.name} sind noch ${Money.format(b.remaining, compact: true)} drin. Einteilen statt verteilen 😉',
            FinaTone.warm =>
              'Für ${b.category!.name} hast du noch ${Money.format(b.remaining, compact: true)}. Das reicht, wenn du’s sanft angehst 🌷',
            FinaTone.calm => '${b.category!.name}: noch ${Money.format(b.remaining, compact: true)} im Budget.',
          },
          action: FinaTipAction.openBudgets,
        ),
      );
    }

    final small = c.frequentSmallExpense ?? ('Eis', 350);
    final smallText = '${small.$1} ${Money.format(small.$2, compact: true).replaceAll(' €', '')}';
    candidates.add(
      FinaTip(
        emoji: '✨',
        text: switch (t) {
          FinaTone.cheeky => 'gönn dir, merk dir: „$smallText“',
          FinaTone.warm => 'Kleine Freuden zählen auch – tipp einfach „$smallText“',
          FinaTone.calm => 'Schnelleingabe: „$smallText“ genügt.',
        },
        quickTitle: small.$1,
        quickAmount: small.$2,
        action: FinaTipAction.quickAdd,
      ),
    );

    final goal = c.goals.where((g) => !g.completed && g.monthlyNeeded != null).firstOrNull;
    if (goal != null) {
      candidates.add(
        FinaTip(
          emoji: goal.goal.emoji,
          text: switch (t) {
            FinaTone.cheeky =>
              'Für ${goal.goal.name} wären ${Money.format(goal.monthlyNeeded!, compact: true)} im Monat perfekt. Deal? 🤝',
            FinaTone.warm =>
              'Mit ${Money.format(goal.monthlyNeeded!, compact: true)} im Monat erreichst du ${goal.goal.name} pünktlich 💫',
            FinaTone.calm => '${goal.goal.name}: ${Money.format(goal.monthlyNeeded!, compact: true)} pro Monat nötig.',
          },
          action: FinaTipAction.openGoals,
        ),
      );
    }

    if (c.month.income > 0 && (c.focus == MoneyFocus.save || c.focus == MoneyFocus.bigGoal)) {
      final tenth = (c.month.income / 10 / 500).round() * 500;
      if (tenth > 0) {
        candidates.add(
          FinaTip(
            emoji: '🐷',
            text: switch (t) {
              FinaTone.cheeky =>
                'Pay yourself first: ${Money.format(tenth, compact: true)} direkt aufs Sparkonto – bevor’s wegschmilzt 🍦',
              FinaTone.warm =>
                'Wie wär’s, 10 % zur Seite zu legen? Das wären ${Money.format(tenth, compact: true)} – ein Geschenk an dein Zukunfts-Ich 💝',
              FinaTone.calm => '10 % des Einkommens: ${Money.format(tenth, compact: true)}.',
            },
            action: FinaTipAction.openGoals,
          ),
        );
      }
    }

    if (c.now.weekday == DateTime.friday || c.now.weekday == DateTime.saturday) {
      candidates.add(
        FinaTip(
          emoji: '🎬',
          text: switch (t) {
            FinaTone.cheeky => 'Wochenend-Trick: Leg dir ein Spaßbudget fest. 40 € und null Reue 😌',
            FinaTone.warm => 'Ein kleines Wochenendbudget nimmt den Druck raus – und lässt Platz für Spaß 🌼',
            FinaTone.calm => 'Tipp: Wochenendbudget festlegen.',
          },
          action: FinaTipAction.openBudgets,
        ),
      );
    }

    return candidates[seed % candidates.length];
  }

  // ---------------------------------------------------------------------------
  // Budgets, Ziele, Sparen
  // ---------------------------------------------------------------------------

  static String budgetNudge(BudgetStatus s, FinaTone t) {
    final rest = Money.format(s.remaining.abs(), compact: true);
    switch (s.level) {
      case BudgetLevel.over:
        return switch (t) {
          FinaTone.cheeky => '$rest drüber – passiert den Besten 😅',
          FinaTone.warm => '$rest über dem Plan. Nicht schlimm 💗',
          FinaTone.calm => '$rest über Budget',
        };
      case BudgetLevel.almost:
        return switch (t) {
          FinaTone.cheeky => 'Noch $rest – wird langsam kuschelig 👀',
          FinaTone.warm => 'Noch $rest – fast geschafft 🌸',
          FinaTone.calm => 'Noch $rest',
        };
      case BudgetLevel.relaxed:
        if (s.plannedWillExceed) {
          return switch (t) {
            FinaTone.cheeky => 'Noch $rest, aber Geplantes sprengt’s 🤏',
            FinaTone.warm => 'Noch $rest – mit Geplantem wird’s knapp',
            FinaTone.calm => 'Noch $rest (Geplantes übersteigt)',
          };
        }
        return switch (t) {
          FinaTone.cheeky => 'Noch $rest – alles chillig 😎',
          FinaTone.warm => 'Noch $rest – ganz entspannt',
          FinaTone.calm => 'Noch $rest',
        };
    }
  }

  static String goalMessage(GoalProgress g, FinaTone t) {
    if (g.completed) return 'Abgeschlossen – du hast es geschafft 🎉';
    if (g.reached) {
      return switch (t) {
        FinaTone.cheeky => 'ZIEL ERREICHT! Ich tanze gerade 💃',
        FinaTone.warm => 'Geschafft! Du hast dein Ziel erreicht 🎉',
        FinaTone.calm => 'Ziel erreicht.',
      };
    }
    final r = g.ratio;
    final rest = Money.format(g.remaining, compact: true);
    if (r == 0) {
      return switch (t) {
        FinaTone.cheeky => 'Der erste Euro ist der schwerste. Los geht’s! 🚀',
        FinaTone.warm => 'Jeder Weg beginnt mit dem ersten Euro ✨',
        FinaTone.calm => 'Noch nichts zurückgelegt.',
      };
    }
    if (r < 0.25) {
      return switch (t) {
        FinaTone.cheeky => 'Guter Start! Nur noch $rest, easy 😏',
        FinaTone.warm => 'Ein schöner Anfang – bleib dran 🌱',
        FinaTone.calm => 'Noch $rest.',
      };
    }
    if (r < 0.5) {
      return switch (t) {
        FinaTone.cheeky => 'Du bist auf Kurs. ${g.goal.emoji} wartet schon auf dich!',
        FinaTone.warm => 'Du kommst richtig gut voran 💫',
        FinaTone.calm => 'Noch $rest.',
      };
    }
    if (r < 0.8) {
      return switch (t) {
        FinaTone.cheeky => 'Mehr als die Hälfte! Ich seh dich schon mit ${g.goal.emoji}',
        FinaTone.warm => 'Über die Hälfte geschafft – wie schön 💗',
        FinaTone.calm => 'Über 50 %. Noch $rest.',
      };
    }
    return switch (t) {
      FinaTone.cheeky => 'Nur noch $rest! Zum Greifen nah 🤩',
      FinaTone.warm => 'Nur noch $rest – du bist fast da ✨',
      FinaTone.calm => 'Noch $rest.',
    };
  }

  /// [hasHistory] = gab es im Vormonat überhaupt Buchungen? Sonst wäre der
  /// Vergleich mit „0 €“ schief.
  static String savingsMessage({
    required int thisMonth,
    required int lastMonth,
    required FinaTone tone,
    bool hasHistory = true,
  }) {
    if (!hasHistory) {
      return switch (tone) {
        FinaTone.cheeky =>
          thisMonth > 0
              ? 'Erster Monat mit mir und schon im Plus. Läuft! 😎'
              : 'Erster Monat zusammen – wir fangen gerade erst an 💪',
        FinaTone.warm => 'Dein erster Monat mit Zoëzas – ein schöner Anfang 🌱',
        FinaTone.calm => 'Erster erfasster Monat – Vergleiche folgen.',
      };
    }
    if (thisMonth <= 0 && lastMonth <= 0) {
      return switch (tone) {
        FinaTone.cheeky => 'Sparen? Kommt noch. Ich glaub an dich 💪',
        FinaTone.warm => 'Jeder Monat ist eine neue Chance – auch kleine Beträge zählen 🌱',
        FinaTone.calm => 'Noch kein Überschuss.',
      };
    }
    final diff = thisMonth - lastMonth;
    if (diff > 0) {
      final d = Money.format(diff, compact: true);
      return switch (tone) {
        FinaTone.cheeky => 'Schon $d mehr als letzten Monat. Wer ist hier der Sparprofi? 😎',
        FinaTone.warm => 'Du liegst $d über dem Vormonat – wunderbar 💚',
        FinaTone.calm => '$d mehr als im Vormonat.',
      };
    }
    return switch (tone) {
      FinaTone.cheeky => 'Noch hinter dem Vormonat – aber der Monat ist noch nicht vorbei 😉',
      FinaTone.warm => 'Etwas weniger als letzten Monat. Ganz okay – du bleibst dran 🌷',
      FinaTone.calm => '${Money.format(-diff, compact: true)} weniger als im Vormonat.',
    };
  }

  // ---------------------------------------------------------------------------
  // Kleine Beschreibungen in der Ausgabenliste
  // ---------------------------------------------------------------------------

  static const _descriptions = <String, List<String>>{
    'food': ['voller Kühlschrank, ruhiges Herz', 'Vitamine & Vorräte', 'Futter für die Woche'],
    'eating_out': ['jemand anderes hat gekocht', 'kleine Auszeit mit Genuss', 'Cappuccino-Momente'],
    'home': ['das Dach über dem Kopf', 'dein gemütliches Zuhause', 'Wände, Wärme, WLAN'],
    'online_shopping': ['ein Klick, ein Lächeln', 'Post für dich', 'schneller da als gedacht'],
    'personal_care': ['Selfcare ist kein Luxus', 'Glow-up inklusive', 'für dein Wohlgefühl'],
    'mobility': ['damit du ankommst', 'von A nach B', 'unterwegs sein'],
    'leisure': ['Zeit für schöne Dinge', 'Erinnerungen sammeln', 'Spaß gehört dazu'],
    'tech': ['für deine kleinen Helfer', 'Bits & Bytes', 'smart investiert'],
    'clothing': ['neuer Lieblingslook', 'für deinen Kleiderschrank', 'Stil mit Gefühl'],
    'subscriptions': ['Serienabende gesichert', 'läuft ganz von allein', 'kleines Abo, großer Spaß'],
    'health': ['für dich und deinen Körper', 'Gesundheit geht vor', 'gut auf dich aufpassen'],
    'gifts': ['Freude schenken', 'von Herzen', 'jemand freut sich riesig'],
    'travel': ['Fernweh gestillt', 'Koffer, Sonne, Abenteuer', 'die Welt wartet'],
    'insurance': ['sicher ist sicher', 'für alle Fälle', 'Ruhe im Kopf'],
    'misc': ['das Leben halt', 'gehört auch dazu', 'kleine Dinge zählen'],
    'salary': ['deine Arbeit zahlt sich aus', 'Zahltag!', 'verdient ist verdient'],
    'side_income': ['extra verdient', 'fleißig gewesen', 'ein kleines Plus'],
    'gift_received': ['jemand hat an dich gedacht', 'einfach so geschenkt', 'Glück gehabt'],
    'refund': ['Geld kommt zurück', 'fair ist fair', 'wieder da'],
    'interest': ['dein Geld arbeitet mit', 'Zinsen, hallo!', 'ein kleiner Bonus'],
    'other_income': ['schön, wenn’s reinkommt', 'ein Plus fürs Konto', 'gern genommen'],
  };

  static const _generic = ['gehört auch dazu', 'notiert & verstanden', 'kleine Dinge zählen'];

  /// „das Dach über dem Kopf, jeden Monat ❤️“. Eine eigene Notiz hat Vorrang.
  static String describe(Booking b, Category? category, {Frequency? recurring}) {
    final note = b.note?.trim();
    if (note != null && note.isNotEmpty) return note;
    if (b.type == BookingType.transfer) return 'von Konto zu Konto';
    final options = _descriptions[category?.builtInKey] ?? _generic;
    final base = options[b.id % options.length];
    if (recurring != null) return '$base, ${recurring.phrase} ❤️';
    return base;
  }
}

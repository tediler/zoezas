import '../../domain/enums.dart';
import '../theme/colors.dart';

/// Mitgelieferte Kategorie. [key] verbindet sie dauerhaft mit Finas Texten,
/// auch wenn die Person sie umbenennt.
class SeedCategory {
  const SeedCategory(this.key, this.name, this.emoji, this.colorIndex, this.kind);

  final String key;
  final String name;
  final String emoji;
  final int colorIndex;
  final CategoryKind kind;

  int get color => ZColors.pastels[colorIndex % ZColors.pastels.length].toARGB32();
}

const seedCategories = <SeedCategory>[
  SeedCategory('food', 'Essen', '🛒', 3, CategoryKind.expense),
  SeedCategory('eating_out', 'Café & Restaurant', '☕', 4, CategoryKind.expense),
  SeedCategory('home', 'Wohnen', '🏠', 0, CategoryKind.expense),
  SeedCategory('online_shopping', 'Online Shopping', '📦', 5, CategoryKind.expense),
  SeedCategory('personal_care', 'Körperpflege', '🧴', 7, CategoryKind.expense),
  SeedCategory('mobility', 'Mobilität', '🚲', 2, CategoryKind.expense),
  SeedCategory('leisure', 'Freizeit', '🎡', 8, CategoryKind.expense),
  SeedCategory('tech', 'Technik', '💻', 1, CategoryKind.expense),
  SeedCategory('clothing', 'Kleidung', '👗', 0, CategoryKind.expense),
  SeedCategory('subscriptions', 'Abos', '📺', 1, CategoryKind.expense),
  SeedCategory('health', 'Gesundheit', '💊', 6, CategoryKind.expense),
  SeedCategory('gifts', 'Geschenke', '🎁', 8, CategoryKind.expense),
  SeedCategory('travel', 'Reisen', '✈️', 2, CategoryKind.expense),
  SeedCategory('insurance', 'Versicherungen', '🛡️', 9, CategoryKind.expense),
  SeedCategory('misc', 'Sonstiges', '✨', 5, CategoryKind.expense),
  SeedCategory('salary', 'Gehalt', '💼', 3, CategoryKind.income),
  SeedCategory('side_income', 'Nebenjob', '🌱', 9, CategoryKind.income),
  SeedCategory('gift_received', 'Geschenkt bekommen', '🎀', 0, CategoryKind.income),
  SeedCategory('refund', 'Rückzahlung', '↩️', 2, CategoryKind.income),
  SeedCategory('interest', 'Zinsen', '📈', 6, CategoryKind.income),
  SeedCategory('other_income', 'Sonstige Einnahmen', '💰', 5, CategoryKind.income),
];

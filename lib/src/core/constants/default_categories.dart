/// Default categories seeded into every group (kept in sync with the Laravel
/// backend's `config/categories.php`).
class DefaultCategory {
  const DefaultCategory(this.id, this.name, this.icon);

  final String id;
  final String name;
  final String icon;
}

const List<DefaultCategory> kDefaultCategories = [
  DefaultCategory('general', 'General', '📝'),
  DefaultCategory('food-drinks', 'Food & Drinks', '🍔'),
  DefaultCategory('transportation', 'Transportation', '🚗'),
  DefaultCategory('entertainment', 'Entertainment', '🎬'),
  DefaultCategory('shopping', 'Shopping', '🛍️'),
  DefaultCategory('utilities', 'Utilities', '💡'),
  DefaultCategory('housing', 'Housing', '🏠'),
  DefaultCategory('life', 'Life', '🧘'),
  DefaultCategory('other', 'Other', '📦'),
];

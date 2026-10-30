/// Default categories seeded into every group (kept in sync with the Laravel
/// backend's `config/categories.php`).
class DefaultCategory {
  const DefaultCategory(this.name, this.icon);

  final String name;
  final String icon;
}

const List<DefaultCategory> kDefaultCategories = [
  DefaultCategory('General', '📝'),
  DefaultCategory('Food & Drinks', '🍔'),
  DefaultCategory('Transportation', '🚗'),
  DefaultCategory('Entertainment', '🎬'),
  DefaultCategory('Shopping', '🛍️'),
  DefaultCategory('Utilities', '💡'),
  DefaultCategory('Housing', '🏠'),
  DefaultCategory('Life', '🧘'),
  DefaultCategory('Other', '📦'),
];

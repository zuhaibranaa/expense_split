import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/data/api_client.dart';
import '../domain/category_model.dart';

final categoriesRepositoryProvider = Provider((ref) {
  return CategoriesRepository(ref.watch(apiClientProvider));
});

final groupCategoriesProvider = FutureProvider.family<List<Category>, int>((
  ref,
  groupId,
) {
  return ref.watch(categoriesRepositoryProvider).getCategories(groupId);
});

class CategoriesRepository {
  final ApiClient _apiClient;

  CategoriesRepository(this._apiClient);

  Future<List<Category>> getCategories(int groupId) async {
    final dynamic data = await _apiClient.get('/groups/$groupId/categories');
    return (data as List).map((e) => Category.fromJson(e)).toList();
  }

  Future<Category> createCategory(
    int groupId,
    String name, {
    String? icon,
  }) async {
    final dynamic data = await _apiClient.post('/groups/$groupId/categories', {
      'name': name,
      'icon': icon,
    });
    return Category.fromJson(data);
  }

  Future<void> deleteCategory(int groupId, int categoryId) async {
    await _apiClient.delete('/groups/$groupId/categories/$categoryId');
  }
}

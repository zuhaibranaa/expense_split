import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/data/api_client.dart';
import '../domain/cash_inflow_model.dart';

class CashInflowRepository {
  final ApiClient _api;

  CashInflowRepository(this._api);

  Future<List<CashInflow>> getInflows({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final queryParams = <String, String>{};
    if (startDate != null) {
      queryParams['start_date'] = startDate.toIso8601String();
    }
    if (endDate != null) {
      queryParams['end_date'] = endDate.toIso8601String();
    }

    String path = '/cash-inflows';
    if (queryParams.isNotEmpty) {
      path += '?${Uri(queryParameters: queryParams).query}';
    }

    final response = await _api.get(path);
    // Assuming response is paginated {data: [...], meta: ...} or just list
    // ApiClient usually returns dynamic.
    // If paginated, response['data'] is the list.
    // Let's assume standard Laravel resource response.
    final List<dynamic> data = response['data'] ?? response;
    return data.map((e) => CashInflow.fromJson(e)).toList();
  }

  Future<CashInflow> createInflow({
    required double amount,
    required String currencyCode,
    String? category,
    required String description,
    DateTime? date,
  }) async {
    final response = await _api.post('/cash-inflows', {
      'amount': amount,
      'currency_code': currencyCode,
      'category': category,
      'description': description,
      'date': date?.toIso8601String(),
    });

    // Response should be the created inflow object (or wrapped in data)
    final data = response['data'] ?? response;
    return CashInflow.fromJson(data);
  }

  Future<void> deleteInflow(int id) async {
    await _api.delete('/cash-inflows/$id');
  }

  Future<CashInflow> updateInflow({
    required int id,
    required double amount,
    required String currencyCode,
    String? category,
    required String description,
    DateTime? date,
  }) async {
    final response = await _api.put('/cash-inflows/$id', {
      'amount': amount,
      'currency_code': currencyCode,
      'category': category,
      'description': description,
      'date': date?.toIso8601String(),
    });

    final data = response['data'] ?? response;
    return CashInflow.fromJson(data);
  }
}

final cashInflowRepositoryProvider = Provider<CashInflowRepository>((ref) {
  return CashInflowRepository(ref.watch(apiClientProvider));
});

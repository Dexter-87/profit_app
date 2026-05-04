import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'http://localhost:8080';

  static Future<List<Map<String, dynamic>>> fetchSales() async {
    final response = await http.get(Uri.parse('$baseUrl/sales'));

    if (response.statusCode != 200) {
      throw Exception('Ошибка загрузки продаж');
    }

    final data = jsonDecode(response.body);
    return List<Map<String, dynamic>>.from(data);
  }

  static Future<void> deleteSale(int rowIndex) async {
    final response = await http.post(
      Uri.parse('$baseUrl/delete-sale'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'rowIndex': rowIndex,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Ошибка удаления продажи: ${response.body}');
    }
  }

  static Future<void> addSale({
    required String name,
    required int quantity,
    required double cost,
    required double price,
    required double commission,
    required String comment,
    required String channel,
    required String orderNumber,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/add-sale'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'quantity': quantity,
        'cost': cost,
        'price': price,
        'commission': commission,
        'comment': comment,
        'channel': channel,
        'orderNumber': orderNumber,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Ошибка добавления продажи: ${response.body}');
    }
  }

  static Future<Map<String, dynamic>> fetchAnalytics({
    String? dateFrom,
    String? dateTo,
    String? brand,
    String? model,
  }) async {
    final query = <String, String>{};

    if (dateFrom != null && dateFrom.isNotEmpty) {
      query['dateFrom'] = dateFrom;
    }

    if (dateTo != null && dateTo.isNotEmpty) {
      query['dateTo'] = dateTo;
    }

    if (brand != null && brand.isNotEmpty && brand != 'Все') {
      query['brand'] = brand;
    }

    if (model != null && model.isNotEmpty) {
      query['model'] = model;
    }

    final uri = Uri.parse('$baseUrl/analytics').replace(
      queryParameters: query,
    );

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Ошибка загрузки аналитики');
    }

    return Map<String, dynamic>.from(jsonDecode(response.body));
  }

  static Future<void> addExpense({
    required double amount,
    required String owner,
    required String type,
    required String comment,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/expenses'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'amount': amount,
        'owner': owner,
        'type': type,
        'comment': comment,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Ошибка добавления расхода: ${response.body}');
    }
  }

  static Future<List<Map<String, dynamic>>> fetchPlan() async {
    final response = await http.get(Uri.parse('$baseUrl/plan'));

    if (response.statusCode != 200) {
      throw Exception('Ошибка загрузки плана');
    }

    final data = jsonDecode(response.body);
    return List<Map<String, dynamic>>.from(data);
  }

  static Future<List<Map<String, dynamic>>> fetchInvestments() async {
    final response = await http.get(Uri.parse('$baseUrl/investments'));

    if (response.statusCode != 200) {
      throw Exception('Ошибка загрузки вложений');
    }

    final data = jsonDecode(response.body);
    return List<Map<String, dynamic>>.from(data);
  }

  static Future<List<Map<String, dynamic>>> fetchDistribution() async {
    final response = await http.get(Uri.parse('$baseUrl/distribution'));

    if (response.statusCode != 200) {
      throw Exception('Ошибка загрузки распределения');
    }

    final data = jsonDecode(response.body);
    return List<Map<String, dynamic>>.from(data);
  }

  static Future<void> saveDistribution(
      List<Map<String, dynamic>> rows,
      ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/distribution'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'rows': rows}),
    );

    if (response.statusCode != 200) {
      throw Exception('Ошибка сохранения распределения: ${response.body}');
    }
  }
}

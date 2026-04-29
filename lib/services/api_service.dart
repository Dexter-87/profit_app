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

  static Future<Map<String, dynamic>> fetchAnalytics({
    String? dateFrom,
    String? dateTo,
  }) async {
    final query = <String, String>{};

    if (dateFrom != null && dateFrom.isNotEmpty) {
      query['date_from'] = dateFrom;
    }

    if (dateTo != null && dateTo.isNotEmpty) {
      query['date_to'] = dateTo;
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

  static Future<void> saveDistribution(List<Map<String, dynamic>> rows) async {
    final response = await http.post(
      Uri.parse('$baseUrl/distribution'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'rows': rows}),
    );

    if (response.statusCode != 200) {
      throw Exception('Ошибка сохранения распределения');
    }
  }
}

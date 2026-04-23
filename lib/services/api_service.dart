import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'http://localhost:8080';
  // Для Android эмулятора потом можно вернуть:
  // static const String baseUrl = 'http://10.0.2.2:8080';

  static Future<List<Map<String, dynamic>>> fetchSales() async {
    final response = await http.get(Uri.parse('$baseUrl/sales'));

    if (response.statusCode != 200) {
      throw Exception('Ошибка загрузки продаж: ${response.body}');
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

    final uri = Uri.parse('$baseUrl/analytics').replace(queryParameters: query);

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Ошибка загрузки аналитики: ${response.body}');
    }

    final data = jsonDecode(response.body);
    return Map<String, dynamic>.from(data);
  }
}

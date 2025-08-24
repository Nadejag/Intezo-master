// lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'http://192.168.100.69:3000/api';

  static Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final headers = {
      'Content-Type': 'application/json',
    };

    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  // Add this method for public endpoints (no auth token)
  static Future<Map<String, String>> _getPublicHeaders() async {
    return {
      'Content-Type': 'application/json',
    };
  }

  // Update the get method to accept a parameter for public endpoints
  static Future<dynamic> get(String endpoint, {bool isPublic = false}) async {
    try {
      final headers = isPublic ? await _getPublicHeaders() : await _getHeaders();
      final url = '$baseUrl/$endpoint';

      print('Making GET request to: $url');
      print('Headers: $headers');

      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to get data: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('API Error: $e');
      throw Exception('Error: $e');
    }
  }

  // Also update other methods if needed for consistency
  // In api_service.dart - Update the post method
  static Future<dynamic> post(String endpoint, dynamic data, {bool isPublic = false}) async {
    try {
      final headers = isPublic ? await _getPublicHeaders() : await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/$endpoint'),
        headers: headers,
        body: data != null ? json.encode(data) : '{}', // Handle empty data
      );

      // Accept both 200 (OK) and 201 (Created) as success
      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to post data: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // ... keep the put and delete methods as they were
  static Future<dynamic> put(String endpoint, dynamic data) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/$endpoint'),
        headers: await _getHeaders(),
        body: json.encode(data),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to put data: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  static Future<dynamic> delete(String endpoint) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/$endpoint'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to delete data: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }
}
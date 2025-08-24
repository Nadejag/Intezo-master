// lib/services/auth_service.dart
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class AuthService {
  // Add this to your AuthService class
  static Future<Map<String, dynamic>?> getCachedPatientData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString('patientName');
      final phone = prefs.getString('patientPhone');

      if (name != null && phone != null) {
        return {
          'name': name,
          'phone': phone,
        };
      }
      return null;
    } catch (e) {
      print('Error getting cached patient data: $e');
      return null;
    }
  }

  static Future<bool> patientLogin(String phone) async {
    try {
      final response = await ApiService.post('auth/login/patient', {
        'phone': phone,
      });

      if (response['token'] != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', response['token']);
        await prefs.setString('patientId', response['patient']['_id']);
        await prefs.setString('patientName', response['patient']['name']);
        await prefs.setString('patientPhone', response['patient']['phone']);
        return true;
      }
      return false;
    } catch (e) {
      throw Exception('Login failed: $e');
    }
  }

  static Future<bool> registerPatient(String name, String phone) async {
    try {
      final response = await ApiService.post('patients/register', {
        'name': name,
        'phone': phone,
      });

      if (response['_id'] != null) {
        return true;
      }
      return false;
    } catch (e) {
      throw Exception('Registration failed: $e');
    }
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token') != null;
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('patientId');
    await prefs.remove('patientName');
    await prefs.remove('patientPhone');
  }

  static Future<Map<String, dynamic>?> getPatientProfile() async {
    try {
      final response = await ApiService.get('patients/profile');
      return response;
    } catch (e) {
      throw Exception('Failed to get profile: $e');
    }
  }
}
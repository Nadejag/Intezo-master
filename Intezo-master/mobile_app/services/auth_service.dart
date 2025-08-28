// lib/services/auth_service.dart
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import '../models/patient.dart';
import 'database_service.dart';
import 'network_service.dart';

class AuthService {
  // Add this to your AuthService class
  static Future<Map<String, dynamic>?> getCachedPatientData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final patientId = prefs.getString('patientId');
      
      if (patientId != null) {
        // Try to get from local database first
        final patient = await DatabaseService.getPatient(patientId);
        if (patient != null) {
          return patient.toJson();
        }
      }
      
      // Fallback to SharedPreferences
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

  static Future<bool> logoutFromAllDevices() async {
    try {
      final response = await ApiService.post('auth/logout/all', null);
      return response['success'] == true;
    } catch (e) {
      print('Logout from all devices failed: $e');
      return false;
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
        
        // Save patient data to local database
        final patient = Patient.fromJson(response['patient']);
        await DatabaseService.savePatient(patient);
        
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
    final patientId = prefs.getString('patientId');
    
    // Clear local database data
    if (patientId != null) {
      await DatabaseService.clearPatientData(patientId);
    }
    
    await prefs.remove('token');
    await prefs.remove('patientId');
    await prefs.remove('patientName');
    await prefs.remove('patientPhone');
  }

  static Future<Map<String, dynamic>?> getPatientProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final patientId = prefs.getString('patientId');
    
    // Check network connectivity first
    final isOnline = await NetworkService.isConnected();
    print('AuthService: Network status: $isOnline');
    if (!isOnline) {
      print('AuthService: No network, using offline profile');
      if (patientId != null) {
        final patient = await DatabaseService.getPatient(patientId);
        if (patient != null) {
          return patient.toJson();
        }
      }
      throw Exception('No offline profile data available');
    }
    
    try {
      final response = await ApiService.get('patients/profile');
      
      // Save updated profile to local database
      if (response != null) {
        final patient = Patient.fromJson(response);
        await DatabaseService.savePatient(patient);
      }
      
      return response;
    } catch (e) {
      // If network fails, try to get from local database
      if (patientId != null) {
        final patient = await DatabaseService.getPatient(patientId);
        if (patient != null) {
          return patient.toJson();
        }
      }
      
      throw Exception('Failed to get profile: $e');
    }
  }
}
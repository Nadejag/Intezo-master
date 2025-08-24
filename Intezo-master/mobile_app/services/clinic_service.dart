// lib/services/clinic_service.dart
import 'api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ClinicService {
  // lib/services/clinic_service.dart - Update getClinics method with better error handling
  static Future<List<Map<String, dynamic>>> getClinics() async {
    try {
      print('Making API call to: clinics/public');
      final response = await ApiService.get('clinics/public', isPublic: true);
      print('API response received: $response');

      if (response is List) {
        return List<Map<String, dynamic>>.from(response);
      } else {
        print('Unexpected response format: $response');
        return [];
      }
    } catch (e) {
      print('Failed to get clinics: $e');
      throw Exception('Failed to get clinics: $e');
    }
  }

  // lib/services/clinic_service.dart - Update getClinicStatus method
  // lib/services/clinic_service.dart - Update getClinicStatus method
  static Future<Map<String, dynamic>> getClinicStatus(String clinicId) async {
    try {
      print('Fetching clinic status for: $clinicId');
      final response = await ApiService.get('clinics/$clinicId/status', isPublic: true);
      print('Clinic status response: $response');

      return {
        'isOpen': response['isOpen'] ?? false,
        'operatingHours': response['operatingHours'] ?? {'opening': '09:00', 'closing': '17:00'},
        'name': response['name'] ?? 'Clinic',
        'lastStatusChange': response['lastStatusChange'] // Add this for better tracking
      };
    } catch (e) {
      print('Error getting clinic status: $e');
      return {
        'isOpen': false,
        'operatingHours': {'opening': '09:00', 'closing': '17:00'},
        'name': 'Unknown Clinic',
        'lastStatusChange': null
      };
    }
  }


// Add this method to get real-time queue data
// In clinic_service.dart - Update getRealTimeQueue method
// In clinic_service.dart - Update getRealTimeQueue method
  // In clinic_service.dart - Update getRealTimeQueue with better error handling
  static Future<Map<String, dynamic>> getRealTimeQueue(String clinicId) async {
    try {
      print('Getting real-time queue for clinic: $clinicId');

      // Use public endpoint for queue data (no auth required)
      final response = await ApiService.get('queues/public/$clinicId', isPublic: true);

      print('Queue API response: $response');

      if (response is Map<String, dynamic>) {
        return response;
      } else {
        print('Unexpected response format: $response');
        return {
          'current': 0,
          'nextNumber': 1,
          'upcoming': [],
          'totalWaiting': 0,
          'avgWaitTime': 15,
          'canCallNext': false
        };
      }
    } catch (e) {
      print('Error getting real-time queue: $e');
      // Return default data instead of throwing exception
      return {
        'current': 0,
        'nextNumber': 1,
        'upcoming': [],
        'totalWaiting': 0,
        'avgWaitTime': 15,
        'canCallNext': false
      };
    }
  }

  static Future<Map<String, dynamic>> bookQueueNumber(String clinicId, String patientId) async {
    try {
      final response = await ApiService.post('queues/book', {
        'clinicId': clinicId,
        'patientId': patientId,
      });
      return Map<String, dynamic>.from(response);
    } catch (e) {
      throw Exception('Failed to book queue number: $e');
    }
  }

  static Future<Map<String, dynamic>> getCurrentQueue(String clinicId) async {
    try {
      final response = await ApiService.get('queues/$clinicId');
      return Map<String, dynamic>.from(response);
    } catch (e) {
      throw Exception('Failed to get current queue: $e');
    }
  }

  static Future<Map<String, dynamic>> getQueueStatus(String queueId) async {
    try {
      final response = await ApiService.get('queues/status/$queueId');
      return Map<String, dynamic>.from(response);
    } catch (e) {
      throw Exception('Failed to get queue status: $e');
    }
  }

  static Future<Map<String, dynamic>?> getPatientCurrentQueue() async {
    try {
      final response = await ApiService.get('patients/queue-status');
      return Map<String, dynamic>.from(response);
    } catch (e) {
      print('Error getting patient queue: $e');
      return null;
    }
  }
  // Add to clinic_service.dart
  // In clinic_service.dart - Update the cancelBooking method
  static Future<bool> cancelBooking(String queueId) async {
    try {
      // Change from DELETE to POST
      final response = await ApiService.post('queues/cancel/$queueId', {});
      return response['success'] == true;
    } catch (e) {
      throw Exception('Failed to cancel booking: $e');
    }
  }
}
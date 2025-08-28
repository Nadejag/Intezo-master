// lib/services/clinic_service.dart
import 'api_service.dart';

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

  static Future<List<Map<String, dynamic>>> getDoctors(String clinicId) async {
    try {
      print('Making API call to get doctors for clinic: $clinicId');
      final response = await ApiService.get('doctors/public/$clinicId', isPublic: true);
      print('Doctors API response: $response');

      if (response is List) {
        return List<Map<String, dynamic>>.from(response);
      } else if (response is Map<String, dynamic> && response.containsKey('error')) {
        print('Error from doctors API: ${response['error']}');
        return [];
      } else {
        print('Unexpected response format for doctors: $response');
        return [];
      }
    } catch (e) {
      print('Failed to get doctors: $e');
      return [];
    }
  }

// lib/services/clinic_service.dart - Update getRealTimeQueue method
  static Future<Map<String, dynamic>> getRealTimeQueue(String clinicId, {String? doctorId}) async {
    try {
      print('Getting real-time queue for clinic: $clinicId${doctorId != null ? ', doctor: $doctorId' : ''}');

      if (doctorId == null) {
        // If no doctor is selected, return default data instead of making a request
        print('No doctor selected, returning default queue data');
        return {
          'current': 0,
          'nextNumber': 1,
          'upcoming': [],
          'totalWaiting': 0,
          'avgWaitTime': 15,
          'canCallNext': false,
          'isDoctorQueue': false
        };
      }

      // Use doctor-specific public endpoint
      final response = await ApiService.get(
          'queues/public/$clinicId/$doctorId',
          isPublic: true
      );

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
          'canCallNext': false,
          'isDoctorQueue': true
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
        'canCallNext': false,
        'isDoctorQueue': doctorId != null
      };
    }
  }
// Update bookQueueNumber method
  static Future<Map<String, dynamic>> bookQueueNumber(String clinicId, String patientId, {String? doctorId}) async {
    try {
      final data = {
        'clinicId': clinicId,
        'patientId': patientId,
        'doctorId': doctorId, // Ensure doctorId is always included
      };

      print('Booking with data: $data');

      final response = await ApiService.post('queues/book-doctor', data);

      print('Booking response: $response');

      if (response is Map<String, dynamic>) {
        if (response.containsKey('error')) {
          throw Exception(response['error']);
        }
        return response;
      } else {
        throw Exception('Invalid response format from server');
      }
    } catch (e) {
      print('Booking service error: $e');
      throw Exception('Failed to book queue number: $e');
    }
  }

// Add method to get doctor details
  static Future<Map<String, dynamic>?> getDoctorDetails(String doctorId) async {
    try {
      final response = await ApiService.get('doctors/$doctorId');
      return Map<String, dynamic>.from(response);
    } catch (e) {
      print('Error getting doctor details: $e');
      return null;
    }
  }

  // FIXED: Remove the doctorId parameter that was causing the error
  static Future<Map<String, dynamic>> getCurrentQueue(String clinicId) async {
    try {
      final response = await ApiService.get('queues/$clinicId');
      return Map<String, dynamic>.from(response);
    } catch (e) {
      throw Exception('Failed to get current queue: $e');
    }
  }

  // FIXED: Add doctor-specific queue method
  static Future<Map<String, dynamic>> getDoctorQueue(String clinicId, String doctorId) async {
    try {
      final response = await ApiService.get(
          'queues/public/$clinicId',
          isPublic: true,
          queryParams: {'doctorId': doctorId}
      );
      return Map<String, dynamic>.from(response);
    } catch (e) {
      throw Exception('Failed to get doctor queue: $e');
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

// Add method to get doctor details
//   static Future<Map<String, dynamic>?> getDoctorDetails(String doctorId) async {
//     try {
//       final response = await ApiService.get('doctors/$doctorId');
//       return Map<String, dynamic>.from(response);
//     } catch (e) {
//       print('Error getting doctor details: $e');
//       return null;
//     }
//   }
}
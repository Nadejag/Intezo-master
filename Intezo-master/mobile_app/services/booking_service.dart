import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import '../models/booking.dart';
import 'database_service.dart';
import 'network_service.dart';

class BookingService {
  static Future<List<Booking>> getBookingHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final patientId = prefs.getString('patientId');

    if (patientId == null) {
      throw Exception('Patient not logged in');
    }

    print('BookingService: Getting history for patient $patientId');

    // Check network connectivity first
    final isOnline = await NetworkService.isConnected();
    print('BookingService: Network status: $isOnline');
    if (!isOnline) {
      print('BookingService: No network, using offline data');
      return await DatabaseService.getBookingHistory(patientId);
    }

    try {
      // Try to fetch from API
      print('BookingService: Trying API call...');
      final response = await ApiService.get('patients/$patientId/history');
      
      if (response != null && response is List) {
        print('BookingService: API returned ${response.length} bookings');
        final bookings = response.map((json) {
          // Add patientId to each booking since API doesn't include it
          json['patientId'] = patientId;
          return Booking.fromJson(json);
        }).toList();
        
        // Save to local database
        await DatabaseService.saveBookings(bookings);
        print('BookingService: Saved to database');
        
        return bookings;
      }
      
      print('BookingService: API returned null/invalid, trying offline...');
      // If API returns null or not a list, try offline data
      final offlineBookings = await DatabaseService.getBookingHistory(patientId);
      print('BookingService: Found ${offlineBookings.length} offline bookings');
      return offlineBookings;
    } catch (e) {
      print('BookingService: API failed, trying offline data: $e');
      // If network fails, get from local database
      final offlineBookings = await DatabaseService.getBookingHistory(patientId);
      print('BookingService: Found ${offlineBookings.length} offline bookings after error');
      

      
      return offlineBookings;
    }
  }

  static Future<List<Booking>> getOfflineBookingHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final patientId = prefs.getString('patientId');
    
    if (patientId != null) {
      return await DatabaseService.getBookingHistory(patientId);
    }
    
    return [];
  }
}
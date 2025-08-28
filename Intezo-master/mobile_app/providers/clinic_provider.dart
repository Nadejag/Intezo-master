// lib/providers/clinic_provider.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import '../main.dart';
import '../services/api_service.dart';
import '../services/clinic_service.dart';
import '../services/event_bus.dart';

class ClinicProvider with ChangeNotifier {
  bool _isLoading = false;
  List<Map<String, dynamic>> _clinics = [];
  Map<String, dynamic>? _selectedClinic;
  Map<String, dynamic>? _currentQueue;
  String? _error;

  bool get isLoading => _isLoading;
  List<Map<String, dynamic>> get clinics => _clinics;
  Map<String, dynamic>? get selectedClinic => _selectedClinic;
  Map<String, dynamic>? get currentQueue => _currentQueue;
  String? get error => _error;

// In ClinicProvider - Update the loadClinics method to handle 201 errors
  Future<void> loadClinics() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      print('Loading clinics from API...');
      final response = await ClinicService.getClinics();
      print('API response: $response');

      _clinics = List<Map<String, dynamic>>.from(response);
      print('Loaded ${_clinics.length} clinics from backend');

      // Backend now provides isOpen status, no need to override

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      print('Error loading clinics: $e');

      // Check if this is the 201 error from booking (which should be ignored)
      if (e.toString().contains('201')) {
        // This is a false error from booking - clear it and try again
        _error = null;
        // Retry loading clinics
        await loadClinics();
      } else {
        _error = e.toString();
      }

      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> selectClinic(Map<String, dynamic> clinic) async {
    _selectedClinic = clinic;
    notifyListeners();

    // Load clinic status and queue
    await loadClinicStatus(clinic['_id']);
    await loadCurrentQueue(clinic['_id']);
  }

  Future<void> loadClinicStatus(String clinicId) async {
    try {
      final status = await ClinicService.getClinicStatus(clinicId);

      // Update clinic with status
      final index = _clinics.indexWhere((c) => c['_id'] == clinicId);
      if (index != -1) {
        // Create a new map with the merged data
        final updatedClinic = Map<String, dynamic>.from(_clinics[index]);
        updatedClinic.addAll(Map<String, dynamic>.from(status));
        _clinics[index] = updatedClinic;
        notifyListeners();
      }

      // Also update selected clinic if it's the same
      if (_selectedClinic != null && _selectedClinic!['_id'] == clinicId) {
        _selectedClinic = {..._selectedClinic!, ...status};
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

// In clinic_provider.dart - Update loadCurrentQueue method
// In clinic_provider.dart - Update loadCurrentQueue method
// lib/providers/clinic_provider.dart - Update loadCurrentQueue method
  Future<void> loadCurrentQueue(String clinicId, {bool forceRefresh = false, String? doctorId}) async {
    if (!forceRefresh && _currentQueue != null) {
      // Check if data is fresh (less than 30 seconds old)
      final lastUpdated = _currentQueue?['_lastUpdated'];
      if (lastUpdated != null) {
        final lastUpdateTime = DateTime.parse(lastUpdated);
        if (DateTime.now().difference(lastUpdateTime).inSeconds < 30) {
          return; // Data is fresh, no need to reload
        }
      }
    }

    try {
      final response = await ClinicService.getRealTimeQueue(clinicId, doctorId: doctorId);

      // Always create a valid queue data structure even if response is empty
      _currentQueue = {
        'current': response['current'] ?? 0,
        'nextNumber': (response['current'] ?? 0) + 1,
        'upcoming': response['upcoming'] ?? [],
        'totalWaiting': response['totalWaiting'] ?? 0,
        'avgWaitTime': response['avgWaitTime'] ?? 15,
        'canCallNext': response['canCallNext'] ?? false,
        '_lastUpdated': DateTime.now().toIso8601String(),
        'isDoctorQueue': doctorId != null // Add flag to identify doctor-specific queue
      };

      notifyListeners();
    } catch (e) {
      print('Error loading current queue: $e');
      // Set default queue data instead of showing error
      _currentQueue = {
        'current': 0,
        'nextNumber': 1,
        'upcoming': [],
        'totalWaiting': 0,
        'avgWaitTime': 15,
        'canCallNext': false,
        '_lastUpdated': DateTime.now().toIso8601String(),
        'isDoctorQueue': doctorId != null
      };
      notifyListeners();
    }
  }

// lib/services/clinic_service.dart - Update the bookQueueNumber method
// Update the bookQueueNumber method
  Future<Map<String, dynamic>> bookQueueNumber(String clinicId, String patientId, {String? doctorId}) async {
    try {
      if (doctorId == null) {
        throw Exception('Doctor ID is required for booking');
      }

      final result = await ClinicService.bookQueueNumber(clinicId, patientId, doctorId: doctorId);

      // Handle the new response format from backend
      if (result.containsKey('error')) {
        throw Exception(result['error']);
      }

      return result;
    } catch (e) {
      print('Booking error in provider: $e');
      throw Exception('Failed to book queue number: $e');
    }
  }

// Update getDoctors method
  Future<List<Map<String, dynamic>>> getDoctors(String clinicId) async {
    try {
      return await ClinicService.getDoctors(clinicId);
    } catch (e) {
      print('Error getting doctors: $e');
      return [];
    }
  }


  // ADD THIS METHOD - to get queue status
  Future<Map<String, dynamic>?> getQueueStatus(String queueId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await ClinicService.getQueueStatus(queueId);
      _isLoading = false;
      notifyListeners();
      // FIX: Handle null response
      return response != null ? Map<String, dynamic>.from(response) : null;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  // ADD THIS METHOD - to get patient's current queue
// In clinic_provider.dart - Update getPatientCurrentQueue method
  Future<Map<String, dynamic>?> getPatientCurrentQueue() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await ApiService.get('patients/queue-status');
      print('Patient queue status response: $response');

      if (response != null && response is Map<String, dynamic>) {
        // Check if patient was served and clear the booking
        if (response['currentQueue'] != null &&
            response['currentQueue']['status'] == 'served') {
          // Patient was served, emit event for real-time updates
          // EventBus().emitPatientServed(PatientServedEvent(
          //   patientId: response['currentQueue']['_id'],
          //   bookingData: response['currentQueue']
          // ));
          _isLoading = false;
          notifyListeners();
          return {'currentQueue': null, 'message': 'Patient has been served'};
        }
        
        // Return the response as-is, let the UI handle the logic
        _isLoading = false;
        notifyListeners();
        return response;
      }

      _isLoading = false;
      notifyListeners();
      return null;
    } catch (e) {
      print('Error getting patient queue: $e');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  final SocketService _socketService = SocketService.instance;
  String? _currentListeningClinicId;
  Timer? _pollingTimer;

  void startListeningForUpdates(String clinicId, {String? doctorId}) {
    if (_currentListeningClinicId == clinicId) return;
    
    stopListeningForUpdates();
    stopPolling();

    _currentListeningClinicId = clinicId;

    _connectToPusher(clinicId, doctorId: doctorId);
    startPollingForUpdates(clinicId, doctorId: doctorId);

      // Listen to event bus for queue updates
      _queueUpdateSubscription = EventBus().onQueueUpdate.listen((event) {
        if (event.clinicId == clinicId && event.doctorId == doctorId) {
          print('Real-time queue update received for clinic $clinicId, doctor: $doctorId: ${event.queueData}');

          _currentQueue = {
            ...event.queueData,
            '_lastUpdated': DateTime.now().toIso8601String(),
            'isDoctorQueue': doctorId != null
          };

          notifyListeners();
        }
      });

      // Listen to clinic status updates
      _clinicStatusSubscription = EventBus().onClinicStatusUpdate.listen((event) {
        if (event.clinicId == clinicId) {
          print('Real-time clinic status update received for clinic $clinicId');

          // Update clinic status in the list
          final index = _clinics.indexWhere((c) => c['_id'] == clinicId);
          if (index != -1) {
            _clinics[index]['isOpen'] = event.statusData['isOpen'];
            _clinics[index]['lastStatusChange'] = event.statusData['lastStatusChange'];
            notifyListeners();
          }

          // Update selected clinic if it's the same
          if (_selectedClinic != null && _selectedClinic!['_id'] == clinicId) {
            _selectedClinic = {
              ..._selectedClinic!,
              'isOpen': event.statusData['isOpen'],
              'lastStatusChange': event.statusData['lastStatusChange']
            };
            notifyListeners();
          }
        }
      });
  }

  void startPollingForUpdates(String clinicId, {String? doctorId}) {
    // Polling completely disabled to prevent home screen refresh
  }

// Add this method to connect to Pusher
  Future<void> _connectToPusher(String clinicId, {String? doctorId}) async {
    try {
      _socketService.setFallbackCallback((fallbackClinicId, fallbackDoctorId) {
        print('Pusher failed, using polling for: $fallbackClinicId');
        startPollingForUpdates(fallbackClinicId, doctorId: fallbackDoctorId);
      });
      
      await _socketService.connect(clinicId: clinicId, doctorId: doctorId);
      print('Pusher connection for clinic: $clinicId${doctorId != null ? ', doctor: $doctorId' : ''}');
    } catch (e) {
      print('Pusher connection failed: $e');
      startPollingForUpdates(clinicId, doctorId: doctorId);
    }
  }

  void stopListeningForUpdates() {
    _socketService.disconnect();
    _currentListeningClinicId = null;
  }

  void clearSpecificError(String errorPattern) {
    if (_error != null && _error!.contains(errorPattern)) {
      _error = null;
      notifyListeners();
    }
  }

// Add these class variables
  StreamSubscription? _queueUpdateSubscription;
  StreamSubscription? _clinicStatusSubscription;

  @override
  void dispose() {
    stopListeningForUpdates();
    stopPolling();
    _queueUpdateSubscription?.cancel();
    _clinicStatusSubscription?.cancel();
    super.dispose();
  }

  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  void startPollingForClinicUpdates() {
    // Polling disabled to prevent screen flickering
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void retryLoading() {
    loadClinics();
  }
}
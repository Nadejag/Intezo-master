// lib/providers/patient_provider.dart
import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';

class PatientProvider with ChangeNotifier {
  Map<String, dynamic>? _patientData;
  bool _isLoading = false;
  String? _error;

  Map<String, dynamic>? get patientData => _patientData;
  bool get isLoading => _isLoading;
  String? get error => _error;

  PatientProvider() {
    // Load cached data immediately
    _loadCachedData();
  }

  Future<void> _loadCachedData() async {
    try {
      final cachedData = await AuthService.getCachedPatientData();
      if (cachedData != null) {
        _patientData = cachedData;
        notifyListeners();
      }
    } catch (e) {
      print('Error loading cached data: $e');
    }
  }

  Future<void> loadPatientProfile() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await AuthService.getPatientProfile();
      _patientData = response;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
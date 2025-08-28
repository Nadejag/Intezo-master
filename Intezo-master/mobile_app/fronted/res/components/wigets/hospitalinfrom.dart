// lib/fronted/res/components/wigets/hospitalinfrom.dart
import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../providers/clinic_provider.dart';
import '../../../../providers/theme_provider.dart';
import '../../../../services/clinic_service.dart';
import '../../../../services/event_bus.dart';
import 'booknow.dart';
import 'doctor_selection_modal.dart';

class HospitalInform extends StatefulWidget {
  final dynamic clinic;

  HospitalInform({super.key, required this.clinic});

  @override
  State<HospitalInform> createState() => _HospitalInformState();
}

class _HospitalInformState extends State<HospitalInform> {
  bool loading = false;
  bool _isRefreshing = false;
  bool _hasActiveBooking = false;
  int _selectedDoctorIndex = -1; // -1 means no doctor selected

  Map<String, dynamic>? _queueData;
  List<Map<String, dynamic>> _doctors = [];
  // Store queue data for each doctor
  Map<String, Map<String, dynamic>> _doctorQueues = {};
  ClinicProvider? _clinicProvider;
  StreamSubscription? _queueUpdateSubscription;

  // New state variables for optimized doctor selection
  String _searchQuery = '';
  List<Map<String, dynamic>> _filteredDoctors = [];
  final ScrollController _doctorScrollController = ScrollController();
  bool _showSearchBar = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDoctors();
      _checkActiveBooking();
    });
    _setupRealTimeUpdates();
  }

  // Remove the call from didChangeDependencies since we're handling it in initState
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _clinicProvider = Provider.of<ClinicProvider>(context, listen: false);
  }

  @override
  void dispose() {
    _queueUpdateSubscription?.cancel();
    _doctorScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadDoctors() async {
    try {
      print('Loading doctors for clinic: ${widget.clinic['_id']}');
      final response = await _clinicProvider?.getDoctors(widget.clinic['_id']);
      print('Doctors response: $response');

      if (response != null && response is List) {
        print('Found ${response.length} doctors');
        setState(() {
          _doctors = List<Map<String, dynamic>>.from(response);
          _filteredDoctors = _doctors;
        });

        // Load queue data for each doctor
        for (var doctor in _doctors) {
          print('Loading queue for doctor: ${doctor['name']}');
          _loadDoctorQueue(doctor['_id']);
        }

        // Select first doctor by default
        if (_doctors.isNotEmpty) {
          setState(() {
            _selectedDoctorIndex = 0;
          });
          _loadClinicQueue(doctorId: _doctors[0]['_id']);
        } else {
          print('No doctors found for this clinic');
        }
      } else {
        print('No doctors data received or invalid format');
        setState(() {
          _doctors = [];
          _filteredDoctors = [];
        });
      }
    } catch (e) {
      print('Error loading doctors: $e');
      setState(() {
        _doctors = [];
        _filteredDoctors = [];
      });
    }
  }

  Future<void> _loadDoctorQueue(String doctorId) async {
    try {
      final clinicProvider = Provider.of<ClinicProvider>(
        context,
        listen: false,
      );
      await clinicProvider.loadCurrentQueue(
        widget.clinic['_id'],
        forceRefresh: true,
        doctorId: doctorId,
      );

      setState(() {
        _doctorQueues[doctorId] =
            clinicProvider.currentQueue ??
                {
                  'current': 0,
                  'nextNumber': 1,
                  'upcoming': [],
                  'totalWaiting': 0,
                  'avgWaitTime': 15,
                  'canCallNext': false,
                };
      });
    } catch (e) {
      print('Error loading doctor queue data: $e');
      setState(() {
        _doctorQueues[doctorId] = {
          'current': 0,
          'nextNumber': 1,
          'upcoming': [],
          'totalWaiting': 0,
          'avgWaitTime': 15,
          'canCallNext': false,
        };
      });
    }
  }

  Future<void> _checkActiveBooking() async {
    try {
      final clinicProvider = Provider.of<ClinicProvider>(
        context,
        listen: false,
      );
      final queueData = await clinicProvider.getPatientCurrentQueue();

      print('Active booking check result: $queueData');

      setState(() {
        // Check if we have a currentQueue object (active booking)
        // OR if we get an error indicating no active booking
        _hasActiveBooking =
            queueData != null &&
                queueData['currentQueue'] != null &&
                queueData['error'] == null;

        print('Has active booking: $_hasActiveBooking');
      });
    } catch (e) {
      print('Error checking active booking: $e');
      setState(() {
        _hasActiveBooking = false;
      });
    }
  }

  // In hospitalinfrom.dart - Update _loadClinicQueue method
  Future<void> _loadClinicQueue({String? doctorId}) async {
    try {
      setState(() {
        _isRefreshing = true;
      });

      // If no doctorId provided, use the selected doctor
      final targetDoctorId =
          doctorId ??
              (_selectedDoctorIndex != -1
                  ? _doctors[_selectedDoctorIndex]['_id']
                  : null);

      if (targetDoctorId == null) {
        print('No doctor selected, cannot load queue data');
        setState(() {
          _isRefreshing = false;
        });
        return;
      }

      final clinicProvider = Provider.of<ClinicProvider>(
        context,
        listen: false,
      );
      await clinicProvider.loadCurrentQueue(
        widget.clinic['_id'],
        forceRefresh: true,
        doctorId: targetDoctorId,
      );

      setState(() {
        _queueData = clinicProvider.currentQueue;
        _isRefreshing = false;
      });
    } catch (e) {
      print('Error loading queue data: $e');
      setState(() {
        _isRefreshing = false;
      });
    }
  }

  // In hospitalinfrom.dart - Update _setupRealTimeUpdates
  void _setupRealTimeUpdates() {
    // Listen for clinic status changes
    final clinicStatusSubscription = EventBus().onClinicStatusUpdate.listen((
        event,
        ) {
      if (event.clinicId == widget.clinic['_id'] && mounted) {
        setState(() {
          widget.clinic['isOpen'] = event.statusData['isOpen'];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              event.statusData['isOpen']
                  ? 'Clinic is now open!'
                  : 'Clinic is now closed!',
            ),
            backgroundColor: event.statusData['isOpen']
                ? Colors.green
                : Colors.red,
          ),
        );
      }
    });

    _queueUpdateSubscription = EventBus().onQueueUpdate.listen((event) {
      if (event.clinicId == widget.clinic['_id']) {
        print('Queue update received: ${event.queueData}');

        // Update specific doctor's queue if doctorId matches
        if (event.doctorId != null) {
          setState(() {
            _doctorQueues[event.doctorId!] = {
              ...event.queueData,
              'nextNumber': _calculateNextNumber(
                event.queueData['current'] ?? 0,
                event.queueData,
              ),
            };
          });
        }

        // If this is the selected doctor, update the main queue data
        if (_selectedDoctorIndex != -1 &&
            event.doctorId == _doctors[_selectedDoctorIndex]['_id']) {
          setState(() {
            _queueData = {
              ...event.queueData,
              'nextNumber': _calculateNextNumber(
                event.queueData['current'] ?? 0,
                event.queueData,
              ),
            };
          });
        }
      }
    });
  }

  // In hospitalinfrom.dart - Update queue calculation
  int _calculateNextNumber(
      int currentServing,
      Map<String, dynamic>? queueData,
      ) {
    if (queueData == null) return currentServing + 1;

    final upcoming = queueData['upcoming'] as List? ?? [];

    // If there are upcoming patients, find the highest number
    if (upcoming.isNotEmpty) {
      final highestUpcoming = upcoming.fold<int>(0, (max, patient) {
        final number = patient['number'] as int? ?? 0;
        return number > max ? number : max;
      });
      return highestUpcoming + 1;
    }

    // If no upcoming patients, next number is current + 1
    return currentServing + 1;
  }

  // Replace the _buildDoctorSelection method with this simplified version
  Widget _buildDoctorSelection() {
    if (_doctors.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text(
            'No doctors available at this clinic',
            style: TextStyle(fontSize: 16, color: context.subtextColor),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final selectedDoctor = _selectedDoctorIndex != -1
        ? _doctors[_selectedDoctorIndex]
        : null;
    final doctorQueue = selectedDoctor != null
        ? _doctorQueues[selectedDoctor['_id']] ??
        {'current': 0, 'nextNumber': 1, 'totalWaiting': 0}
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text(
          'Selected Doctor',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: context.textColor,
          ),
        ),
        const SizedBox(height: 12),

        // Selected doctor card or select button
        if (selectedDoctor != null)
          _buildSelectedDoctorCard(
            doctor: selectedDoctor,
            currentServing: doctorQueue?['current'] ?? 0,
            nextNumber: _calculateNextNumber(
              doctorQueue?['current'] ?? 0,
              doctorQueue,
            ),
            totalWaiting: doctorQueue?['totalWaiting'] ?? 0,
          )
        else
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _showDoctorSelectionModal,
              style: ElevatedButton.styleFrom(
                backgroundColor: context.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Select Doctor',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // Add this method to show the doctor selection modal
  void _showDoctorSelectionModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (context, scrollController) => DoctorSelectionModal(
          doctors: _doctors,
          doctorQueues: _doctorQueues,
          calculateNextNumber: _calculateNextNumber,
          onDoctorSelected: (doctor) {
            final index = _doctors.indexWhere((d) => d['_id'] == doctor['_id']);
            if (index != -1) {
              setState(() {
                _selectedDoctorIndex = index;
              });
              _loadClinicQueue(doctorId: doctor['_id']);
            }
          },
        ),
      ),
    );
  }

  Widget _buildSelectedDoctorCard({
    required Map<String, dynamic> doctor,
    required int currentServing,
    required int nextNumber,
    required int totalWaiting,
  }) {
    final bool isAvailable = doctor['isAvailable'] ?? true;
    final bool isActive = doctor['isActive'] ?? true;
    final isDarkMode = context.isDarkMode;
    final primaryColor = context.primaryColor;

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.1),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: (!isAvailable || !isActive)
                            ? isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300
                            : primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Icon(
                        Icons.person,
                        color: (!isAvailable || !isActive)
                            ? Colors.grey
                            : primaryColor,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            doctor['name'] ?? 'Doctor',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: (!isAvailable || !isActive)
                                  ? context.subtextColor
                                  : context.textColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            doctor['specialty'] ?? 'General Practitioner',
                            style: TextStyle(
                              fontSize: 14,
                              color: (!isAvailable || !isActive)
                                  ? context.subtextColor.withOpacity(0.7)
                                  : context.subtextColor,
                            ),
                          ),
                          if (!isAvailable || !isActive)
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                !isActive ? 'Not Active' : 'Not Available',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.red,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.edit, color: context.textColor),
                      onPressed: _showDoctorSelectionModal,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Queue information for this doctor
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildQueueInfoItem('Serving', '$currentServing', false),
                      _buildQueueInfoItem('Next', '$nextNumber', false),
                      _buildQueueInfoItem('Waiting', '$totalWaiting', false),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _showDoctorSelectionModal,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              side: BorderSide(color: context.primaryColor),
            ),
            child: Text(
              'Change Doctor',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: context.primaryColor,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQueueInfoItem(String label, String value, bool compact) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: compact ? 10 : 12,
            color: context.subtextColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: compact ? 14 : 16,
            fontWeight: FontWeight.bold,
            color: context.primaryColor,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.isDarkMode;
    final isOpen = widget.clinic['isOpen'] ?? true;
    final currentServing = _queueData?['current'] ?? 0;
    final nextNumber = _calculateNextNumber(currentServing, _queueData);

    // Get selected doctor info
    final selectedDoctor = _selectedDoctorIndex == -1
        ? null
        : _doctors[_selectedDoctorIndex];

    final doctorFee = selectedDoctor != null
        ? (selectedDoctor['consultationFee'] ?? 0)
        : 0;

    // Disable booking if clinic is closed OR user has active booking OR no doctor selected
    final canBook =
        isOpen && !_hasActiveBooking && !loading && _selectedDoctorIndex != -1;

    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        title: Text(
          widget.clinic['name'] ?? 'Clinic',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.bold,
            color: context.textColor,
          ),
        ),
        backgroundColor: context.cardColor,
        elevation: 0,
        foregroundColor: context.textColor,
        actions: [
          IconButton(
            icon: Icon(
              Icons.refresh,
              color: context.textColor,
            ),
            onPressed: () {
              if (_selectedDoctorIndex != -1) {
                _loadClinicQueue(
                  doctorId: _doctors[_selectedDoctorIndex]['_id'],
                );
              }
              // Refresh all doctor queues
              for (var doctor in _doctors) {
                _loadDoctorQueue(doctor['_id']);
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Clinic Information Card
            Container(
              decoration: BoxDecoration(
                color: context.cardColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.1),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.clinic['name'] ?? 'Clinic',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: context.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (widget.clinic['address'] != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 16,
                              color: context.subtextColor,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                widget.clinic['address']!,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: context.subtextColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 16,
                          color: context.subtextColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${widget.clinic['operatingHours']?['opening'] ?? '09:00'} - '
                              '${widget.clinic['operatingHours']?['closing'] ?? '17:00'}',
                          style: TextStyle(
                            fontSize: 14,
                            color: context.subtextColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isOpen
                                ? Colors.green.withOpacity(isDarkMode ? 0.2 : 0.1)
                                : Colors.red.withOpacity(isDarkMode ? 0.2 : 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isOpen
                                  ? Colors.green.withOpacity(isDarkMode ? 0.5 : 0.3)
                                  : Colors.red.withOpacity(isDarkMode ? 0.5 : 0.3),
                            ),
                          ),
                          child: Text(
                            isOpen ? 'OPEN' : 'CLOSED',
                            style: TextStyle(
                              color: isOpen ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Doctor Selection Section
            _buildDoctorSelection(),

            const SizedBox(height: 20),

            // Queue Information Card - Only show if doctor is selected
            if (_selectedDoctorIndex != -1)
              Container(
                decoration: BoxDecoration(
                  color: context.cardColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.1),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Queue Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: context.textColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildQueueInfoRow(
                        'Currently Serving:',
                        '$currentServing',
                      ),
                      _buildQueueInfoRow(
                        'Next Available:',
                        '$nextNumber',
                      ),
                      _buildQueueInfoRow(
                        'Patients Waiting:',
                        '${_queueData?['totalWaiting'] ?? 0}',
                      ),
                      _buildQueueInfoRow(
                        'Consultation Fee:',
                        'PKR $doctorFee',
                      ),

                      // Show active booking warning if user has one
                      if (_hasActiveBooking)
                        Padding(
                          padding: const EdgeInsets.only(top: 12, bottom: 8),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(isDarkMode ? 0.2 : 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange.withOpacity(isDarkMode ? 0.5 : 0.3)),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.warning,
                                  color: Colors.orange,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'You already have an active booking',
                                    style: TextStyle(
                                      color: Colors.orange,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: canBook ? _bookQueue : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: canBook
                                ? context.primaryColor
                                : Colors.grey.shade400,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: loading
                              ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(
                                Colors.white,
                              ),
                            ),
                          )
                              : Text(
                            _hasActiveBooking
                                ? 'Already Booked'
                                : 'Book Queue Number',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 20),

            // Additional Information
            Container(
              decoration: BoxDecoration(
                color: context.cardColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.1),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'About this Clinic',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: context.textColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.clinic['description'] ??
                          'This clinic provides quality healthcare services. '
                              'Please arrive 10 minutes before your scheduled time.',
                      style: TextStyle(
                        fontSize: 14,
                        color: context.subtextColor,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildQueueInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: context.subtextColor,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: context.primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  // In _bookQueue method - Update the booking call
  Future<void> _bookQueue() async {
    if (_selectedDoctorIndex == -1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a doctor first')),
      );
      return;
    }

    try {
      setState(() {
        loading = true;
      });

      final prefs = await SharedPreferences.getInstance();
      final patientId = prefs.getString('patientId');
      final token = prefs.getString('token');

      if (patientId == null || token == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Please login first')));
        return;
      }

      // Double-check if user already has active booking
      final clinicProvider = Provider.of<ClinicProvider>(
        context,
        listen: false,
      );
      final currentQueue = await clinicProvider.getPatientCurrentQueue();

      if (currentQueue != null &&
          currentQueue['currentQueue'] != null &&
          currentQueue['error'] == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You already have an active booking')),
        );
        setState(() {
          loading = false;
          _hasActiveBooking = true;
        });
        return;
      }

      // Get selected doctor ID
      final doctorId = _doctors[_selectedDoctorIndex]['_id'];

      // Call the updated booking method with doctorId
      final result = await clinicProvider.bookQueueNumber(
        widget.clinic['_id'],
        patientId,
        doctorId: doctorId,
      );

      if (result != null) {
        if (result['queueNumber'] != null || result['success'] == true) {
          await _loadClinicQueue(doctorId: doctorId);
          await _checkActiveBooking();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Booking successful! Your number: ${result['queueNumber'] ?? 'N/A'}',
              ),
            ),
          );

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => Booknow(
                clinic: widget.clinic,
                queueNumber: result['queueNumber'] ?? 0,
                doctor: _doctors[_selectedDoctorIndex],
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Booking completed successfully!')),
          );
          await _loadClinicQueue(doctorId: doctorId);
          await _checkActiveBooking();
          Navigator.pop(context);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking failed: No response from server'),
          ),
        );
      }
    } catch (e) {
      print('Booking error: $e');

      if (e.toString().contains('Doctor is not available')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Selected doctor is not available. Please choose another doctor.',
            ),
          ),
        );
      } else if (e.toString().contains('201')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking completed successfully!')),
        );
        await _loadClinicQueue(doctorId: _doctors[_selectedDoctorIndex]['_id']);
        await _checkActiveBooking();
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    } finally {
      setState(() {
        loading = false;
      });
    }
  }
}
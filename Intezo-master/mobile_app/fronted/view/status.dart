import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qatar_app/fronted/view/bottom_navigator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/clinic_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/api_service.dart';
import '../../services/clinic_service.dart';
import '../../services/event_bus.dart';
import '../res/components/wigets/colors.dart';

class Status extends StatefulWidget {
  const Status({super.key});

  @override
  State<Status> createState() => _StatusState();
}

class _StatusState extends State<Status> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _queueData;

  StreamSubscription? _queueUpdateSubscription;
  StreamSubscription? _patientServedSubscription;
  ClinicProvider? _clinicProvider;

  @override
  void initState() {
    super.initState();

    // Use a delay to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    await _loadCurrentQueueStatus();
    _setupRealTimeUpdates();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: isDarkMode
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: isDarkMode ? AppColors.darkCard : Colors.white,
        title: Text(
          "Queue Status",
          style: TextStyle(
            color: isDarkMode ? AppColors.darkText : AppColors.lightText,
          ),
        ),
        foregroundColor: isDarkMode ? AppColors.darkText : AppColors.lightText,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              Icons.refresh,
              color: isDarkMode ? Colors.white70 : Colors.black54,
            ),
            onPressed: () {
              _loadCurrentQueueStatus();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildMainContent(isDarkMode),
    );
  }

  Widget _buildMainContent(bool isDarkMode) {
    if (_error != null) {
      return _buildErrorState(isDarkMode);
    }

    // Check if we have an active booking (not null, not error, and not served)
    final hasActiveBooking =
        _queueData != null &&
        _queueData!['currentQueue'] != null &&
        _queueData!['error'] == null &&
        _queueData!['currentQueue']['status'] != 'served';

    print('Queue data status: ${_queueData?['currentQueue']?['status']}');
    print('Has active booking: $hasActiveBooking');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current queue status (if available)
          if (hasActiveBooking)
            _buildCurrentQueueCard(_queueData!['currentQueue'], isDarkMode)
          else
            _buildNoQueueEncouragement(isDarkMode),
        ],
      ),
    );
  }

  void _setupRealTimeUpdates() {
    _queueUpdateSubscription = EventBus().onQueueUpdate.listen((event) {
      print('🔥 Real-time event received in Status screen: ${event.queueData}');

      // Show a snackbar to indicate real-time update received
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Real-time update received!'),
            duration: Duration(seconds: 1),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Always reload status when any event is received
      _loadCurrentQueueStatus();
    });

    // Listen for patient served events
    // _patientServedSubscription = EventBus().onPatientServed.listen((event) {
    //   if (mounted) {
    //     ScaffoldMessenger.of(context).showSnackBar(
    //       SnackBar(
    //         content: Text('You have been served! Updating booking history...'),
    //         duration: Duration(seconds: 3),
    //         backgroundColor: Colors.green,
    //       ),
    //     );
    //     _loadBookingHistory(); // Refresh booking history
    //     _loadCurrentQueueStatus(); // Clear current queue
    //   }
    // });
  }

  Future<void> _loadCurrentQueueStatus() async {
    try {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _error = null;
        });
      }

      final clinicProvider = Provider.of<ClinicProvider>(
        context,
        listen: false,
      );
      final queueData = await clinicProvider.getPatientCurrentQueue();

      print('Queue status response: $queueData');

      // Check if we have queue data
      if (queueData != null &&
          queueData['currentQueue'] != null &&
          queueData['error'] == null) {
        final status = queueData['currentQueue']['status'];
        print('Current booking status: $status');

        // Check if patient was served - if so, clear the booking
        if (status == 'served') {
          print('Patient was served, clearing booking');
          setState(() {
            _queueData = null;
          });

          // Show served message
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'You have been served! You can now book a new appointment.',
                ),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 3),
              ),
            );
          }

          // Stop listening for updates
          clinicProvider.stopListeningForUpdates();
        } else {
          // Active booking - show it
          print('Active booking found with status: $status');
          setState(() {
            _queueData = queueData;
          });

          final clinicId = queueData['currentQueue']['clinic']['_id'];
          final doctorId = queueData['currentQueue']['doctor']?['_id'];

          // Start listening for updates with doctor-specific channel (optimized)
          clinicProvider.startListeningForUpdates(clinicId, doctorId: doctorId);
        }
      } else {
        // No active booking - clear the data
        print('No queue data found, clearing booking');
        setState(() {
          _queueData = null;
        });

        // Stop listening for updates since there's no active booking
        clinicProvider.stopListeningForUpdates();
      }
    } catch (e) {
      setState(() {
        _error = 'Error loading queue status: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _queueUpdateSubscription?.cancel();
    _patientServedSubscription?.cancel();

    // Stop listening for updates when screen is disposed
    if (_clinicProvider != null) {
      _clinicProvider!.stopListeningForUpdates();
    }

    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _clinicProvider = Provider.of<ClinicProvider>(context, listen: false);
  }

  Widget _buildErrorState(bool isDarkMode) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
          const SizedBox(height: 16),
          Text(
            _error!,
            style: TextStyle(
              fontSize: 16,
              color: isDarkMode ? AppColors.darkText : AppColors.lightText,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _loadData,
            style: ElevatedButton.styleFrom(
              backgroundColor: colors().bluecolor1,
              foregroundColor: Colors.white,
            ),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildNoQueueEncouragement(bool isDarkMode) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.1 : 0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(Icons.calendar_today, size: 48, color: colors().bluecolor1),
          const SizedBox(height: 16),
          Text(
            'No Active Booking',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colors().bluecolor1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Book an appointment to see your queue status here',
            style: TextStyle(
              color: isDarkMode ? AppColors.darkSubtext : Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const BottomNav()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colors().bluecolor1,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Book Appointment'),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentQueueCard(dynamic queueData, bool isDarkMode) {
    final queueNumber = queueData['number'] ?? 'N/A';
    final currentServing = queueData['currentServing'] ?? 0;
    final positionInQueue = (queueNumber is int && currentServing is int)
        ? queueNumber - currentServing
        : 0;
    final estimatedWait = positionInQueue > 0 ? positionInQueue * 5 : 0;
    final queueId = queueData['_id'];
    final clinicName = queueData['clinic']?['name'] ?? 'Unknown Clinic';
    final doctorName = queueData['doctor']?['name'] ?? 'Unknown Doctor';
    final doctorSpecialty = queueData['doctor']?['specialty'] ?? '';

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isDarkMode ? AppColors.darkCard : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Text(
              'Current Booking',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: colors().bluecolor1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              clinicName,
              style: TextStyle(
                fontSize: 16,
                color: isDarkMode
                    ? AppColors.darkSubtext
                    : Colors.grey.shade600,
              ),
            ),
            if (doctorName.isNotEmpty)
              Column(
                children: [
                  const SizedBox(height: 4),
                  Text(
                    'Dr. $doctorName',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDarkMode
                          ? AppColors.darkSubtext
                          : Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            if (doctorSpecialty.isNotEmpty)
              Column(
                children: [
                  const SizedBox(height: 2),
                  Text(
                    doctorSpecialty,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDarkMode
                          ? AppColors.darkSubtext
                          : Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 16),
            Text(
              '$queueNumber',
              style: TextStyle(
                fontSize: 64,
                fontWeight: FontWeight.bold,
                color: colors().bluecolor1,
              ),
            ),
            const SizedBox(height: 16),
            _buildStatusRow(
              'Currently Serving:',
              '$currentServing',
              Colors.blue.shade800,
              isDarkMode,
            ),
            _buildStatusRow(
              'Your Position:',
              positionInQueue > 0 ? '$positionInQueue' : 'Being served',
              positionInQueue > 0
                  ? Colors.orange.shade700
                  : Colors.green.shade700,
              isDarkMode,
            ),
            _buildStatusRow(
              'Estimated Wait:',
              positionInQueue > 0 ? '$estimatedWait minutes' : '0 minutes',
              positionInQueue > 0
                  ? Colors.orange.shade700
                  : Colors.green.shade700,
              isDarkMode,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      _loadCurrentQueueStatus();
                      // Test Pusher connection
                      final clinicProvider = Provider.of<ClinicProvider>(
                        context,
                        listen: false,
                      );
                      final clinicId =
                          _queueData!['currentQueue']['clinic']['_id'];
                      final doctorId =
                          _queueData!['currentQueue']['doctor']?['_id'];
                      clinicProvider.startListeningForUpdates(
                        clinicId,
                        doctorId: doctorId,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors().bluecolor1,
                      foregroundColor: Colors.white,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.refresh, size: 20),
                        const SizedBox(width: 8),
                        const Text('Refresh'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _cancelBooking(queueId),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.cancel, size: 20),
                        const SizedBox(width: 8),
                        const Text('Cancel'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(
    String label,
    String value,
    Color? valueColor,
    bool isDarkMode,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: isDarkMode ? AppColors.darkSubtext : Colors.grey.shade700,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  // In status.dart - Update the _cancelBooking method
  Future<void> _cancelBooking(String queueId) async {
    bool confirmCancel = await showDialog(
      context: context,
      builder: (BuildContext context) {
        final themeProvider = Provider.of<ThemeProvider>(context);
        final isDarkMode = themeProvider.isDarkMode;

        return AlertDialog(
          backgroundColor: isDarkMode ? AppColors.darkCard : Colors.white,
          title: Text(
            "Confirm Cancellation",
            style: TextStyle(
              color: isDarkMode ? AppColors.darkText : AppColors.lightText,
            ),
          ),
          content: Text(
            "Are you sure you want to cancel this booking?",
            style: TextStyle(
              color: isDarkMode
                  ? AppColors.darkSubtext
                  : AppColors.lightSubtext,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                "No",
                style: TextStyle(
                  color: isDarkMode
                      ? AppColors.darkSubtext
                      : AppColors.lightSubtext,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text("Yes", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (!confirmCancel) return;

    try {
      setState(() {
        _isLoading = true;
      });

      final success = await ClinicService.cancelBooking(queueId);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking cancelled successfully')),
        );

        // Stop listening for updates since booking is cancelled
        final clinicProvider = Provider.of<ClinicProvider>(
          context,
          listen: false,
        );
        clinicProvider.stopListeningForUpdates();

        // Reload data after successful cancellation
        await _loadCurrentQueueStatus();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to cancel booking')),
        );
      }
    } catch (e) {
      String errorMessage = 'Failed to cancel booking';
      if (e.toString().contains('404')) {
        errorMessage = 'Booking not found or already processed';
      } else if (e.toString().contains('400')) {
        errorMessage = 'Cannot cancel already processed booking';
      } else if (e.toString().contains('401') || e.toString().contains('403')) {
        errorMessage = 'Authentication error - please login again';
      } else if (e.toString().contains('Doctor not available')) {
        errorMessage = 'Cannot cancel - doctor is not available';
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMessage)));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Add this method to handle doctor-specific real-time data
  void _handleDoctorSpecificUpdate(QueueUpdateEvent event) {
    if (_queueData != null && _queueData!['currentQueue'] != null) {
      final currentDoctorId = _queueData!['currentQueue']['doctor']?['_id'];

      // Only process updates for the specific doctor or general clinic updates
      if (event.doctorId == null || event.doctorId == currentDoctorId) {
        setState(() {
          _queueData!['currentQueue']['currentServing'] =
              event.queueData['currentNumber'];

          final queueNumber = _queueData!['currentQueue']['number'];
          final currentServing = event.queueData['currentNumber'];
          final positionInQueue = queueNumber - currentServing;
          final estimatedWait = positionInQueue > 0 ? positionInQueue * 5 : 0;

          _queueData!['currentQueue']['positionInQueue'] = positionInQueue;
          _queueData!['currentQueue']['estimatedWait'] = estimatedWait;
        });
      }
    }
  }
}

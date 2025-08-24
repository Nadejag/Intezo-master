import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qatar_app/fronted/view/bottom_navigator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/clinic_provider.dart';
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
  List<dynamic> _bookingHistory = [];
  StreamSubscription? _queueUpdateSubscription;
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
    await _loadBookingHistory();
    _setupRealTimeUpdates();
  }

  Future<void> _loadBookingHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final patientId = prefs.getString('patientId');

      if (patientId != null) {
        // Use the correct endpoint for booking history
        final response = await ApiService.get('patients/$patientId/history');

        if (response != null && response is List) {
          setState(() {
            _bookingHistory = List<dynamic>.from(response);
          });
        } else {
          // If no history from API, show empty list instead of error
          setState(() {
            _bookingHistory = [];
          });
        }
      }
    } catch (e) {
      print('Error loading booking history: $e');
      // Even if there's an error, set empty history to avoid UI issues
      setState(() {
        _bookingHistory = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colors.bgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text("Queue Status"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadCurrentQueueStatus();
              _loadBookingHistory();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildMainContent(),
    );
  }

  Widget _buildMainContent() {
    if (_error != null) {
      return _buildErrorState();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current queue status (if available)
          if (_queueData != null && _queueData!['currentQueue'] != null)
            _buildCurrentQueueCard(_queueData!['currentQueue']),

          if (_queueData != null && _queueData!['currentQueue'] != null)
            const SizedBox(height: 24),

          // Always show booking history section
          _buildBookingHistorySection(),

          // Show encouragement to book if no current queue
          if (_queueData == null || _queueData!['currentQueue'] == null)
            _buildNoQueueEncouragement(),
        ],
      ),
    );
  }

  void _setupRealTimeUpdates() {
    _queueUpdateSubscription = EventBus().onQueueUpdate.listen((event) {
      print('Real-time queue update received in Status screen');
      if (_queueData != null && _queueData!['currentQueue'] != null) {
        setState(() {
          _queueData!['currentQueue']['currentServing'] = event.queueData['currentNumber'];

          final queueNumber = _queueData!['currentQueue']['number'];
          final currentServing = event.queueData['currentNumber'];
          final positionInQueue = queueNumber - currentServing;
          final estimatedWait = positionInQueue > 0 ? positionInQueue * 5 : 0;

          _queueData!['currentQueue']['positionInQueue'] = positionInQueue;
          _queueData!['currentQueue']['estimatedWait'] = estimatedWait;
        });
      }
    });
  }

  Future<void> _loadCurrentQueueStatus() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final clinicProvider = Provider.of<ClinicProvider>(context, listen: false);
      final queueData = await clinicProvider.getPatientCurrentQueue();

      if (queueData != null && queueData['currentQueue'] != null) {
        setState(() {
          _queueData = queueData;
        });

        final clinicId = queueData['currentQueue']['clinic']['_id'];
        clinicProvider.startListeningForUpdates(clinicId);
      } else {
        setState(() {
          _queueData = null; // Ensure queueData is null when no active queue
        });
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
    _clinicProvider?.stopListeningForUpdates();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _clinicProvider = Provider.of<ClinicProvider>(context, listen: false);
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
          const SizedBox(height: 16),
          Text(
            _error!,
            style: const TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _loadData,
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildNoQueueEncouragement() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(
            Icons.calendar_today,
            size: 48,
            color: colors().bluecolor1,
          ),
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
            style: TextStyle(color: Colors.grey.shade600),
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

  Widget _buildCurrentQueueCard(dynamic queueData) {
    final queueNumber = queueData['number'] ?? 'N/A';
    final currentServing = queueData['currentServing'] ?? 0;
    final positionInQueue = (queueNumber is int && currentServing is int)
        ? queueNumber - currentServing
        : 0;
    final estimatedWait = positionInQueue > 0 ? positionInQueue * 5 : 0;
    final queueId = queueData['_id'];
    final clinicName = queueData['clinic']?['name'] ?? 'Unknown Clinic';

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
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
                color: Colors.grey.shade600,
              ),
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
            _buildStatusRow('Currently Serving:', '$currentServing', Colors.blue.shade800),
            _buildStatusRow('Your Position:', positionInQueue > 0 ? '$positionInQueue' : 'Being served',
                positionInQueue > 0 ? Colors.orange.shade700 : Colors.green.shade700),
            _buildStatusRow('Estimated Wait:', positionInQueue > 0 ? '$estimatedWait minutes' : '0 minutes',
                positionInQueue > 0 ? Colors.orange.shade700 : Colors.green.shade700),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _loadCurrentQueueStatus,
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

  Widget _buildBookingHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Booking History',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 12),
        _bookingHistory.isEmpty
            ? Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              Icon(
                Icons.history,
                size: 40,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 12),
              Text(
                'No past bookings yet',
                style: TextStyle(
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        )
            : ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _bookingHistory.length,
          itemBuilder: (context, index) {
            final booking = _bookingHistory[index];
            return _buildHistoryItem(booking);
          },
        ),
      ],
    );
  }

  Widget _buildHistoryItem(dynamic booking) {
    final isServed = booking['status'] == 'served';
    final clinicName = booking['clinic']?['name'] ?? 'Unknown Clinic';
    final queueNumber = booking['number'] ?? 'N/A';
    final date = _formatDate(booking['servedAt'] ?? booking['bookedAt'] ?? '');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isServed ? Colors.green.shade50 : Colors.orange.shade50,
            shape: BoxShape.circle,
          ),
          child: Icon(
            isServed ? Icons.check_circle : Icons.pending,
            color: isServed ? Colors.green : Colors.orange,
          ),
        ),
        title: Text(
          'Queue #$queueNumber - $clinicName',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          'Status: ${booking['status']?.toString().toUpperCase() ?? 'UNKNOWN'}',
          style: TextStyle(
            color: isServed ? Colors.green.shade700 : Colors.orange.shade700,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: Text(
          date,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      if (dateString.isEmpty) return 'Unknown date';

      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Unknown date';
    }
  }

  Widget _buildStatusRow(String label, String value, Color? valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          )),
          Text(value, style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: valueColor,
          )),
        ],
      ),
    );
  }

  // In status.dart - Update the _cancelBooking method
  Future<void> _cancelBooking(String queueId) async {
    bool confirmCancel = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Confirm Cancellation"),
          content: const Text("Are you sure you want to cancel this booking?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text("No"),
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

        // Reload data after successful cancellation
        await _loadCurrentQueueStatus();
        await _loadBookingHistory();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to cancel booking')),
        );
      }
    } catch (e) {
      // More specific error handling
      String errorMessage = 'Failed to cancel booking';
      if (e.toString().contains('404')) {
        errorMessage = 'Booking not found or already processed';
      } else if (e.toString().contains('400')) {
        errorMessage = 'Cannot cancel already processed booking';
      } else if (e.toString().contains('401') || e.toString().contains('403')) {
        errorMessage = 'Authentication error - please login again';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
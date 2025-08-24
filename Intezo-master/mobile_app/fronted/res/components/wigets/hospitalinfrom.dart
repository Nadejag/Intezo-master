// lib/fronted/res/components/wigets/hospitalinfrom.dart
import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../providers/clinic_provider.dart';
import '../../../../services/event_bus.dart';
import 'booknow.dart';
import 'colors.dart';

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

  Map<String, dynamic>? _queueData;
  ClinicProvider? _clinicProvider;
  StreamSubscription? _queueUpdateSubscription;

  @override
  void initState() {
    super.initState();
    _loadClinicQueue();
    _checkActiveBooking();
    _setupRealTimeUpdates();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _clinicProvider = Provider.of<ClinicProvider>(context, listen: false);
    _clinicProvider?.startListeningForUpdates(widget.clinic['_id']);
  }

  @override
  void dispose() {
    _queueUpdateSubscription?.cancel();
    _clinicProvider?.stopListeningForUpdates();
    super.dispose();
  }

  Future<void> _checkActiveBooking() async {
    try {
      final clinicProvider = Provider.of<ClinicProvider>(context, listen: false);
      final queueData = await clinicProvider.getPatientCurrentQueue();

      setState(() {
        _hasActiveBooking = queueData != null && queueData['currentQueue'] != null;
      });
    } catch (e) {
      print('Error checking active booking: $e');
    }
  }

  Future<void> _loadClinicQueue() async {
    try {
      setState(() { _isRefreshing = true; });

      final clinicProvider = Provider.of<ClinicProvider>(context, listen: false);
      await clinicProvider.loadCurrentQueue(widget.clinic['_id'], forceRefresh: true);

      setState(() {
        _queueData = clinicProvider.currentQueue;
        _isRefreshing = false;
      });
    } catch (e) {
      print('Error loading queue data: $e');
      setState(() { _isRefreshing = false; });
    }
  }

  void _setupRealTimeUpdates() {
    _queueUpdateSubscription = EventBus().onQueueUpdate.listen((event) {
      if (event.clinicId == widget.clinic['_id']) {
        print('Queue update received in UI: ${event.queueData}');

        final upcoming = event.queueData['upcoming'] as List? ?? [];
        int nextNumber = (event.queueData['current'] ?? 0) + 1;

        if (upcoming.isNotEmpty) {
          final highestNumber = upcoming.fold<int>(0, (max, patient) {
            final number = patient['number'] as int? ?? 0;
            return number > max ? number : max;
          });
          nextNumber = highestNumber + 1;
        }

        setState(() {
          _queueData = {
            ...event.queueData,
            'nextNumber': nextNumber
          };
        });

        print('UI updated with new queue data');
      }
    });
  }

  int _calculateNextNumber(int currentServing, Map<String, dynamic>? queueData) {
    if (queueData == null) return currentServing + 1;

    final upcoming = queueData['upcoming'] as List? ?? [];
    if (upcoming.isNotEmpty) {
      final highestUpcoming = upcoming.fold<int>(0, (max, patient) {
        final number = patient['number'] as int? ?? 0;
        return number > max ? number : max;
      });
      return highestUpcoming + 1;
    }

    return currentServing + 1;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isOpen = widget.clinic['isOpen'] ?? true;
    final currentServing = _queueData?['current'] ?? 0;
    final nextNumber = _calculateNextNumber(currentServing, _queueData);

    // Disable booking if clinic is closed OR user has active booking
    final canBook = isOpen && !_hasActiveBooking && !loading;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.clinic['name'] ?? 'Clinic',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadClinicQueue,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Clinic Information Card
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
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
                        color: colors().bluecolor1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (widget.clinic['address'] != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          children: [
                            Icon(Icons.location_on,
                                size: 16, color: Colors.grey.shade600),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                widget.clinic['address']!,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Row(
                      children: [
                        Icon(Icons.access_time,
                            size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 8),
                        Text(
                          '${widget.clinic['operatingHours']?['opening'] ?? '09:00'} - '
                              '${widget.clinic['operatingHours']?['closing'] ?? '17:00'}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isOpen
                                ? Colors.green.shade50
                                : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isOpen
                                  ? Colors.green.shade200
                                  : Colors.red.shade200,
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

            // Queue Information Card
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
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
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildQueueInfoRow('Currently Serving:', '$currentServing'),
                    _buildQueueInfoRow('Next Available:', '$nextNumber'),

                    // Show active booking warning if user has one
                    if (_hasActiveBooking)
                      Padding(
                        padding: const EdgeInsets.only(top: 12, bottom: 8),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.warning, color: Colors.orange.shade700, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'You already have an active booking',
                                  style: TextStyle(
                                    color: Colors.orange.shade700,
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
                              ? colors().bluecolor1
                              : Colors.grey.shade400,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: loading
                            ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                            : Text(
                          _hasActiveBooking ? 'Already Booked' : 'Book Queue Number',
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
            Text(
              'About this Clinic',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              widget.clinic['description'] ??
                  'This clinic provides quality healthcare services. '
                      'Please arrive 10 minutes before your scheduled time.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
            ),
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
              color: Colors.grey.shade700,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: colors().bluecolor1,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _bookQueue() async {
    try {
      setState(() { loading = true; });

      final prefs = await SharedPreferences.getInstance();
      final patientId = prefs.getString('patientId');
      final token = prefs.getString('token');

      if (patientId == null || token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please login first')),
        );
        return;
      }

      // Double-check if user already has active booking
      final clinicProvider = Provider.of<ClinicProvider>(context, listen: false);
      final currentQueue = await clinicProvider.getPatientCurrentQueue();

      if (currentQueue != null && currentQueue['currentQueue'] != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You already have an active booking')),
        );
        setState(() {
          loading = false;
          _hasActiveBooking = true;
        });
        return;
      }

      final result = await clinicProvider.bookQueueNumber(
          widget.clinic['_id'],
          patientId
      );

      if (result != null) {
        if (result['number'] != null || result['success'] == true || result['_id'] != null) {
          await _loadClinicQueue();
          await _checkActiveBooking(); // Refresh booking status

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Booking successful! Your number: ${result['number'] ?? 'N/A'}')),
          );

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => Booknow(
                clinic: widget.clinic,
                queueNumber: result['number'] ?? 0,
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Booking completed successfully!')),
          );
          await _loadClinicQueue();
          await _checkActiveBooking(); // Refresh booking status
          Navigator.pop(context);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking failed: No response from server')),
        );
      }
    } catch (e) {
      print('Booking error: $e');

      if (e.toString().contains('201')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking completed successfully!')),
        );
        await _loadClinicQueue();
        await _checkActiveBooking(); // Refresh booking status
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      setState(() { loading = false; });
    }
  }
}
// lib/fronted/view/clinic_booking_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/clinic_provider.dart';
import '../../services/event_bus.dart';
import '../res/components/wigets/colors.dart';

class ClinicBookingScreen extends StatefulWidget {
  final Map<String, dynamic> clinic;

  const ClinicBookingScreen({super.key, required this.clinic});

  @override
  State<ClinicBookingScreen> createState() => _ClinicBookingScreenState();
}

class _ClinicBookingScreenState extends State<ClinicBookingScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _queueData;
  String? _error;
  StreamSubscription? _queueUpdateSubscription;

  @override
  void initState() {
    super.initState();
    _loadClinicQueue();
    _setupRealTimeUpdates();
  }

  void _setupRealTimeUpdates() {
    _queueUpdateSubscription = EventBus().onQueueUpdate.listen((event) {
      if (event.clinicId == widget.clinic['_id'] && mounted) {
        _loadClinicQueue();
      }
    });
  }

  @override
  void dispose() {
    _queueUpdateSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadClinicQueue() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final clinicProvider = Provider.of<ClinicProvider>(context, listen: false);
      await clinicProvider.loadCurrentQueue(widget.clinic['_id']);

      setState(() {
        _queueData = clinicProvider.currentQueue;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error loading queue: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _bookQueue() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final prefs = await SharedPreferences.getInstance();
      final patientId = prefs.getString('patientId');

      if (patientId == null) {
        setState(() {
          _error = 'Please login first';
          _isLoading = false;
        });
        return;
      }

      final clinicProvider = Provider.of<ClinicProvider>(context, listen: false);
      final result = await clinicProvider.bookQueueNumber(widget.clinic['_id'], patientId);

      if (result != null) {
        // Show success message and navigate to status screen
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Booking successful!'))
        );
        Navigator.pop(context); // Go back to home
        // You might want to navigate to status screen instead
      } else {
        setState(() {
          _error = 'Failed to book queue';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Booking failed: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colors.bgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text('Book at ${widget.clinic['name']}'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : _buildBookingUI(),
    );
  }

  Widget _buildBookingUI() {
    final currentServing = _queueData?['current'] ?? 0;
    final nextNumber = (_queueData?['nextNumber'] ?? currentServing + 1);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Clinic Info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.clinic['name'],
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(widget.clinic['address'] ?? ''),
                  const SizedBox(height: 8),
                  Text(
                    'Status: ${widget.clinic['isOpen'] == true ? 'OPEN' : 'CLOSED'}',
                    style: TextStyle(
                      color: widget.clinic['isOpen'] == true ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Queue Info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Queue Information',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow('Currently Serving:', '$currentServing'),
                  _buildInfoRow('Next Available Number:', '$nextNumber'),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: widget.clinic['isOpen'] == true ? _bookQueue : null,
                      child: const Text('Book This Number'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
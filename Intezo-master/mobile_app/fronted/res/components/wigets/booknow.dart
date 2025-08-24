// lib/fronted/res/components/wigets/booknow.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:qatar_app/fronted/res/components/wigets/patientdata.dart';
import 'package:qatar_app/fronted/res/components/wigets/roundbutton.dart';

import '../../../view/bottom_navigator.dart';
import '../../../view/status.dart';
import 'colors.dart';

// lib/fronted/res/components/wigets/booknow.dart
class Booknow extends StatelessWidget {
  final dynamic clinic;
  final int queueNumber;

  const Booknow({super.key, required this.clinic, required this.queueNumber});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking Confirmation'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle,
              size: 80,
              color: Colors.green.shade400,
            ),
            const SizedBox(height: 24),
            const Text(
              'Booking Confirmed!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Your queue number at ${clinic['name']}',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colors().bluecolor1.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors().bluecolor1.withOpacity(0.3)),
              ),
              child: Text(
                '$queueNumber',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: colors().bluecolor1,
                ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // Navigate directly to status page instead of bottom nav
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const Status()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors().bluecolor1,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'View Status',
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
    );
  }
}
// lib/fronted/view/homescreen.dart - Updated
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/clinic_provider.dart';
import '../../../providers/patient_provider.dart';
import '../res/components/wigets/colors.dart';
import '../res/components/wigets/home/hospital_sugest.dart';
import '../res/components/wigets/searchbutton.dart';
import 'clinic_booking_screen.dart';

class Homescreen extends StatefulWidget {
  const Homescreen({super.key});

  @override
  State<Homescreen> createState() => _HomescreenState();
}

class _HomescreenState extends State<Homescreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ClinicProvider>(context, listen: false).loadClinics();
      Provider.of<PatientProvider>(context, listen: false).loadPatientProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width * 1;
    final height = MediaQuery.sizeOf(context).width * 1;
    final clinicProvider = Provider.of<ClinicProvider>(context);
    final patientProvider = Provider.of<PatientProvider>(context);
    final patientData = patientProvider.patientData;

    return Scaffold(

      backgroundColor: colors.bgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('Queue App', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (patientData != null)
            CircleAvatar(
              radius: 16,
              backgroundColor: colors().bluecolor1,
              child: Text(
                patientData['name']? [0]?.toUpperCase() ?? 'U',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          // lib/fronted/view/homescreen.dart - Add a debug button temporarily
// In the actions section of AppBar, add:
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: () async {
              try {
                final clinicProvider = Provider.of<ClinicProvider>(context, listen: false);
                await clinicProvider.loadClinics();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Loaded ${clinicProvider.clinics.length} clinics')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
          ),
          // In homescreen.dart - Add debug button
          IconButton(
            icon: Icon(Icons.wifi_find),
            onPressed: () {
              final clinicProvider = Provider.of<ClinicProvider>(context, listen: false);
              if (clinicProvider.clinics.isNotEmpty) {
                clinicProvider.startListeningForUpdates(clinicProvider.clinics.first['_id']);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Started listening for clinic ${clinicProvider.clinics.first['_id']}')),
                );
              }
            },
          ),

          const SizedBox(width: 16),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Provider.of<ClinicProvider>(context, listen: false).loadClinics();
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Section
              if (patientData != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors().bluecolor1.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome back, ${patientData['name']}!',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Ready to book your next appointment?',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 20),

              // Search Section
              const Searchbutton(),

              const SizedBox(height: 24),

              // Clinics Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Available Clinics",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () => clinicProvider.loadClinics(),
                    tooltip: 'Refresh clinics',
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Clinics List
        // lib/fronted/view/homescreen.dart - Update the clinics list section
// Clinics List
        clinicProvider.isLoading
            ? const Center(child: CircularProgressIndicator())
            : // In homescreen.dart - Update the error handling section
        clinicProvider.error != null
            ? Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              // Check if this is the 201 error (which is actually success)
              if (clinicProvider.error!.contains('201'))
                Column(
                  children: [
                    Icon(Icons.check_circle, size: 48, color: Colors.green.shade400),
                    const SizedBox(height: 12),
                    Text(
                      'Booking Completed Successfully!',
                      style: TextStyle(color: Colors.green.shade600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your queue number has been booked successfully',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
                    const SizedBox(height: 12),
                    Text(
                      'Error loading clinics',
                      style: TextStyle(color: Colors.red.shade600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      clinicProvider.error!,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  // If it's a 201 error, clear it specifically
                  if (clinicProvider.error!.contains('201')) {
                    clinicProvider.clearSpecificError('201');
                  } else {
                    clinicProvider.loadClinics();
                  }
                },
                child: const Text('Try Again'),
              ),
            ],
          ),
        )
            : clinicProvider.clinics.isEmpty
            ? Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(Icons.business, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text(
                'No clinics available',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        )
            : Hospital_Suggestion(clinics: clinicProvider.clinics),
            ],
          ),
        ),
      ),

    );
  }

}
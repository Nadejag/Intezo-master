import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/clinic_provider.dart';
import '../../../providers/patient_provider.dart';
import '../../../providers/theme_provider.dart';
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
      _setupRealTimeUpdates();
    });
  }

  void _setupRealTimeUpdates() {
    // Removed all auto-refresh to prevent screen flickering
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final width = MediaQuery.sizeOf(context).width * 1;
    final height = MediaQuery.sizeOf(context).width * 1;
    final clinicProvider = Provider.of<ClinicProvider>(context);
    final patientProvider = Provider.of<PatientProvider>(context);
    final patientData = patientProvider.patientData;

    return Scaffold(
      backgroundColor: isDarkMode
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: isDarkMode ? AppColors.darkCard : Colors.white,
        title: Text(
          'Queue App',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDarkMode ? AppColors.darkText : AppColors.lightText,
          ),
        ),
        foregroundColor: isDarkMode ? AppColors.darkText : AppColors.lightText,
        elevation: 0,
        actions: [
          if (patientData != null)
            CircleAvatar(
              radius: 16,
              backgroundColor: colors().bluecolor1,
              child: Text(
                patientData['name']?[0]?.toUpperCase() ?? 'U',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          const SizedBox(width: 16),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Provider.of<ClinicProvider>(
            context,
            listen: false,
          ).loadClinics();
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
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode
                              ? AppColors.darkText
                              : AppColors.lightText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Ready to book your next appointment?',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDarkMode
                              ? AppColors.darkSubtext
                              : Colors.grey.shade600,
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
                  Text(
                    "Recently Visited",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode
                          ? AppColors.darkText
                          : AppColors.lightText,
                    ),
                  ),
                  TextButton(
                    onPressed: () => clinicProvider.loadClinics(),
                    child: Text(
                      'Refresh',
                      style: TextStyle(color: colors().bluecolor1),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Clinics List
              clinicProvider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : clinicProvider.error != null
                  ? Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDarkMode ? AppColors.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(
                        isDarkMode ? 0.1 : 0.08,
                      ),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Check if this is the 201 error (which is actually success)
                    if (clinicProvider.error!.contains('201'))
                      Column(
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 48,
                            color: Colors.green.shade400,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Booking Completed Successfully!',
                            style: TextStyle(
                              color: Colors.green.shade600,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Your queue number has been booked successfully',
                            style: TextStyle(
                              color: isDarkMode
                                  ? AppColors.darkSubtext
                                  : Colors.grey.shade600,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      )
                    else
                      Column(
                        children: [
                          Icon(
                            Icons.refresh,
                            size: 48,
                            color: isDarkMode
                                ? Colors.grey.shade400
                                : Colors.grey.shade500,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Unable to load clinics',
                            style: TextStyle(
                              color: isDarkMode
                                  ? AppColors.darkText
                                  : Colors.grey.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Please check your connection and try again',
                            style: TextStyle(
                              color: isDarkMode
                                  ? AppColors.darkSubtext
                                  : Colors.grey.shade600,
                              fontSize: 12,
                            ),
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
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors().bluecolor1,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              )
                  : clinicProvider.clinics.isEmpty
                  ? Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDarkMode ? AppColors.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(
                        isDarkMode ? 0.1 : 0.08,
                      ),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.business,
                      size: 48,
                      color: isDarkMode
                          ? Colors.grey.shade600
                          : Colors.grey.shade400,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No clinics available',
                      style: TextStyle(
                        color: isDarkMode
                            ? AppColors.darkText
                            : Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Check back later for available clinics',
                      style: TextStyle(
                        color: isDarkMode
                            ? AppColors.darkSubtext
                            : Colors.grey.shade500,
                        fontSize: 12,
                      ),
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
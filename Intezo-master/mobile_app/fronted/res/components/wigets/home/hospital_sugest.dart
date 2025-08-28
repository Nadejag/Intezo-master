// lib/fronted/res/components/wigets/home/hospital_sugest.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:qatar_app/providers/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../../providers/clinic_provider.dart';
import '../../../../../services/api_service.dart';
import '../../../../view/clinic_booking_screen.dart';
import '../hospitalinfrom.dart';


class Hospital_Suggestion extends StatefulWidget {
  final List<dynamic> clinics;
  final int maxClinicsToShow;

  const Hospital_Suggestion({super.key, required this.clinics, this.maxClinicsToShow = 5});

  @override
  State<Hospital_Suggestion> createState() => _Hospital_SuggestionState();
}

class _Hospital_SuggestionState extends State<Hospital_Suggestion> {
  late ClinicProvider _clinicProvider;
  List<dynamic> _previouslyBookedClinics = [];

  @override
  void initState() {
    super.initState();
    _clinicProvider = Provider.of<ClinicProvider>(context, listen: false);
    _loadPreviouslyBookedClinics();
  }

  Future<void> _loadPreviouslyBookedClinics() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final patientId = prefs.getString('patientId');

      if (patientId != null) {
        final response = await ApiService.get('patients/$patientId/history');

        if (response != null && response is List) {
          final now = DateTime.now();
          final threeMonthsAgo = now.subtract(const Duration(days: 90));

          // Get unique clinic IDs from recent bookings (last 3 months)
          final recentClinicIds = <String>{};

          for (final booking in response) {
            final bookingDate = DateTime.tryParse(booking['servedAt'] ?? booking['bookedAt'] ?? '');
            final clinicId = booking['clinic']?['_id'];

            if (bookingDate != null && bookingDate.isAfter(threeMonthsAgo)) {
              if (clinicId != null) {
                recentClinicIds.add(clinicId);
              }
            }
          }

          // Find clinics that match these IDs and sort by most recent visit
          _previouslyBookedClinics = widget.clinics.where((clinic) {
            return recentClinicIds.contains(clinic['_id']);
          }).toList();

          // Sort by most recent booking datetime (ascending - most recent first)
          _previouslyBookedClinics.sort((a, b) {
            final aLatest = response.where((booking) => booking['clinic']?['_id'] == a['_id'])
                .map((booking) => DateTime.parse(booking['servedAt'] ?? booking['bookedAt'] ?? '1970-01-01T00:00:00.000Z'))
                .reduce((a, b) => a.isAfter(b) ? a : b);
            final bLatest = response.where((booking) => booking['clinic']?['_id'] == b['_id'])
                .map((booking) => DateTime.parse(booking['servedAt'] ?? booking['bookedAt'] ?? '1970-01-01T00:00:00.000Z'))
                .reduce((a, b) => a.isAfter(b) ? a : b);
            return bLatest.compareTo(aLatest); // Most recent first
          });

          if (mounted) {
            setState(() {});
          }
        }
      }
    } catch (e) {
      _previouslyBookedClinics = [];
      if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = context.isDarkMode;
    final cardColor = context.cardColor;
    final textColor = context.textColor;
    final subtextColor = context.subtextColor;

    // Only show previously booked clinics
    final displayedClinics = _previouslyBookedClinics.take(widget.maxClinicsToShow).toList();

    if (displayedClinics.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(Icons.history, size: 48, color: subtextColor),
            const SizedBox(height: 12),
            Text(
              'No recent visits',
              style: TextStyle(color: subtextColor),
            ),
            const SizedBox(height: 8),
            Text(
              'Visit a clinic to see it here',
              style: TextStyle(color: subtextColor.withOpacity(0.7), fontSize: 12),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: displayedClinics.length,
          itemBuilder: (context, index) {
            final clinic = displayedClinics[index];
            // All displayed clinics are previously booked
            const isPreviouslyBooked = true;

            // Use Provider to get real-time status updates
            return Consumer<ClinicProvider>(
              builder: (context, clinicProvider, child) {
                // Find the latest clinic data from provider
                final updatedClinic = clinicProvider.clinics.firstWhere(
                      (c) => c['_id'] == clinic['_id'],
                  orElse: () => clinic,
                );

                final isOpen = updatedClinic['isOpen'] ?? true;
                final clinicName = updatedClinic['name'] ?? 'Unknown Clinic';
                final clinicAddress = updatedClinic['address'] ?? 'No address';
                final clinicDistance = updatedClinic['distance'] != null
                    ? '${updatedClinic['distance'].toStringAsFixed(1)} km away'
                    : 'Distance not available';

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.1),
                        spreadRadius: 1,
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ListTile(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => HospitalInform(
                            clinic: updatedClinic,
                          ),
                        ),
                      );
                    },
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: isOpen
                            ? context.primaryColor.withOpacity(0.1)
                            : Colors.grey.withOpacity(0.1),
                      ),
                      child: Center(
                        child: Icon(Icons.local_hospital_outlined,
                            color: isOpen ? context.primaryColor : Colors.grey, size: 28),
                      ),
                    ),
                    title: Text(
                      clinicName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          clinicAddress,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: subtextColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          clinicDistance,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            color: subtextColor.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: isOpen
                                ? Colors.green.withOpacity(isDarkMode ? 0.2 : 0.1)
                                : Colors.red.withOpacity(isDarkMode ? 0.2 : 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isOpen
                                  ? Colors.green.withOpacity(isDarkMode ? 0.5 : 0.3)
                                  : Colors.red.withOpacity(isDarkMode ? 0.5 : 0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            isOpen ? 'OPEN' : 'CLOSED',
                            style: TextStyle(
                              color: isOpen ? Colors.green : Colors.red,
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Previously visited',
                            style: TextStyle(
                              fontSize: 10,
                              color: context.primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}
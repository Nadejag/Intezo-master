// lib/fronted/res/components/wigets/home/hospital_sugest.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../providers/clinic_provider.dart';
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

  @override
  void initState() {
    super.initState();
    _clinicProvider = Provider.of<ClinicProvider>(context, listen: false);

    // Start listening for status updates for all clinics
    for (var clinic in widget.clinics.take(widget.maxClinicsToShow)) {
      _clinicProvider.startListeningForUpdates(clinic['_id']);
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayedClinics = widget.clinics.take(widget.maxClinicsToShow).toList();

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: displayedClinics.length,
      itemBuilder: (context, index) {
        final clinic = displayedClinics[index];

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

            return Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Card(
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
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
                  title: Text(
                    clinicName,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.06,
                      color: Colors.black.withOpacity(0.7),
                    ),
                  ),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(100),
                      color: Colors.indigo.withOpacity(0.3),
                    ),
                    child: Center(
                      child: Icon(Icons.health_and_safety_outlined,
                          color: isOpen ? Colors.indigo : Colors.grey),
                    ),
                  ),
                  subtitle: Text(
                    clinicAddress,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.06,
                      color: Colors.black.withOpacity(0.3),
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isOpen ? Colors.green.shade50 : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isOpen ? Colors.green.shade200 : Colors.red.shade200,
                          ),
                        ),
                        child: Text(
                          isOpen ? 'OPEN' : 'CLOSED',
                          style: TextStyle(
                            color: isOpen ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      if (isOpen)
                        IconButton(
                          icon: const Icon(Icons.add, size: 20),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ClinicBookingScreen(clinic: updatedClinic),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
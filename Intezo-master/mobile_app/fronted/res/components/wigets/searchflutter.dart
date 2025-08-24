// lib/fronted/res/components/wigets/searchflutter.dart - Professional Design
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qatar_app/services/clinic_service.dart';
import 'colors.dart';
import 'hospitalinfrom.dart';

class MainPageState extends StatefulWidget {
  const MainPageState({super.key});

  @override
  State<MainPageState> createState() => _MainPageStateState();
}

class _MainPageStateState extends State<MainPageState> {
  final controller = TextEditingController();
  List<Map<String, dynamic>> _clinics = [];
  List<Map<String, dynamic>> _filteredClinics = [];
  bool _isLoading = true;
  bool _isSearching = false;
  Timer? _debounceTimer;
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadClinics();
    _searchFocusNode.requestFocus();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    controller.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadClinics() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final clinics = await ClinicService.getClinics();
      setState(() {
        _clinics = List<Map<String, dynamic>>.from(clinics);
        _filteredClinics = _clinics;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading clinics: $e');
      setState(() {
        _isLoading = false;
        _clinics = [];
        _filteredClinics = [];
      });
    }
  }

  void _searchClinics(String query) {
    _debounceTimer?.cancel();

    if (query.isEmpty) {
      setState(() {
        _filteredClinics = _clinics;
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      final lowercaseQuery = query.toLowerCase();

      final suggestions = _clinics.where((clinic) {
        final clinicName = clinic['name']?.toString().toLowerCase() ?? '';
        final clinicAddress = clinic['address']?.toString().toLowerCase() ?? '';
        final clinicServices = (clinic['services'] as List<dynamic>?)
            ?.map((service) => service.toString().toLowerCase())
            .join(' ') ?? '';

        return clinicName.contains(lowercaseQuery) ||
            clinicAddress.contains(lowercaseQuery) ||
            clinicServices.contains(lowercaseQuery);
      }).toList();

      setState(() {
        _filteredClinics = suggestions;
        _isSearching = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final height = MediaQuery.sizeOf(context).height;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Clinics',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 24),
          onPressed: () => Navigator.of(context).pop(),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: colors().bluecolor1,
      ),
      body: Column(
        children: [
          // Search Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colors().bluecolor1,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                Text(
                  'Find Healthcare Services',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Search by name, location, or specialty',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),

          // Search Field
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: controller,
                focusNode: _searchFocusNode,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: "Search clinics...",
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 18,
                  ),
                  hintStyle: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade500,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: colors().bluecolor1,
                    size: 24,
                  ),
                  suffixIcon: _isSearching
                      ? Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(colors().bluecolor1),
                      ),
                    ),
                  )
                      : controller.text.isNotEmpty
                      ? IconButton(
                    icon: Icon(
                      Icons.clear,
                      color: Colors.grey.shade500,
                    ),
                    onPressed: () {
                      controller.clear();
                      _searchClinics('');
                    },
                  )
                      : null,
                ),
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade800,
                ),
                onChanged: _searchClinics,
              ),
            ),
          ),

          // Results Counter
          if (_filteredClinics.isNotEmpty && !_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    '${_filteredClinics.length} ${_filteredClinics.length == 1 ? 'clinic' : 'clinics'} found',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 8),

          // Results List
          Expanded(
            child: _buildResultsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsList() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(colors().bluecolor1),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading clinics...',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    if (_filteredClinics.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              controller.text.isEmpty
                  ? 'No clinics available'
                  : 'No results found for "${controller.text}"',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Try different keywords or check your spelling',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            if (controller.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: ElevatedButton(
                  onPressed: () {
                    controller.clear();
                    _searchClinics('');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors().bluecolor1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: const Text(
                    'Clear Search',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _filteredClinics.length,
      itemBuilder: (context, index) {
        final clinic = _filteredClinics[index];
        return _buildClinicListItem(clinic);
      },
    );
  }

  Widget _buildClinicListItem(Map<String, dynamic> clinic) {
    final isOpen = clinic['isOpen'] ?? false;
    final clinicName = clinic['name'] ?? 'Unknown Clinic';
    final clinicAddress = clinic['address'] ?? 'No address provided';
    final services = (clinic['services'] as List<dynamic>?)?.join(', ') ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => HospitalInform(clinic: clinic),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Clinic Icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: colors().bluecolor1.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.medical_services,
                    color: colors().bluecolor1,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),

                // Clinic Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        clinicName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        clinicAddress,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (services.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          services,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isOpen
                        ? Colors.green.withOpacity(0.1)
                        : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isOpen ? Colors.green : Colors.red,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    isOpen ? 'OPEN' : 'CLOSED',
                    style: TextStyle(
                      color: isOpen ? Colors.green : Colors.red,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
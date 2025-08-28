import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qatar_app/services/clinic_service.dart';
import '../../../../providers/theme_provider.dart';
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
  String? _errorMessage;
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
        _errorMessage = null;
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
        _errorMessage = 'Failed to load clinics';
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
        final clinicServices =
            (clinic['services'] as List<dynamic>?)
                ?.map((service) => service.toString().toLowerCase())
                .join(' ') ??
                '';

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
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: isDarkMode
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text(
          'Find Clinics',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            size: 24,
            color: isDarkMode ? Colors.white70 : Colors.black54,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        elevation: 0,
        backgroundColor: isDarkMode ? AppColors.darkCard : Colors.white,
        foregroundColor: colors().bluecolor1,
      ),
      body: Column(
        children: [
          // Search Header - Made more compact
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            decoration: BoxDecoration(
              color: colors().bluecolor1,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Column(
              children: [
                Text(
                  'Find Healthcare Services',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Search by name, location, or specialty',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),

          // Search Field - Made more compact
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Container(
              decoration: BoxDecoration(
                color: isDarkMode ? AppColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDarkMode ? 0.1 : 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
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
                    horizontal: 16,
                    vertical: 14,
                  ),
                  hintStyle: TextStyle(
                    fontSize: 14,
                    color: isDarkMode
                        ? AppColors.darkSubtext
                        : Colors.grey.shade500,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: colors().bluecolor1,
                    size: 22,
                  ),
                  suffixIcon: _isSearching
                      ? Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        valueColor: AlwaysStoppedAnimation(
                          colors().bluecolor1,
                        ),
                      ),
                    ),
                  )
                      : controller.text.isNotEmpty
                      ? IconButton(
                    icon: Icon(
                      Icons.clear,
                      color: isDarkMode
                          ? Colors.white70
                          : Colors.grey.shade500,
                      size: 20,
                    ),
                    onPressed: () {
                      controller.clear();
                      _searchClinics('');
                    },
                  )
                      : null,
                ),
                style: TextStyle(
                  fontSize: 14,
                  color: isDarkMode ? AppColors.darkText : AppColors.lightText,
                ),
                onChanged: _searchClinics,
              ),
            ),
          ),

          // Results Counter - Made more compact
          if (_filteredClinics.isNotEmpty && !_isLoading && _errorMessage == null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  Text(
                    '${_filteredClinics.length} ${_filteredClinics.length == 1 ? 'clinic' : 'clinics'} found',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDarkMode
                          ? AppColors.darkSubtext
                          : Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

          // Results List
          Expanded(child: _buildResultsList(isDarkMode)),
        ],
      ),
    );
  }

  Widget _buildResultsList(bool isDarkMode) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(colors().bluecolor1),
            ),
            const SizedBox(height: 12),
            Text(
              'Loading clinics...',
              style: TextStyle(
                color: isDarkMode
                    ? AppColors.darkSubtext
                    : Colors.grey.shade600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.wifi_off,
              size: 48,
              color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade500,
            ),
            const SizedBox(height: 16),
            Text(
              'Unable to load clinics',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: isDarkMode ? AppColors.darkText : Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please check your connection and try again',
              style: TextStyle(
                fontSize: 14,
                color: isDarkMode ? AppColors.darkSubtext : Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadClinics,
              style: ElevatedButton.styleFrom(
                backgroundColor: colors().bluecolor1,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Try Again'),
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
              size: 48,
              color: isDarkMode ? Colors.grey.shade600 : Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              controller.text.isEmpty
                  ? 'No clinics available'
                  : 'No results found for "${controller.text}"',
              style: TextStyle(
                color: isDarkMode ? AppColors.darkText : Colors.grey.shade600,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Try different keywords or check your spelling',
              style: TextStyle(
                color: isDarkMode
                    ? AppColors.darkSubtext
                    : Colors.grey.shade500,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
            if (controller.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: ElevatedButton(
                  onPressed: () {
                    controller.clear();
                    _searchClinics('');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors().bluecolor1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                  ),
                  child: const Text(
                    'Clear Search',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      itemCount: _filteredClinics.length,
      itemBuilder: (context, index) {
        final clinic = _filteredClinics[index];
        return _buildClinicListItem(clinic, isDarkMode);
      },
    );
  }

  Widget _buildClinicListItem(Map<String, dynamic> clinic, bool isDarkMode) {
    final isOpen = clinic['isOpen'] ?? false;
    final clinicName = clinic['name'] ?? 'Unknown Clinic';
    final clinicAddress = clinic['address'] ?? 'No address provided';
    final services = (clinic['services'] as List<dynamic>?)?.join(', ') ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.1 : 0.06),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => HospitalInform(clinic: clinic),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Clinic Icon - Made smaller
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colors().bluecolor1.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.medical_services,
                    color: colors().bluecolor1,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),

                // Clinic Info - Made more compact
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        clinicName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode
                              ? AppColors.darkText
                              : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        clinicAddress,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDarkMode
                              ? AppColors.darkSubtext
                              : Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (services.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          services,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDarkMode
                                ? AppColors.darkSubtext
                                : Colors.grey.shade500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Status Badge - Made smaller
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isOpen
                        ? Colors.green.withOpacity(0.1)
                        : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isOpen ? Colors.green : Colors.red,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    isOpen ? 'OPEN' : 'CLOSED',
                    style: TextStyle(
                      color: isOpen ? Colors.green : Colors.red,
                      fontSize: 10,
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
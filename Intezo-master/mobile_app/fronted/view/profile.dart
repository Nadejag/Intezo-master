
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qatar_app/fronted/res/components/wigets/profile/profile_buttons.dart';
import 'package:qatar_app/providers/patient_provider.dart';
import '../../providers/theme_provider.dart';
import './booking_history_screen.dart';

import '../res/components/wigets/aboutscreen.dart';
import '../res/components/wigets/colors.dart';
import '../res/components/wigets/profile/logout.dart';
import '../res/components/wigets/profile/profilebatch1.dart';

class Profile extends StatefulWidget {
const Profile({super.key});

@override
State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
@override
void initState() {
super.initState();
// Load patient data when profile screen opens
WidgetsBinding.instance.addPostFrameCallback((_) {
Provider.of<PatientProvider>(context, listen: false).loadPatientProfile();
});
}

@override
Widget build(BuildContext context) {
final themeProvider = Provider.of<ThemeProvider>(context);
final isDarkMode = themeProvider.isDarkMode;
final width = MediaQuery.sizeOf(context).width;
final patientProvider = Provider.of<PatientProvider>(context);
final patientData = patientProvider.patientData;

return Scaffold(
backgroundColor: isDarkMode ? AppColors.darkBackground : AppColors.lightBackground,
appBar: AppBar(
title: const Text("Profile", style: TextStyle(fontWeight: FontWeight.w600)),
backgroundColor: isDarkMode ? AppColors.darkCard : Colors.white,
elevation: 0,
actions: [
IconButton(
onPressed: () {
Provider.of<PatientProvider>(context, listen: false).loadPatientProfile();
},
icon: Icon(Icons.refresh, color: isDarkMode ? Colors.white70 : Colors.black54),
),
IconButton(
onPressed: () {
Navigator.push(context, MaterialPageRoute(builder: (context) => Logoutoptions()));
},
icon: Icon(Icons.login_outlined, color: isDarkMode ? Colors.white70 : Colors.black54),
)
],
),
body: patientProvider.isLoading
? const Center(child: CircularProgressIndicator())
    : patientProvider.error != null
? Center(
child: Column(
mainAxisAlignment: MainAxisAlignment.center,
children: [
Icon(Icons.refresh, size: 64, color: Colors.blue.shade400),
const SizedBox(height: 16),
Text('Unable to load data', style: TextStyle(fontSize: 16)),
const SizedBox(height: 20),
ElevatedButton(
onPressed: () => Provider.of<PatientProvider>(context, listen: false).loadPatientProfile(),
child: const Text('Reload'),
),
],
),
)
    : patientData == null
? const Center(child: Text('No patient data found'))
    : SingleChildScrollView(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
// User info section
Container(
width: double.infinity,
padding: const EdgeInsets.all(20),
color: isDarkMode ? AppColors.darkCard : Colors.white,
child: Column(
crossAxisAlignment: CrossAxisAlignment.center,
children: [
Container(
width: 80,
height: 80,
decoration: BoxDecoration(
shape: BoxShape.circle,
color: colors().bluecolor1.withOpacity(0.2),
),
child: Icon(
Icons.person,
size: 40,
color: colors().bluecolor1,
),
),
const SizedBox(height: 16),
Text(
patientData['name'] ?? 'No Name',
style: TextStyle(
fontSize: 20,
fontWeight: FontWeight.bold,
color: isDarkMode ? AppColors.darkText : AppColors.lightText,
),
),
const SizedBox(height: 8),
Text(
patientData['phone'] ?? 'No Phone',
style: TextStyle(
fontSize: 16,
color: isDarkMode ? AppColors.darkSubtext : AppColors.lightSubtext,
),
),
],
),
),
const SizedBox(height: 16),

// Divider line
Container(
height: 8,
color: isDarkMode ? AppColors.darkDivider : Colors.grey.shade200,
),

// Menu items section
Container(
width: double.infinity,
color: isDarkMode ? AppColors.darkCard : Colors.white,
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
_buildMenuItem(
icon: Icons.history,
title: "History",
isDarkMode: isDarkMode,
onTap: () {
Navigator.push(context, MaterialPageRoute(builder: (context) => const BookingHistoryScreen()));
},
),
_buildDivider(isDarkMode),
_buildMenuItem(
icon: Icons.support_agent,
title: "Support",
isDarkMode: isDarkMode,
),
_buildDivider(isDarkMode),
_buildThemeToggle(themeProvider, isDarkMode),
_buildDivider(isDarkMode),
_buildMenuItem(
icon: Icons.settings,
title: "Settings",
isDarkMode: isDarkMode,
),
_buildDivider(isDarkMode),
_buildMenuItem(
icon: Icons.info_outline,
title: "Information",
isDarkMode: isDarkMode,
onTap: () {
Navigator.push(context, MaterialPageRoute(builder: (context) => AboutScreen()));
},
),
],
),
),
const SizedBox(height: 20),
],
),
),
);
}

Widget _buildMenuItem({required IconData icon, required String title, required bool isDarkMode, VoidCallback? onTap}) {
return InkWell(
onTap: onTap,
child: Container(
padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
child: Row(
children: [
Icon(icon, size: 22, color: isDarkMode ? Colors.white70 : Colors.grey.shade700),
const SizedBox(width: 16),
Text(
title,
style: TextStyle(
fontSize: 16,
color: isDarkMode ? AppColors.darkText : AppColors.lightText,
),
),
const Spacer(),
Icon(Icons.arrow_forward_ios, size: 16, color: isDarkMode ? Colors.white54 : Colors.grey.shade500),
],
),
),
);
}

Widget _buildThemeToggle(ThemeProvider themeProvider, bool isDarkMode) {
return Container(
padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
child: Row(
children: [
Icon(
themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
size: 22,
color: isDarkMode ? Colors.white70 : Colors.grey.shade700,
),
const SizedBox(width: 16),
Text(
"Dark Mode",
style: TextStyle(
fontSize: 16,
color: isDarkMode ? AppColors.darkText : AppColors.lightText,
),
),
const Spacer(),
Switch(
value: themeProvider.isDarkMode,
onChanged: (value) => themeProvider.toggleTheme(),
),
],
),
);
}

Widget _buildDivider(bool isDarkMode) {
return Padding(
padding: const EdgeInsets.only(left: 58, right: 20),
child: Divider(
height: 1,
color: isDarkMode ? AppColors.darkDivider : Colors.grey.shade200
),
);
}
}
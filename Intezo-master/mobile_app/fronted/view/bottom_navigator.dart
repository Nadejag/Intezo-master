// // lib/fronted/view/bottom_navigator.dart - Updated
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../res/components/wigets/colors.dart';
// import 'homescreen.dart';
// import 'profile.dart';
// import 'status.dart';
//
// class BottomNav extends StatefulWidget {
//   const BottomNav({super.key});
//
//   @override
//   _BottomNavState createState() => _BottomNavState();
// }
//
// class _BottomNavState extends State<BottomNav> {
//   int _selectedIndex = 0;
//
//   static final List<Widget> _widgetOptions = <Widget>[
//     const Homescreen(),
//     const Status(),
//     const Profile(),
//   ];
//
//   void _onItemTapped(int index) {
//     setState(() {
//       _selectedIndex = index;
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: _widgetOptions.elementAt(_selectedIndex),
//       bottomNavigationBar: Container(
//         decoration: BoxDecoration(
//           boxShadow: [
//             BoxShadow(
//               color: Colors.grey.withOpacity(0.3),
//               blurRadius: 10,
//               offset: const Offset(0, -2),
//             ),
//           ],
//         ),
//         child: BottomNavigationBar(
//           backgroundColor: Colors.white,
//           currentIndex: _selectedIndex,
//           onTap: _onItemTapped,
//           selectedItemColor: colors().bluecolor1,
//           unselectedItemColor: Colors.grey.shade600,
//           selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
//           type: BottomNavigationBarType.fixed,
//           items: const [
//             BottomNavigationBarItem(
//               icon: Icon(Icons.home_outlined),
//               activeIcon: Icon(Icons.home),
//               label: 'Home',
//             ),
//             BottomNavigationBarItem(
//               icon: Icon(Icons.access_time_outlined),
//               activeIcon: Icon(Icons.access_time),
//               label: 'Status',
//             ),
//             BottomNavigationBarItem(
//               icon: Icon(Icons.person_outlined),
//               activeIcon: Icon(Icons.person),
//               label: 'Profile',
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }


// lib/fronted/view/bottom_navigator.dart
import 'package:flutter/material.dart';
import 'package:convex_bottom_bar/convex_bottom_bar.dart';
import '../res/components/wigets/colors.dart';
import 'homescreen.dart';
import 'profile.dart';
import 'status.dart';

class BottomNav extends StatefulWidget {
  const BottomNav({super.key});

  @override
  _BottomNavState createState() => _BottomNavState();
}

class _BottomNavState extends State<BottomNav> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    Homescreen(),
    Status(),
    Profile(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],

      // ✅ Modern Bottom Navigation
      bottomNavigationBar: ConvexAppBar(
        style: TabStyle.react, // animation style
        backgroundColor: Colors.deepPurple, // professional background
        activeColor: Colors.white,
        color: Colors.white70,
        curveSize: 100, // bigger curve for center button
        height: 65,
        items: const [
          TabItem(icon: Icons.home, title: 'Home'),
          TabItem(icon: Icons.favorite, title: 'Favorite'),
          TabItem(icon: Icons.settings, title: 'Settings'),
        ],
        initialActiveIndex: _selectedIndex,
        onTap: (int index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
    );
  }
}

// import 'package:flutter/cupertino.dart';
// import 'package:flutter/material.dart';
// import 'package:qatar_app/fronted/res/components/wigets/profile/profile_buttons.dart';
//
// import '../res/components/wigets/aboutscreen.dart';
// import '../res/components/wigets/colors.dart';
// import '../res/components/wigets/profile/logout.dart';
// import '../res/components/wigets/profile/profilebatch1.dart';
//
// class Profile extends StatefulWidget {
//   const Profile({super.key});
//
//   @override
//   State<Profile> createState() => _ProfileState();
// }
//
// class _ProfileState extends State<Profile> {
//   @override
//   Widget build(BuildContext context) {
//     final width = MediaQuery.sizeOf(context).width * 1;
//     final height = MediaQuery.sizeOf(context).width * 1;
//     return Scaffold(
//       backgroundColor: colors.bgColor,
//       appBar: AppBar(
//         title: Text("Profile"),
//         backgroundColor: Colors.white,
//         actions: [
//           IconButton(onPressed: (){
//             Navigator.push(context, MaterialPageRoute(builder: (context)=>Logoutoptions()));
//           },
//               icon: Icon(Icons.login_outlined))
//         ],
//       ),
//       body: Column(
//         crossAxisAlignment: CrossAxisAlignment.center,
//         children: [
//                     Profile_batch1(height: height, width: width),
//                    SizedBox(height: height * 0.15,),
//
//                  Align(
//                      alignment: Alignment.topLeft,
//                      child: Padding(
//                        padding: const EdgeInsets.only(left: 18,bottom: 10),
//                        child: Text("General Settings"),
//                      )),
//                 Container(
//                   width: width ,
//                   height:  height * 0.55,
//                   decoration: BoxDecoration(
//                     color: Colors.white
//                   ),
//                   child: Column(
//                     children: [
//                       ProfileButton(title: 'App Settings', subtitle: 'Language,Theme,Security,Backup', icons: Icons.app_settings_alt,),
//                       Padding(
//                         padding: const EdgeInsets.only(left: 60,right: 30),
//                         child: Divider(color: Colors.black87.withOpacity(0.1),height: 4,),
//                       ),
//                       ProfileButton(title: 'Your Profile', subtitle: 'Name,Mobile Number,Email', icons: Icons.person_pin,),
//                       Padding(
//                         padding: const EdgeInsets.only(left: 60,right: 30),
//                         child: Divider(color: Colors.black87.withOpacity(0.1),height: 4,),
//                       ),
//                       InkWell(
//                           onTap: (){
//                             Navigator.push(context, MaterialPageRoute(builder: (context)=> AboutScreen()));
//                           },
//                           child: ProfileButton(title: 'About ', subtitle: 'About us', icons: Icons.info_outline,))
//                     ],
//                   ),
//                 )
//         ],
//       ),
//     );
//   }
// }
//
//
// lib/fronted/view/profile.dart
// lib/fronted/view/profile.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qatar_app/fronted/res/components/wigets/profile/profile_buttons.dart';
import 'package:qatar_app/providers/patient_provider.dart';

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
    final width = MediaQuery.sizeOf(context).width * 1;
    final height = MediaQuery.sizeOf(context).width * 1;
    final patientProvider = Provider.of<PatientProvider>(context);
    final patientData = patientProvider.patientData;

    return Scaffold(
      backgroundColor: colors.bgColor,
      appBar: AppBar(
        title: Text("Profile"),
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () {
              Provider.of<PatientProvider>(context, listen: false).loadPatientProfile();
            },
            icon: Icon(Icons.refresh),
          ),
          IconButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => Logoutoptions()));
              },
              icon: Icon(Icons.login_outlined)
          )
        ],
      ),
      body: patientProvider.isLoading
          ? Center(child: CircularProgressIndicator())
          : patientProvider.error != null
          ? Center(child: Text('Error: ${patientProvider.error}'))
          : patientData == null
          ? Center(child: Text('No patient data found'))
          : Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Profile_batch1(
            height: height,
            width: width,
            patientName: patientData['name'] ?? 'No Name',
            patientPhone: patientData['phone'] ?? 'No Phone',
          ),
          SizedBox(height: height * 0.15),
          Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 18,bottom: 10),
                child: Text("General Settings", style: TextStyle(fontWeight: FontWeight.bold)),
              )),
          Container(
            width: width,
            height: height * 0.55,
            decoration: BoxDecoration(
                color: Colors.white
            ),
            child: Column(
              children: [
                ProfileButton(
                  title: 'App Settings',
                  subtitle: 'Language, Theme, Security, Backup',
                  icons: Icons.app_settings_alt,
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 60,right: 30),
                  child: Divider(color: Colors.black87.withOpacity(0.1),height: 4,),
                ),
                ProfileButton(
                  title: 'Your Profile',
                  subtitle: 'Name: ${patientData['name']}, Phone: ${patientData['phone']}',
                  icons: Icons.person_pin,
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 60,right: 30),
                  child: Divider(color: Colors.black87.withOpacity(0.1),height: 4,),
                ),
                InkWell(
                    onTap: (){
                      Navigator.push(context, MaterialPageRoute(builder: (context)=> AboutScreen()));
                    },
                    child: ProfileButton(
                      title: 'About',
                      subtitle: 'About us',
                      icons: Icons.info_outline,
                    )
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
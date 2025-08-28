import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkService {
  static Future<bool> isConnected() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      final hasConnection = connectivityResult.contains(ConnectivityResult.mobile) || 
                           connectivityResult.contains(ConnectivityResult.wifi);
      print('NetworkService: Connectivity result: $connectivityResult, hasConnection: $hasConnection');
      return hasConnection;
    } catch (e) {
      print('NetworkService: Error checking connectivity: $e');
      return false;
    }
  }
}
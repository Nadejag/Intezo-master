// lib/main.dart - Using pusher_channels_flutter
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';
import 'package:qatar_app/services/event_bus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'fronted/view/bottom_navigator.dart';
import 'fronted/view/homescreen.dart';
import 'fronted/view/auth/login_screen.dart';
import 'providers/auth_provider.dart';
import 'providers/clinic_provider.dart';
import 'providers/patient_provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ClinicProvider()),
        ChangeNotifierProvider(create: (_) => PatientProvider())
      ],
      child: MaterialApp(
        title: 'Queue App',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: const AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      authProvider.checkLoginStatus();
    });

    if (authProvider.isLoggedIn) {
      return const BottomNav();
    } else {
      return const LoginScreen();
    }
  }
}

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  PusherChannelsFlutter? _pusher;
  bool isConnected = false;
  String? _currentClinicId;
  String? _currentChannelName;
  Function(String)? _onFallbackToPolling; // Callback for fallback

  // Set fallback callback
  void setFallbackCallback(Function(String) callback) {
    _onFallbackToPolling = callback;
  }

// In SocketService - Update the connect method
  Future<void> connect({String? clinicId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      // Disconnect existing connection if any
      if (isConnected) {
        await disconnect();
      }

      // Initialize Pusher
      _pusher = PusherChannelsFlutter.getInstance();

      await _pusher!.init(
        apiKey: 'a305330e07bceb77cbb7',
        cluster: 'ap2',
        onConnectionStateChange: (String state, dynamic data) {
          print('Pusher connection state: $state');
          isConnected = state == 'connected';

          if (isConnected && clinicId != null) {
            joinClinicChannel(clinicId);
          } else if (state == 'disconnected' || state == 'failed') {
            // Auto-reconnect on failure
            Future.delayed(Duration(seconds: 3), () => connect(clinicId: clinicId));
          }
        },
        onError: (String message, int? code, dynamic error) {
          print('Pusher error: $message, code: $code');
          isConnected = false;

          // Fallback to polling if Pusher fails
          if (clinicId != null && _onFallbackToPolling != null) {
            _onFallbackToPolling!(clinicId);
          }

          // Auto-reconnect
          Future.delayed(Duration(seconds: 5), () => connect(clinicId: clinicId));
        },
        onEvent: (event) {
          print('Pusher event: ${event.eventName} - ${event.data}');

          // Handle queue updates
          if (event.eventName == 'queue-update' && event.data != null) {
            try {
              final data = json.decode(event.data!);
              print('Queue update received: $data');

              // Emit event to EventBus
              EventBus().emitQueueUpdate(QueueUpdateEvent(
                clinicId: _currentClinicId!,
                queueData: data,
              ));
            } catch (e) {
              print('Error parsing queue update: $e');
            }
          }
        },
        onAuthorizer: (String channelName, String socketId, dynamic options) async {
          try {
            final response = await http.post(
              Uri.parse('http://192.168.100.69:3000/pusher/auth'),
              headers: {
                'Content-Type': 'application/x-www-form-urlencoded',
                'Authorization': 'Bearer $token',
              },
              body: {
                'socket_id': socketId,
                'channel_name': channelName,
              },
            );

            if (response.statusCode == 200) {
              return json.decode(response.body);
            } else {
              print('Pusher auth failed: ${response.statusCode} - ${response.body}');
              throw Exception('Auth failed: ${response.statusCode}');
            }
          } catch (e) {
            print('Pusher auth error: $e');
            throw e;
          }
        },
      );

      // Connect to Pusher
      await _pusher!.connect();
      print('Pusher connection initiated');

    } catch (e) {
      print('Pusher connection error: $e');
      // Retry connection after delay
      Future.delayed(Duration(seconds: 5), () => connect(clinicId: clinicId));
    }
  }

// In joinClinicChannel method - Replace with this:
  Future<void> joinClinicChannel(String clinicId) async {
    if (_pusher != null && isConnected) {
      try {
        // Use public channel for patients (no auth required)
        final channelName = 'public-clinic-$clinicId';

        print('Attempting to subscribe to channel: $channelName');

        // Subscribe to channel
        final channel = await _pusher!.subscribe(
          channelName: channelName,
          onEvent: (event) {
            print('Pusher event received: ${event.eventName} - ${event.data}');

            if (event.eventName == 'queue-update' && event.data != null) {
              try {
                final data = json.decode(event.data!);
                print('Queue update received via Pusher: $data');

                // Emit event to EventBus
                EventBus().emitQueueUpdate(QueueUpdateEvent(
                  clinicId: clinicId,
                  queueData: data,
                ));
              } catch (e) {
                print('Error parsing queue update: $e');
              }
            }
          },
        );

        _currentChannelName = channelName;
        _currentClinicId = clinicId;
        print('Successfully subscribed to channel: $channelName');

      } catch (e) {
        print('Error subscribing to channel: $e');
        // Trigger fallback to polling
        if (_onFallbackToPolling != null) {
          _onFallbackToPolling!(clinicId);
        }
      }
    } else {
      print('Pusher not connected, cannot subscribe to channel');
      if (_onFallbackToPolling != null) {
        _onFallbackToPolling!(clinicId);
      }
    }
  }


  void _handleQueueUpdate(Map<String, dynamic> data) {
    try {
      final clinicId = _currentClinicId;
      if (clinicId != null) {
        EventBus().emitQueueUpdate(QueueUpdateEvent(
          clinicId: clinicId,
          queueData: data,
        ));
      }
    } catch (e) {
      print('Error handling queue update: $e');
    }
  }

  Future<void> disconnect() async {
    if (_currentChannelName != null) {
      await _pusher!.unsubscribe(channelName: _currentChannelName!);
      _currentChannelName = null;
    }
    if (_pusher != null) {
      await _pusher!.disconnect();
    }
    isConnected = false;
    _currentClinicId = null;
  }
}
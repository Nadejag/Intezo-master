// lib/main.dart - Updated for doctor-specific queues
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
import 'providers/theme_provider.dart';
import 'providers/offline_provider.dart';

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
        ChangeNotifierProvider(create: (_) => PatientProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => OfflineProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'Queue App',
            debugShowCheckedModeBanner: false,
            theme: themeProvider.themeData,
            home: const AuthWrapper(),
          );
        },
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
  static SocketService? _instance;
  static SocketService get instance {
    _instance ??= SocketService._internal();
    return _instance!;
  }
  SocketService._internal();

  PusherChannelsFlutter? _pusher;
  bool isConnected = false;
  bool _isInitialized = false;
  String? _currentClinicId;
  String? _currentChannelName;
  Function(String, String?)? _onFallbackToPolling;

  void setFallbackCallback(Function(String, String?) callback) {
    _onFallbackToPolling = callback;
  }

  Future<void> connect({String? clinicId, String? doctorId}) async {
    print('SocketService.connect called for clinic: $clinicId');
    
    if (_isInitialized && isConnected) {
      print('Already connected, just switching channel');
      if (clinicId != null) {
        await joinClinicChannel(clinicId, doctorId: doctorId);
      }
      return;
    }

    if (_isInitialized) {
      print('Already initializing, skipping');
      return;
    }
    
    print('Initializing new Pusher connection');
    _isInitialized = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      _pusher = PusherChannelsFlutter.getInstance();

      await _pusher!.init(
        apiKey: 'a305330e07bceb77cbb7',
        cluster: 'ap2',
        onConnectionStateChange: (String state, dynamic data) {
          print('Pusher connection state: $state');
          isConnected = state.toLowerCase() == 'connected';
          print('isConnected set to: $isConnected');

          if (isConnected && clinicId != null) {
            print('Pusher connected, subscribing to channel for clinic: $clinicId');
            Future.delayed(Duration(milliseconds: 500), () {
              joinClinicChannel(clinicId, doctorId: doctorId);
            });
          }
        },
        onError: (String message, int? code, dynamic error) {
          print('Pusher error: $message, code: $code');
          isConnected = false;
          if (clinicId != null && _onFallbackToPolling != null) {
            _onFallbackToPolling!(clinicId, doctorId);
          }
        },
        onEvent: (event) {
          print('🔥 GLOBAL EVENT: ${event.eventName} on ${event.channelName}');
          print('🔥 EVENT DATA: ${event.data}');
          _handlePusherEvent(event);
        },
      );

      await _pusher!.connect();
      print('Pusher connection initiated');

    } catch (e) {
      print('Pusher connection error: $e');
      _isInitialized = false;
    }
  }

  void _handlePusherEvent(dynamic event) {
    print('Processing Pusher event: ${event.eventName} for clinic: $_currentClinicId');
    
    // Log ALL events for debugging
    print('🔥 PROCESSING EVENT: ${event.eventName}');
    
    // Handle real-time events
    if (event.data != null && event.data!.isNotEmpty && event.data != '{}') {
      try {
        final data = json.decode(event.data!);
        print('🔥 REAL EVENT DATA: $data');
        
        // Handle different event types
        if (event.eventName == 'queue-update') {
          EventBus().emitQueueUpdate(QueueUpdateEvent(
            clinicId: _currentClinicId!,
            doctorId: null,
            queueData: data,
          ));
        } else if (event.eventName == 'clinic-status-update') {
          EventBus().emitClinicStatusUpdate(ClinicStatusUpdateEvent(
            clinicId: _currentClinicId!,
            statusData: data,
          ));
        } else {
          // Default to queue update for any other event with data
          EventBus().emitQueueUpdate(QueueUpdateEvent(
            clinicId: _currentClinicId!,
            doctorId: null,
            queueData: data,
          ));
        }
        print('🔥 EVENT EMITTED TO UI!');
      } catch (e) {
        print('Error parsing event data: $e');
      }
    } else {
      print('🔥 EMPTY OR SYSTEM EVENT: ${event.eventName}');
    }
  }

  Future<void> joinClinicChannel(String clinicId, {String? doctorId}) async {
    if (_pusher == null) {
      print('Pusher not initialized, using polling');
      if (_onFallbackToPolling != null) {
        _onFallbackToPolling!(clinicId, doctorId);
      }
      return;
    }

    try {
      // Use doctor-specific public channel
      final channelName = doctorId != null 
          ? 'public-doctor-$doctorId'
          : 'public-clinic-$clinicId';
      
      if (_currentChannelName == channelName) {
        print('Already subscribed to channel: $channelName');
        return;
      }
      
      if (_currentChannelName != null) {
        await _pusher!.unsubscribe(channelName: _currentChannelName!);
      }

      print('Attempting to subscribe to channel: $channelName');
      await _pusher!.subscribe(
        channelName: channelName,
        onEvent: (event) {
          print('🔥 CHANNEL EVENT: ${event.eventName} on $channelName');
          print('🔥 CHANNEL DATA: ${event.data}');
          _handlePusherEvent(event);
        },
      );
      
      _currentChannelName = channelName;
      _currentClinicId = clinicId;
      print('Successfully subscribed to channel: $channelName');

    } catch (e) {
      print('Error subscribing to channel: $e');
      if (_onFallbackToPolling != null) {
        _onFallbackToPolling!(clinicId, doctorId);
      }
    }
  }

  Future<void> disconnect() async {
    if (_currentChannelName != null && _pusher != null) {
      await _pusher!.unsubscribe(channelName: _currentChannelName!);
    }
    _currentChannelName = null;
    _currentClinicId = null;
    isConnected = false;
  }

  bool get isActive {
    final active = isConnected && _currentChannelName != null;
    print('Pusher isActive check: connected=$isConnected, channel=$_currentChannelName, active=$active');
    return active;
  }
}
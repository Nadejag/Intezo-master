// lib/services/event_bus.dart
import 'dart:async';
import 'package:flutter/foundation.dart';

class QueueUpdateEvent {
  final String clinicId;
  final Map<String, dynamic> queueData;

  QueueUpdateEvent({required this.clinicId, required this.queueData});
}

class ClinicStatusUpdateEvent {
  final String clinicId;
  final Map<String, dynamic> statusData;

  ClinicStatusUpdateEvent({required this.clinicId, required this.statusData});
}

class EventBus {
  static final EventBus _instance = EventBus._internal();
  factory EventBus() => _instance;
  EventBus._internal();

  final _queueUpdateController = StreamController<QueueUpdateEvent>.broadcast();
  final _clinicStatusController = StreamController<ClinicStatusUpdateEvent>.broadcast();

  Stream<QueueUpdateEvent> get onQueueUpdate => _queueUpdateController.stream;
  Stream<ClinicStatusUpdateEvent> get onClinicStatusUpdate => _clinicStatusController.stream;

  void emitQueueUpdate(QueueUpdateEvent event) {
    _queueUpdateController.add(event);
  }

  void emitClinicStatusUpdate(ClinicStatusUpdateEvent event) {
    _clinicStatusController.add(event);
  }

  void dispose() {
    _queueUpdateController.close();
    _clinicStatusController.close();
  }
}
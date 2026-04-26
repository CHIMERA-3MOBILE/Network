import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NetworkService {
  static const String _serviceId = 'com.chimera.network_app';
  static const String _deviceName = 'FileManager';
  
  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;
  NetworkService._internal();

  bool _isAdvertising = false;
  bool _isDiscovering = false;
  List<String> _connectedDevices = [];
  Map<String, String> _deviceEndpoints = {};
  StreamSubscription? _connectionSubscription;
  StreamSubscription? _payloadSubscription;

  final StreamController<Map<String, dynamic>> _messageController = 
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;

  final StreamController<List<String>> _deviceListController = 
      StreamController<List<String>>.broadcast();
  Stream<List<String>> get deviceListStream => _deviceListController.stream;

  List<String> get connectedDevices => List.unmodifiable(_connectedDevices);

  Future<void> initialize() async {
    await _requestPermissions();
    await _setupBackgroundService();
    _setupEventListeners();
  }

  Future<void> _requestPermissions() async {
    final permissions = [
      Permission.location,
      Permission.bluetoothScan,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.nearbyWifiDevices,
      Permission.notification,
    ];

    for (final permission in permissions) {
      final status = await permission.request();
      if (status.isDenied) {
        print('Permission denied: ${permission.toString()}');
      }
    }
  }

  Future<void> _setupBackgroundService() async {
    final service = FlutterBackgroundService();
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        isForegroundMode: true,
        autoStart: true,
        notificationChannelId: 'network_app_channel',
        initialNotificationTitle: 'File Manager',
        initialNotificationContent: 'Network service active',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
    service.startService();
  }

  void _setupEventListeners() {
    _connectionSubscription = Nearby().connectionEvents.listen((event) {
      if (event.type == ConnectionEventType.connected) {
        _handleConnection(event.deviceId, event.info);
      } else if (event.type == ConnectionEventType.disconnected) {
        _handleDisconnection(event.deviceId);
      }
    });

    _payloadSubscription = Nearby().payloadEvents.listen((event) {
      if (event.type == PayloadType.bytes) {
        _handleMessage(event.deviceId, event.bytes!);
      }
    });
  }

  Future<void> startAdvertising() async {
    if (_isAdvertising) return;

    try {
      await Nearby().startAdvertising(
        _deviceName,
        Strategy.P2P_CLUSTER,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: (deviceId, status) {
          if (status == Status.connected) {
            print('Connected to: $deviceId');
          }
        },
        onDisconnected: (deviceId) {
          print('Disconnected from: $deviceId');
          _handleDisconnection(deviceId);
        },
        serviceId: _serviceId,
      );
      _isAdvertising = true;
      print('Started advertising');
    } catch (e) {
      print('Error starting advertising: $e');
    }
  }

  Future<void> startDiscovery() async {
    if (_isDiscovering) return;

    try {
      await Nearby().startDiscovery(
        _serviceId,
        Strategy.P2P_CLUSTER,
        onEndpointFound: (deviceId, displayName, serviceId) {
          print('Found device: $deviceId ($displayName)');
          _requestConnection(deviceId);
        },
        onEndpointLost: (deviceId) {
          print('Lost endpoint: $deviceId');
        },
      );
      _isDiscovering = true;
      print('Started discovery');
    } catch (e) {
      print('Error starting discovery: $e');
    }
  }

  Future<void> _requestConnection(String deviceId) async {
    try {
      await Nearby().requestConnection(
        _deviceName,
        deviceId,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: (deviceId, status) {
          if (status == Status.connected) {
            print('Successfully connected to: $deviceId');
          }
        },
        onDisconnected: (deviceId) {
          print('Disconnected from: $deviceId');
          _handleDisconnection(deviceId);
        },
      );
    } catch (e) {
      print('Error requesting connection: $e');
    }
  }

  void _onConnectionInitiated(String deviceId, ConnectionInfo info) {
    print('Connection initiated with: $deviceId');
    Nearby().acceptConnection(
      deviceId,
      onPayloadReceived: (payload) {
        if (payload is Uint8List) {
          _handleMessage(deviceId, payload);
        }
      },
      onPayloadTransferUpdate: (update) {
        // Handle transfer progress if needed
      },
    );
  }

  void _handleConnection(String deviceId, ConnectionInfo info) {
    if (!_connectedDevices.contains(deviceId)) {
      _connectedDevices.add(deviceId);
      _deviceEndpoints[deviceId] = info.endpointName;
      _deviceListController.add(List.from(_connectedDevices));
      print('Connected to device: $deviceId (${info.endpointName})');
    }
  }

  void _handleDisconnection(String deviceId) {
    _connectedDevices.remove(deviceId);
    _deviceEndpoints.remove(deviceId);
    _deviceListController.add(List.from(_connectedDevices));
    print('Disconnected from device: $deviceId');
  }

  void _handleMessage(String deviceId, Uint8List data) {
    try {
      final message = json.decode(String.fromCharCodes(data));
      final enrichedMessage = {
        ...message,
        'senderId': deviceId,
        'senderName': _deviceEndpoints[deviceId] ?? 'Unknown',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      _messageController.add(enrichedMessage);
      
      // Route message if needed (for mesh networking)
      _routeMessage(enrichedMessage, deviceId);
    } catch (e) {
      print('Error handling message: $e');
    }
  }

  Future<void> sendMessage(String content, {String? targetDeviceId}) async {
    final message = {
      'type': 'message',
      'content': content,
      'senderId': Platform.isAndroid ? await _getDeviceId() : 'unknown',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'ttl': 3, // Time to live for mesh routing
    };

    final messageData = Uint8List.fromList(json.encode(message).codeUnits);

    if (targetDeviceId != null) {
      // Send to specific device
      if (_connectedDevices.contains(targetDeviceId)) {
        await Nearby().sendBytesPayload(targetDeviceId, messageData);
      }
    } else {
      // Broadcast to all connected devices
      for (final deviceId in _connectedDevices) {
        await Nearby().sendBytesPayload(deviceId, messageData);
      }
    }
  }

  void _routeMessage(Map<String, dynamic> message, String senderId) {
    final ttl = message['ttl'] as int? ?? 0;
    if (ttl <= 0) return;

    // Create message with decreased TTL for forwarding
    final forwardedMessage = Map<String, dynamic>.from(message);
    forwardedMessage['ttl'] = ttl - 1;

    // Forward to all connected devices except the sender
    for (final deviceId in _connectedDevices) {
      if (deviceId != senderId) {
        final messageData = Uint8List.fromList(json.encode(forwardedMessage).codeUnits);
        Nearby().sendBytesPayload(deviceId, messageData);
      }
    }
  }

  Future<String> _getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString('device_id');
    if (deviceId == null) {
      deviceId = 'device_${DateTime.now().millisecondsSinceEpoch}';
      await prefs.setString('device_id', deviceId);
    }
    return deviceId;
  }

  Future<void> stopAll() async {
    try {
      if (_isAdvertising) {
        await Nearby().stopAdvertising();
        _isAdvertising = false;
      }
      if (_isDiscovering) {
        await Nearby().stopDiscovery();
        _isDiscovering = false;
      }
      await _connectionSubscription?.cancel();
      await _payloadSubscription?.cancel();
    } catch (e) {
      print('Error stopping services: $e');
    }
  }

  void dispose() {
    _messageController.close();
    _deviceListController.close();
    stopAll();
  }
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  if (service is AndroidServiceInstance) {
    service.on('stopService').listen((event) {
      service.stopSelf();
    });
  }
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}

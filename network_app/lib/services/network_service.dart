import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'logger_service.dart';
import 'settings_service.dart';

class NetworkService {
  static const String _serviceId = 'com.chimera.network_app';
  static const String _defaultDeviceName = 'FileManager';
  
  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;
  NetworkService._internal();

  final LoggerService _logger = LoggerService();
  final SettingsService _settingsService = SettingsService();
  
  bool _isAdvertising = false;
  bool _isDiscovering = false;
  List<String> _connectedDevices = [];
  Map<String, String> _deviceEndpoints = {};
  Map<String, DateTime> _lastSeen = {};
  StreamSubscription? _connectionSubscription;
  StreamSubscription? _payloadSubscription;
  Timer? _cleanupTimer;
  Timer? _reconnectTimer;

  final StreamController<Map<String, dynamic>> _messageController = 
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;

  final StreamController<List<String>> _deviceListController = 
      StreamController<List<String>>.broadcast();
  Stream<List<String>> get deviceListStream => _deviceListController.stream;

  List<String> get connectedDevices => List.unmodifiable(_connectedDevices);

  Future<void> initialize() async {
    try {
      await _requestPermissions();
      await _setupBackgroundService();
      _setupEventListeners();
      _startCleanupTimer();
      _logger.info('NetworkService initialized successfully');
    } catch (e) {
      _logger.error('Failed to initialize NetworkService', error: e);
      rethrow;
    }
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
      try {
        final status = await permission.request();
        if (status.isGranted) {
          _logger.info('Permission granted: ${permission.toString()}');
        } else if (status.isDenied) {
          _logger.warning('Permission denied: ${permission.toString()}');
        } else if (status.isPermanentlyDenied) {
          _logger.error('Permission permanently denied: ${permission.toString()}');
        }
      } catch (e) {
        _logger.error('Error requesting permission: ${permission.toString()}', error: e);
      }
    }
  }

  void _startCleanupTimer() {
    _cleanupTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _cleanupStaleConnections();
    });
  }

  void _cleanupStaleConnections() {
    final now = DateTime.now();
    final staleDevices = <String>[];
    
    for (final entry in _lastSeen.entries) {
      if (now.difference(entry.value).inMinutes > 10) {
        staleDevices.add(entry.key);
      }
    }
    
    for (final deviceId in staleDevices) {
      _handleDisconnection(deviceId);
      _logger.info('Cleaned up stale connection: $deviceId');
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
      final deviceName = await _settingsService.getDeviceName();
      await Nearby().startAdvertising(
        deviceName,
        Strategy.P2P_CLUSTER,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: (deviceId, status) {
          if (status == Status.connected) {
            _logger.info('Successfully connected to: $deviceId');
          } else if (status == Status.rejected) {
            _logger.warning('Connection rejected by: $deviceId');
          } else if (status == Status.error) {
            _logger.error('Connection error with: $deviceId');
          }
        },
        onDisconnected: (deviceId) {
          _logger.info('Disconnected from: $deviceId');
          _handleDisconnection(deviceId);
        },
        serviceId: _serviceId,
      );
      _isAdvertising = true;
      _logger.info('Started advertising as: $deviceName');
    } catch (e) {
      _logger.error('Error starting advertising', error: e);
      _scheduleReconnect();
    }
  }

  Future<void> startDiscovery() async {
    if (_isDiscovering) return;

    try {
      await Nearby().startDiscovery(
        _serviceId,
        Strategy.P2P_CLUSTER,
        onEndpointFound: (deviceId, displayName, serviceId) {
          _logger.info('Found device: $deviceId ($displayName)');
          _requestConnection(deviceId);
        },
        onEndpointLost: (deviceId) {
          _logger.info('Lost endpoint: $deviceId');
        },
      );
      _isDiscovering = true;
      _logger.info('Started discovery');
    } catch (e) {
      _logger.error('Error starting discovery', error: e);
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (_isAdvertising || _isDiscovering) {
        _logger.info('Attempting to reconnect network services');
        if (_isAdvertising) startAdvertising();
        if (_isDiscovering) startDiscovery();
      }
    });
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
      _lastSeen[deviceId] = DateTime.now();
      _deviceListController.add(List.from(_connectedDevices));
      _logger.info('Connected to device: $deviceId (${info.endpointName})');
    }
  }

  void _handleDisconnection(String deviceId) {
    _connectedDevices.remove(deviceId);
    _deviceEndpoints.remove(deviceId);
    _lastSeen.remove(deviceId);
    _deviceListController.add(List.from(_connectedDevices));
    _logger.info('Disconnected from device: $deviceId');
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
    try {
      final maxHops = await _settingsService.getMaxHops();
      final encryptionEnabled = await _settingsService.getEncryptionEnabled();
      
      var messageContent = content;
      if (encryptionEnabled) {
        final encryptionService = EncryptionService();
        final sessionKey = encryptionService.generateSessionKey();
        final encrypted = encryptionService.encryptMessage(messageContent, sessionKey);
        messageContent = json.encode(encrypted);
      }

      final message = {
        'type': 'message',
        'content': messageContent,
        'senderId': Platform.isAndroid ? await _getDeviceId() : 'unknown',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'ttl': maxHops, // Time to live for mesh routing
        'encrypted': encryptionEnabled,
      };

      final messageData = Uint8List.fromList(json.encode(message).codeUnits);

      if (targetDeviceId != null) {
        // Send to specific device
        if (_connectedDevices.contains(targetDeviceId)) {
          await Nearby().sendBytesPayload(targetDeviceId, messageData);
          _logger.info('Message sent to specific device: $targetDeviceId');
        } else {
          _logger.warning('Target device not connected: $targetDeviceId');
        }
      } else {
        // Broadcast to all connected devices
        for (final deviceId in _connectedDevices) {
          await Nearby().sendBytesPayload(deviceId, messageData);
        }
        _logger.info('Message broadcast to ${_connectedDevices.length} devices');
      }
    } catch (e) {
      _logger.error('Failed to send message', error: e);
      rethrow;
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
        try {
          final messageData = Uint8List.fromList(json.encode(forwardedMessage).codeUnits);
          Nearby().sendBytesPayload(deviceId, messageData);
          _logger.debug('Message forwarded to: $deviceId');
        } catch (e) {
          _logger.error('Failed to forward message to: $deviceId', error: e);
        }
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

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'services/network_service.dart';
import 'services/encryption_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeService();
  await requestPermissions();
  await NetworkService().initialize();
  runApp(const NetworkApp());
}

Future<void> initializeService() async {
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

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  if (service is AndroidServiceInstance) {
    service.on('stopService').listen((event) {
      service.stopSelf();
    });
  }
}

Future<void> requestPermissions() async {
  await Permission.notification.request();
  await Permission.location.request();
  await Permission.nearbyWifiDevices.request();
  await Permission.bluetoothScan.request();
  await Permission.bluetoothAdvertise.request();
  await Permission.bluetoothConnect.request();
}

class NetworkApp extends StatelessWidget {
  const NetworkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'File Manager',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const FileManagerScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class FileManagerScreen extends StatefulWidget {
  const FileManagerScreen({super.key});

  @override
  State<FileManagerScreen> createState() => _FileManagerScreenState();
}

class _FileManagerScreenState extends State<FileManagerScreen> {
  final NetworkService _networkService = NetworkService();
  bool _isNetworkActive = false;
  List<String> _connectedDevices = [];

  @override
  void initState() {
    super.initState();
    _setupNetworkListeners();
  }

  void _setupNetworkListeners() {
    _networkService.deviceListStream.listen((devices) {
      setState(() {
        _connectedDevices = devices;
      });
    });

    _networkService.messageStream.listen((message) {
      print('Received message: ${message['content']}');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('File Manager'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: GestureDetector(
        onLongPress: () {
          _showNetworkSettings(context);
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Local Storage',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView(
                  children: [
                    _buildFileItem('Documents', 'folder'),
                    _buildFileItem('Downloads', 'folder'),
                    _buildFileItem('Pictures', 'folder'),
                    _buildFileItem('Videos', 'folder'),
                    _buildFileItem('Music', 'folder'),
                    const Divider(),
                    _buildNetworkStatusItem(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFileItem(String name, String type) {
    return ListTile(
      leading: Icon(
        type == 'folder' ? Icons.folder : Icons.insert_drive_file,
        color: Colors.blue,
      ),
      title: Text(name),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Opening $name...')),
        );
      },
    );
  }

  Widget _buildNetworkStatusItem() {
    return ListTile(
      leading: Icon(
        _isNetworkActive ? Icons.wifi : Icons.wifi_off,
        color: _isNetworkActive ? Colors.green : Colors.grey,
      ),
      title: Text('Network Status: ${_isNetworkActive ? "Active" : "Inactive"}'),
      subtitle: Text('Connected devices: ${_connectedDevices.length}'),
      trailing: Switch(
        value: _isNetworkActive,
        onChanged: (value) {
          setState(() {
            _isNetworkActive = value;
          });
          if (value) {
            _startNetworkServices();
          } else {
            _stopNetworkServices();
          }
        },
      ),
    );
  }

  void _startNetworkServices() async {
    await _networkService.startAdvertising();
    await _networkService.startDiscovery();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Network services started')),
    );
  }

  void _stopNetworkServices() async {
    await _networkService.stopAll();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Network services stopped')),
    );
  }

  void _showNetworkSettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Network Settings'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('P2P Network Configuration'),
                    SizedBox(height: 16),
                    Text('Status: ${_isNetworkActive ? "Active" : "Inactive"}'),
                    Text('Connected Nodes: ${_connectedDevices.length}'),
                    Text('Protocol: Mesh'),
                    const SizedBox(height: 16),
                    const Text('Connected Devices:', style: TextStyle(fontWeight: FontWeight.bold)),
                    ..._connectedDevices.map((device) => Padding(
                      padding: const EdgeInsets.only(left: 16.0, top: 4.0),
                      child: Text('• $device'),
                    )),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        _networkService.sendMessage('Test message from ${DateTime.now()}');
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Test message sent')),
                        );
                      },
                      child: const Text('Send Test Message'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

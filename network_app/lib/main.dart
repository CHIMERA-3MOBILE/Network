import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeService();
  await requestPermissions();
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
      initialNotificationTitle: 'Network Utility',
      initialNotificationContent: 'Running in background',
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

  void _showNetworkSettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Network Settings'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('P2P Network Configuration'),
              SizedBox(height: 16),
              Text('Status: Connected'),
              Text('Nodes: 1'),
              Text('Protocol: Mesh'),
            ],
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
  }
}

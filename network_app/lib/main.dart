import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/network_service.dart';
import 'services/encryption_service.dart';
import 'services/logger_service.dart';
import 'services/settings_service.dart';
import 'widgets/animated_file_item.dart';
import 'widgets/network_status_card.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  // Initialize services
  await initializeServices();
  await requestPermissions();
  await NetworkService().initialize();
  
  // Check first launch
  final settingsService = SettingsService();
  if (await settingsService.isFirstLaunch()) {
    await settingsService.setFirstLaunchComplete();
  }
  
  runApp(const NetworkApp());
}

Future<void> initializeServices() async {
  final service = FlutterBackgroundService();
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      isForegroundMode: true,
      autoStart: true,
      notificationChannelId: 'network_app_channel',
      initialNotificationTitle: 'File Manager',
      initialNotificationContent: 'Background service active',
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
  final logger = LoggerService();
  final permissions = [
    Permission.notification,
    Permission.location,
    Permission.nearbyWifiDevices,
    Permission.bluetoothScan,
    Permission.bluetoothAdvertise,
    Permission.bluetoothConnect,
  ];

  for (final permission in permissions) {
    try {
      final status = await permission.request();
      if (status.isGranted) {
        logger.info('Permission granted: ${permission.toString()}');
      } else if (status.isDenied) {
        logger.warning('Permission denied: ${permission.toString()}');
      } else if (status.isPermanentlyDenied) {
        logger.error('Permission permanently denied: ${permission.toString()}');
      }
    } catch (e) {
      logger.error('Error requesting permission: ${permission.toString()}', error: e);
    }
  }
}

class NetworkApp extends StatelessWidget {
  const NetworkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'File Manager',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          scrolledUnderElevation: 1,
        ),
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
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

class _FileManagerScreenState extends State<FileManagerScreen>
    with TickerProviderStateMixin {
  final NetworkService _networkService = NetworkService();
  final LoggerService _logger = LoggerService();
  final SettingsService _settingsService = SettingsService();
  
  bool _isNetworkActive = false;
  List<String> _connectedDevices = [];
  String _deviceName = 'FileManager';
  
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadSettings();
    _setupNetworkListeners();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));
    _fadeController.forward();
  }

  Future<void> _loadSettings() async {
    final deviceName = await _settingsService.getDeviceName();
    final autoStart = await _settingsService.getAutoStartNetwork();
    
    setState(() {
      _deviceName = deviceName;
    });
    
    if (autoStart) {
      _startNetworkServices();
    }
  }

  void _setupNetworkListeners() {
    _networkService.deviceListStream.listen((devices) {
      setState(() {
        _connectedDevices = devices;
      });
      _logger.info('Connected devices updated: ${devices.length}');
    });

    _networkService.messageStream.listen((message) {
      _logger.info('Message received: ${message['content']} from ${message['senderId']}');
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(_deviceName),
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey[800],
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showAboutDialog,
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: GestureDetector(
          onLongPress: _showNetworkSettings,
          child: RefreshIndicator(
            onRefresh: _refreshData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 24),
                  NetworkStatusCard(
                    isActive: _isNetworkActive,
                    connectedDevices: _connectedDevices.length,
                    onToggle: _toggleNetwork,
                    onSettings: _showNetworkSettings,
                  ),
                  const SizedBox(height: 24),
                  _buildFileSection(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Local Storage',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Manage your files and folders',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildFileSection() {
    final files = [
      {'name': 'Documents', 'type': 'documents'},
      {'name': 'Downloads', 'type': 'downloads'},
      {'name': 'Pictures', 'type': 'pictures'},
      {'name': 'Videos', 'type': 'videos'},
      {'name': 'Music', 'type': 'music'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Folders',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        ...files.map((file) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: AnimatedFileItem(
            name: file['name']!,
            type: file['type']!,
            onTap: () => _handleFileTap(file['name']!),
          ),
        )),
      ],
    );
  }

  void _handleFileTap(String folderName) {
    _logger.info('Folder tapped: $folderName');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening $folderName...'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Future<void> _toggleNetwork() async {
    setState(() {
      _isNetworkActive = !_isNetworkActive;
    });

    if (_isNetworkActive) {
      await _startNetworkServices();
    } else {
      await _stopNetworkServices();
    }
  }

  Future<void> _startNetworkServices() async {
    try {
      await _networkService.startAdvertising();
      await _networkService.startDiscovery();
      _logger.info('Network services started');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Network services started'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      _logger.error('Failed to start network services', error: e);
      setState(() {
        _isNetworkActive = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to start network services'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _stopNetworkServices() async {
    try {
      await _networkService.stopAll();
      _logger.info('Network services stopped');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Network services stopped'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      _logger.error('Failed to stop network services', error: e);
    }
  }

  Future<void> _refreshData() async {
    await Future.delayed(const Duration(milliseconds: 500));
    _logger.info('Data refreshed');
  }

  void _showNetworkSettings() {
    showDialog(
      context: context,
      builder: (context) => NetworkSettingsDialog(
        isActive: _isNetworkActive,
        connectedDevices: _connectedDevices,
        deviceName: _deviceName,
        onDeviceNameChanged: (name) {
          setState(() {
            _deviceName = name;
          });
          _settingsService.setDeviceName(name);
        },
        onSendMessage: () => _sendTestMessage(),
      ),
    );
  }

  Future<void> _sendTestMessage() async {
    try {
      await _networkService.sendMessage(
        'Test message from $_deviceName at ${DateTime.now()}',
      );
      _logger.info('Test message sent');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Test message sent'),
          backgroundColor: Colors.blue,
        ),
      );
    } catch (e) {
      _logger.error('Failed to send test message', error: e);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to send test message'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'File Manager',
      applicationVersion: '1.0.0',
      applicationIcon: const Icon(Icons.folder, size: 48),
      children: [
        const Text('A sophisticated file management utility with advanced networking capabilities.'),
      ],
    );
  }
}

class NetworkSettingsDialog extends StatefulWidget {
  final bool isActive;
  final List<String> connectedDevices;
  final String deviceName;
  final Function(String) onDeviceNameChanged;
  final VoidCallback onSendMessage;

  const NetworkSettingsDialog({
    super.key,
    required this.isActive,
    required this.connectedDevices,
    required this.deviceName,
    required this.onDeviceNameChanged,
    required this.onSendMessage,
  });

  @override
  State<NetworkSettingsDialog> createState() => _NetworkSettingsDialogState();
}

class _NetworkSettingsDialogState extends State<NetworkSettingsDialog> {
  late TextEditingController _deviceNameController;

  @override
  void initState() {
    super.initState();
    _deviceNameController = TextEditingController(text: widget.deviceName);
  }

  @override
  void dispose() {
    _deviceNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.settings_ethernet,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  'Network Settings',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _deviceNameController,
              decoration: const InputDecoration(
                labelText: 'Device Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.devices),
              ),
              onSubmitted: (value) {
                widget.onDeviceNameChanged(value);
              },
            ),
            const SizedBox(height: 20),
            _buildStatusCard(),
            const SizedBox(height: 20),
            _buildDeviceList(),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
                const SizedBox(width: 8),
                if (widget.isActive)
                  ElevatedButton.icon(
                    onPressed: widget.onSendMessage,
                    icon: const Icon(Icons.send),
                    label: const Text('Send Test'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.isActive 
            ? Colors.green.withOpacity(0.1) 
            : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.isActive 
              ? Colors.green.withOpacity(0.3) 
              : Colors.grey.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                widget.isActive ? Icons.wifi : Icons.wifi_off,
                color: widget.isActive ? Colors.green : Colors.grey,
              ),
              const SizedBox(width: 8),
              Text(
                'Status: ${widget.isActive ? "Active" : "Inactive"}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: widget.isActive ? Colors.green : Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Protocol: Mesh Network'),
          Text('Connected Nodes: ${widget.connectedDevices.length}'),
        ],
      ),
    );
  }

  Widget _buildDeviceList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Connected Devices',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        if (widget.connectedDevices.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                'No devices connected',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
          )
        else
          ...widget.connectedDevices.map((device) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(Icons.smartphone, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    device,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          )),
      ],
    );
  }
}

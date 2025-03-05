import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import 'dart:convert';
import 'dart:async';

void main() {
  runApp(const AgriCareApp());
}

class AgriCareApp extends StatelessWidget {
  const AgriCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AgriCare',
      theme: ThemeData(
        primarySwatch: Colors.green,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
        ),
      ),
      home: const GreenhouseMonitorScreen(),
    );
  }
}

class GreenhouseMonitorScreen extends StatefulWidget {
  const GreenhouseMonitorScreen({super.key});

  @override
  _GreenhouseMonitorScreenState createState() => _GreenhouseMonitorScreenState();
}

class _GreenhouseMonitorScreenState extends State<GreenhouseMonitorScreen> {
  BluetoothDevice? _connectedDevice;
  bool _isScanning = false;
  String temperature = "--";
  String humidity = "--";
  String alertMessage = "No alerts";
  
  List<FlSpot> temperatureSpots = [];
  List<FlSpot> humiditySpots = [];
  
  final String apiKey = "YOUR_OPENWEATHERMAP_API_KEY"; 
  final String city = "Manila";

  @override
  void initState() {
    super.initState();
    _initializeBluetooth();
  }

  Future<void> _initializeBluetooth() async {
    // Ensure Bluetooth is available
    if (!await FlutterBluePlus.isAvailable) {
      _showBluetoothUnavailableDialog();
      return;
    }

    // Turn on Bluetooth
    await FlutterBluePlus.turnOn();
    
    // Start scanning with a more robust approach
    _startDeviceScan();
  }

  void _startDeviceScan() {
    // Prevent multiple simultaneous scans
    if (_isScanning) return;

    setState(() {
      _isScanning = true;
      _connectedDevice = null;
    });

    // Clear previous scan results
    FlutterBluePlus.stopScan();

    // Start a new scan
    FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 15),
      // Optional: add service UUIDs if known
      // withServices: [Guid('your-service-uuid')]
    );

    // Listen to scan results
    FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult result in results) {
        // More flexible device detection
        if (_isTargetDevice(result.device)) {
          _connectToDevice(result.device);
          break;
        }
      }
    }, onDone: () {
      setState(() {
        _isScanning = false;
      });
      _showNoDeviceFoundDialog();
    }, onError: (error) {
      print("Bluetooth scan error: $error");
      setState(() {
        _isScanning = false;
      });
    });
  }

  bool _isTargetDevice(BluetoothDevice device) {
    // More flexible device name matching
    return device.platformName.contains('STM32') || 
           device.platformName.contains('Greenhouse') ||
           device.platformName.contains('Sensor');
  }

  void _connectToDevice(BluetoothDevice device) async {
    try {
      // Stop scanning
      await FlutterBluePlus.stopScan();

      // Connect to device
      await device.connect(timeout: const Duration(seconds: 15));
      
      setState(() {
        _connectedDevice = device;
        _isScanning = false;
      });

      // Discover services
      await _discoverServices(device);
    } catch (e) {
      print("Connection error: $e");
      _showConnectionErrorDialog(e.toString());
    }
  }

  Future<void> _discoverServices(BluetoothDevice device) async {
    try {
      List<BluetoothService> services = await device.discoverServices();
      // Additional service discovery logic if needed
    } catch (e) {
      print("Service discovery error: $e");
    }
  }

  void _showBluetoothUnavailableDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bluetooth Unavailable'),
        content: const Text('Bluetooth is not available on this device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showNoDeviceFoundDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('No Device Found'),
        content: const Text('Could not find a suitable greenhouse monitoring device.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _startDeviceScan();
            },
            child: const Text('Retry'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showConnectionErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Connection Error'),
        content: Text('Failed to connect to device: $error'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _startDeviceScan();
            },
            child: const Text('Retry'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AgriCare Greenhouse Monitor'),
        actions: [
          IconButton(
            icon: Icon(_isScanning ? Icons.stop : Icons.bluetooth_searching),
            onPressed: _isScanning ? FlutterBluePlus.stopScan : _startDeviceScan,
          ),
        ],
      ),
      body: Center(
        child: _isScanning 
          ? const CircularProgressIndicator()
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Temperature: $temperature °C", 
                  style: const TextStyle(fontSize: 22)
                ),
                Text(
                  "Humidity: $humidity %", 
                  style: const TextStyle(fontSize: 22)
                ),
                const SizedBox(height: 20),
                Text(
                  alertMessage, 
                  style: const TextStyle(fontSize: 24, color: Colors.red)
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _startDeviceScan,
                  child: const Text("Scan for Devices"),
                ),
              ],
            ),
      ),
    );
  }

  @override
  void dispose() {
    _connectedDevice?.disconnect();
    FlutterBluePlus.stopScan();
    super.dispose();
  }
}
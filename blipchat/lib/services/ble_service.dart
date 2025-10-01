import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:crypto/crypto.dart';
import 'package:blipchat/models/message.dart';

class BleService {
  static const String serviceUuid = "12345678-1234-5678-9012-123456789abc";
  static const String characteristicUuid = "87654321-4321-8765-2109-cba987654321";
  
  final StreamController<Message> _messageStreamController = StreamController<Message>.broadcast();
  final StreamController<bool> _connectionStatusController = StreamController<bool>.broadcast();
  final List<BluetoothDevice> _connectedDevices = [];
  final List<Message> _messages = [];
  
  bool _isActive = false;
  BluetoothCharacteristic? _writeCharacteristic;
  late String _deviceUsername;

  Stream<Message> get messageStream => _messageStreamController.stream;
  Stream<bool> get connectionStatusStream => _connectionStatusController.stream;
  bool get isActive => _isActive;
  String get deviceUsername => _deviceUsername;
  List<Message> get messages => List.unmodifiable(_messages);

  BleService() {
    _generateRandomUsername();
    _initializeBluetooth();
  }

  void _generateRandomUsername() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    _deviceUsername = String.fromCharCodes(
      Iterable.generate(10, (_) => chars.codeUnitAt(random.nextInt(chars.length)))
    );
  }

  Future<void> _initializeBluetooth() async {
    try {
      // Check if Bluetooth is supported
      if (await FlutterBluePlus.isSupported == false) {
        print("Bluetooth not supported by this device");
        return;
      }

      // Listen to bluetooth state changes
      FlutterBluePlus.adapterState.listen((BluetoothAdapterState state) {
        print("Bluetooth adapter state: $state");
        if (state == BluetoothAdapterState.on && _isActive) {
          _startScanning();
        } else if (state != BluetoothAdapterState.on) {
          _stopScanning();
        }
      });
    } catch (e) {
      print("Error initializing Bluetooth: $e");
    }
  }

  Future<bool> requestPermissions() async {
    try {
      Map<Permission, PermissionStatus> statuses = await [
        Permission.bluetooth,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.bluetoothAdvertise,
        Permission.location,
      ].request();

      bool allGranted = statuses.values.every((status) => status == PermissionStatus.granted);
      return allGranted;
    } catch (e) {
      print("Error requesting permissions: $e");
      return false;
    }
  }

  Future<bool> toggleConnection() async {
    if (_isActive) {
      await deactivate();
      return false;
    } else {
      return await activate();
    }
  }

  Future<bool> activate() async {
    try {
      bool permissionsGranted = await requestPermissions();
      if (!permissionsGranted) {
        print("Permissions not granted");
        return false;
      }

      // Turn on Bluetooth if it's off
      if (await FlutterBluePlus.isOn == false) {
        await FlutterBluePlus.turnOn();
      }

      _isActive = true;
      _connectionStatusController.add(true);
      
      await _startScanning();
      await _startAdvertising();
      
      return true;
    } catch (e) {
      print("Error activating BLE: $e");
      _isActive = false;
      _connectionStatusController.add(false);
      return false;
    }
  }

  Future<void> deactivate() async {
    try {
      _isActive = false;
      _connectionStatusController.add(false);
      
      await _stopScanning();
      await _disconnectAllDevices();
    } catch (e) {
      print("Error deactivating BLE: $e");
    }
  }

  Future<void> _startScanning() async {
    try {
      // Start scanning for devices
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 4),
        withServices: [Guid(serviceUuid)],
      );

      // Listen to scan results
      FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult result in results) {
          _connectToDevice(result.device);
        }
      });
    } catch (e) {
      print("Error starting scan: $e");
    }
  }

  Future<void> _stopScanning() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (e) {
      print("Error stopping scan: $e");
    }
  }

  Future<void> _startAdvertising() async {
    // Note: Flutter Blue Plus doesn't support advertising directly
    // This would require platform-specific implementation
    // For now, we'll use peripheral mode simulation
    
    print("Starting advertising (simulated)");
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    try {
      if (_connectedDevices.contains(device)) return;

      await device.connect();
      _connectedDevices.add(device);

      // Discover services
      List<BluetoothService> services = await device.discoverServices();
      
      for (BluetoothService service in services) {
        if (service.uuid.toString().toLowerCase() == serviceUuid.toLowerCase()) {
          for (BluetoothCharacteristic characteristic in service.characteristics) {
            if (characteristic.uuid.toString().toLowerCase() == characteristicUuid.toLowerCase()) {
              _writeCharacteristic = characteristic;
              
              // Subscribe to notifications
              if (characteristic.properties.notify) {
                await characteristic.setNotifyValue(true);
                characteristic.lastValueStream.listen((value) {
                  _handleReceivedMessage(value);
                });
              }
            }
          }
        }
      }
    } catch (e) {
      print("Error connecting to device: $e");
      _connectedDevices.remove(device);
    }
  }

  Future<void> _disconnectAllDevices() async {
    for (BluetoothDevice device in List.from(_connectedDevices)) {
      try {
        await device.disconnect();
      } catch (e) {
        print("Error disconnecting device: $e");
      }
    }
    _connectedDevices.clear();
  }

  Future<void> sendMessage(String content) async {
    if (!_isActive || content.trim().isEmpty) return;

    try {
      final message = Message(
        id: _generateMessageId(),
        username: _deviceUsername,
        content: content.trim(),
        timestamp: DateTime.now(),
        isLocal: true,
      );

      // Add to local messages
      _messages.add(message);
      _messageStreamController.add(message);

      // Send to connected devices
      if (_writeCharacteristic != null) {
        final messageJson = jsonEncode(message.toJson());
        final messageBytes = utf8.encode(messageJson);
        
        try {
          await _writeCharacteristic!.write(messageBytes);
        } catch (e) {
          print("Error writing to characteristic: $e");
        }
      }

      // Simulate sending to other devices (for testing when only one device)
      if (_connectedDevices.isEmpty) {
        print("No connected devices - message sent locally only");
      }
    } catch (e) {
      print("Error sending message: $e");
    }
  }

  void _handleReceivedMessage(List<int> data) {
    try {
      final messageJson = utf8.decode(data);
      final messageData = jsonDecode(messageJson);
      final message = Message.fromJson(messageData);
      
      // Don't add messages from ourselves
      if (message.username != _deviceUsername) {
        _messages.add(message);
        _messageStreamController.add(message);
      }
    } catch (e) {
      print("Error handling received message: $e");
    }
  }

  String _generateMessageId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(10000);
    final data = '$_deviceUsername$timestamp$random';
    return sha256.convert(utf8.encode(data)).toString().substring(0, 16);
  }

  void dispose() {
    deactivate();
    _messageStreamController.close();
    _connectionStatusController.close();
  }
}
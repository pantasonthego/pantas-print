import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

class BluetoothProvider with ChangeNotifier {
  BluetoothState _bluetoothState = BluetoothState.UNKNOWN;
  BluetoothConnection? _connection;
  BluetoothDevice? _connectedDevice;
  List<BluetoothDevice> _devices = [];
  bool _isScanning = false;
  bool _isConnecting = false;

  BluetoothState get bluetoothState => _bluetoothState;
  BluetoothConnection? get connection => _connection;
  BluetoothDevice? get connectedDevice => _connectedDevice;
  List<BluetoothDevice> get devices => _devices;
  bool get isScanning => _isScanning;
  bool get isConnecting => _isConnecting;
  bool get isConnected => _connection != null && _connection!.isConnected;

  BluetoothProvider() {
    _initBluetooth();
  }

  Future<void> _initBluetooth() async {
    _bluetoothState = await FlutterBluetoothSerial.instance.state;
    notifyListeners();

    FlutterBluetoothSerial.instance.onStateChanged().listen((state) {
      _bluetoothState = state;
      if (state == BluetoothState.STATE_OFF) {
        _connection = null;
        _connectedDevice = null;
      }
      notifyListeners();
    });

    _tryAutoConnect();
  }

  Future<void> _tryAutoConnect() async {
    final prefs = await SharedPreferences.getInstance();
    final lastAddress = prefs.getString('last_printer_address');
    if (lastAddress != null && _bluetoothState == BluetoothState.STATE_ON) {
      // Logic to find device and connect could be added here
    }
  }

  Future<void> scanDevices() async {
    if (_isScanning) return;
    
    var status = await Permission.bluetoothScan.request();
    var connectStatus = await Permission.bluetoothConnect.request();
    var locationStatus = await Permission.location.request();

    if (status.isGranted && connectStatus.isGranted) {
      _isScanning = true;
      _devices = [];
      notifyListeners();

      try {
        _devices = await FlutterBluetoothSerial.instance.getBondedDevices();
      } catch (e) {
        debugPrint("Error getting bonded devices: $e");
      }

      _isScanning = false;
      notifyListeners();
    }
  }

  Future<bool> connect(BluetoothDevice device) async {
    if (_isConnecting) return false;
    _isConnecting = true;
    notifyListeners();

    try {
      if (_connection != null) {
        await _connection!.close();
      }

      _connection = await BluetoothConnection.toAddress(device.address);
      _connectedDevice = device;
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_printer_address', device.address);
      await prefs.setString('last_printer_name', device.name ?? 'Unknown');

      _isConnecting = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint("Connection error: $e");
      _isConnecting = false;
      _connection = null;
      _connectedDevice = null;
      notifyListeners();
      return false;
    }
  }

  Future<void> disconnect() async {
    await _connection?.close();
    _connection = null;
    _connectedDevice = null;
    notifyListeners();
  }
}

import 'package:esc_pos_bluetooth/esc_pos_bluetooth.dart';

class BluetoothAdapterService {
  static final printerManager = PrinterBluetoothManager();
  
  static Future<bool> initBluetooth() async {
    try {
      await printerManager.startScan(Duration(seconds: 5));
      return true;
    } catch (e) {
      print('Error init Bluetooth: $e');
      return false;
    }
  }
  
  static List<PrinterBluetooth> getPairedDevices() {
    return printerManager.pairedDevices;
  }
  
  static Future<bool> connectToDevice(PrinterBluetooth device) async {
    try {
      await printerManager.connect(device);
      return true;
    } catch (e) {
      print('Error connect: $e');
      return false;
    }
  }
  
  static void disconnect() {
    printerManager.disconnect();
  }
  
  static void startScan({Duration duration = const Duration(seconds: 5)}) {
    printerManager.startScan(duration);
  }
  
  static void stopScan() {
    printerManager.stopScan();
  }
}

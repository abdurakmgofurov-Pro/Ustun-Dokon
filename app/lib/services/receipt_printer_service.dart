import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrinterDevice {
  final String name;
  final String mac;
  const PrinterDevice({required this.name, required this.mac});
}

/// Bluetooth termal chek printeri bilan ishlash: ulangan qurilmalar
/// ro'yxati, tanlangan printerni eslab qolish va baytlarni yuborish.
class ReceiptPrinterService {
  static const _kMac = 'printer_mac';
  static const _kName = 'printer_name';

  /// Android 12+ da BLUETOOTH_CONNECT ruxsatini so'raydi (kerak bo'lsa).
  /// Birinchi chaqiriqda tizim dialogini ko'rsatadi va false qaytarishi
  /// mumkin — foydalanuvchi ruxsat berganidan keyin qayta chaqirish kerak.
  Future<bool> ensurePermission() async {
    return PrintBluetoothThermal.isPermissionBluetoothGranted;
  }

  Future<bool> isBluetoothEnabled() => PrintBluetoothThermal.bluetoothEnabled;

  Future<List<PrinterDevice>> pairedDevices() async {
    final list = await PrintBluetoothThermal.pairedBluetooths;
    return list
        .map((d) => PrinterDevice(name: d.name, mac: d.macAdress))
        .toList();
  }

  Future<PrinterDevice?> getSelected() async {
    final prefs = await SharedPreferences.getInstance();
    final mac = prefs.getString(_kMac);
    if (mac == null || mac.isEmpty) return null;
    return PrinterDevice(name: prefs.getString(_kName) ?? mac, mac: mac);
  }

  Future<void> select(PrinterDevice device) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kMac, device.mac);
    await prefs.setString(_kName, device.name);
  }

  Future<void> forget() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kMac);
    await prefs.remove(_kName);
    final connected = await PrintBluetoothThermal.connectionStatus;
    if (connected) await PrintBluetoothThermal.disconnect;
  }

  /// Tanlangan printerga ulanadi (agar hali ulanmagan bo'lsa) va baytlarni
  /// yuboradi. Xato bo'lsa tushunarli matn qaytaradi, muvaffaqiyatli
  /// bo'lsa `null` qaytaradi.
  Future<String?> printBytes(List<int> bytes) async {
    final selected = await getSelected();
    if (selected == null) {
      return 'Printer tanlanmagan. Sozlamalar > Chek bo\'limidan tanlang.';
    }

    final granted = await ensurePermission();
    if (!granted) {
      return 'Bluetooth ruxsati berilmagan. Qayta urinib ko\'ring.';
    }

    final enabled = await isBluetoothEnabled();
    if (!enabled) {
      return 'Bluetooth o\'chirilgan. Uni yoqib, qayta urinib ko\'ring.';
    }

    final alreadyConnected = await PrintBluetoothThermal.connectionStatus;
    if (!alreadyConnected) {
      final connected = await PrintBluetoothThermal.connect(
          macPrinterAddress: selected.mac);
      if (!connected) {
        return 'Printerga ulanib bo\'lmadi ("${selected.name}"). Printer yoqilgan va yaqinligini tekshiring.';
      }
    }

    final sent = await PrintBluetoothThermal.writeBytes(bytes);
    if (!sent) {
      return 'Chek chiqarishda xatolik yuz berdi.';
    }
    return null;
  }
}

final receiptPrinterService = ReceiptPrinterService();

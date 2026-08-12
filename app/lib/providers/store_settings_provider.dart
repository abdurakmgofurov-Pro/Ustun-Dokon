import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StoreSettings {
  final String name;
  final String phone;
  final String address;
  final String footer;
  final int paperWidthMm;

  const StoreSettings({
    this.name = 'Ustun Do\'kon',
    this.phone = '',
    this.address = '',
    this.footer = 'Xaridingiz uchun rahmat!',
    this.paperWidthMm = 58,
  });

  StoreSettings copyWith({
    String? name,
    String? phone,
    String? address,
    String? footer,
    int? paperWidthMm,
  }) {
    return StoreSettings(
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      footer: footer ?? this.footer,
      paperWidthMm: paperWidthMm ?? this.paperWidthMm,
    );
  }
}

class StoreSettingsNotifier extends StateNotifier<StoreSettings> {
  StoreSettingsNotifier() : super(const StoreSettings()) {
    _load();
  }

  static const _kName = 'store_name';
  static const _kPhone = 'store_phone';
  static const _kAddress = 'store_address';
  static const _kFooter = 'store_footer';
  static const _kPaperWidth = 'store_paper_width_mm';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = StoreSettings(
      name: prefs.getString(_kName) ?? state.name,
      phone: prefs.getString(_kPhone) ?? state.phone,
      address: prefs.getString(_kAddress) ?? state.address,
      footer: prefs.getString(_kFooter) ?? state.footer,
      paperWidthMm: prefs.getInt(_kPaperWidth) ?? state.paperWidthMm,
    );
  }

  Future<void> save({
    required String name,
    required String phone,
    required String address,
    required String footer,
    required int paperWidthMm,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kName, name);
    await prefs.setString(_kPhone, phone);
    await prefs.setString(_kAddress, address);
    await prefs.setString(_kFooter, footer);
    await prefs.setInt(_kPaperWidth, paperWidthMm);
    state = StoreSettings(
      name: name,
      phone: phone,
      address: address,
      footer: footer,
      paperWidthMm: paperWidthMm,
    );
  }
}

final storeSettingsProvider =
    StateNotifierProvider<StoreSettingsNotifier, StoreSettings>(
        (ref) => StoreSettingsNotifier());

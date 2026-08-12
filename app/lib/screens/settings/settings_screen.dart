import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/catalog_provider.dart';
import '../../providers/store_settings_provider.dart';
import '../../services/receipt_printer_service.dart';
import '../../widgets/empty_state.dart';
import '../../models/receipt.dart';
import '../../widgets/receipt_view.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Sozlamalar'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Xodimlar'),
              Tab(text: 'Kategoriyalar'),
              Tab(text: 'Chek'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_EmployeesTab(), _CategoriesTab(), _ReceiptTab()],
        ),
      ),
    );
  }
}

class _EmployeesTab extends ConsumerWidget {
  const _EmployeesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profilesAsync = ref.watch(allProfilesProvider);
    final myId = ref.watch(currentProfileProvider).valueOrNull?.id;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: () => _showCreateEmployeeDialog(context, ref),
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('Yangi xodim qo\'shish'),
          ),
        ),
        Expanded(
          child: profilesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => AsyncErrorView(
                error: e, onRetry: () => ref.invalidate(allProfilesProvider)),
            data: (profiles) => ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: profiles.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final p = profiles[i];
                final isMe = p.id == myId;
                final onSurface = Theme.of(context).colorScheme.onSurface;
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: p.role == UserRole.admin
                          ? AppColors.primary.withValues(alpha: 0.15)
                          : onSurface.withValues(alpha: 0.1),
                      child: Icon(
                        p.role == UserRole.admin
                            ? Icons.admin_panel_settings_outlined
                            : Icons.person_outline,
                        color: p.role == UserRole.admin
                            ? AppColors.primary
                            : onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    title: Text(p.fullName + (isMe ? ' (siz)' : '')),
                    subtitle:
                        Text(p.role == UserRole.admin ? 'Admin' : 'Sotuvchi'),
                    trailing: isMe
                        ? null
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Switch(
                                value: p.isActive,
                                onChanged: (v) async {
                                  await ref
                                      .read(authControllerProvider)
                                      .setActive(p.id, v);
                                  ref.invalidate(allProfilesProvider);
                                },
                              ),
                              PopupMenuButton<String>(
                                onSelected: (v) async {
                                  if (v == 'admin' || v == 'sotuvchi') {
                                    await ref
                                        .read(authControllerProvider)
                                        .updateRole(
                                            p.id,
                                            v == 'admin'
                                                ? UserRole.admin
                                                : UserRole.sotuvchi);
                                    ref.invalidate(allProfilesProvider);
                                  } else if (v == 'delete') {
                                    final confirmed = await showDialog<bool>(
                                      context: context,
                                      builder: (_) => AlertDialog(
                                        title: const Text('Xodimni o\'chirish'),
                                        content: Text(
                                            '"${p.fullName}" hisobini butunlay o\'chirmoqchimisiz? Bu amalni orqaga qaytarib bo\'lmaydi.'),
                                        actions: [
                                          TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, false),
                                              child: const Text('Bekor qilish')),
                                          FilledButton(
                                              style: FilledButton.styleFrom(
                                                  backgroundColor:
                                                      AppColors.danger),
                                              onPressed: () =>
                                                  Navigator.pop(context, true),
                                              child: const Text('O\'chirish')),
                                        ],
                                      ),
                                    );
                                    if (confirmed == true) {
                                      final error = await ref
                                          .read(authControllerProvider)
                                          .deleteEmployee(p.id);
                                      ref.invalidate(allProfilesProvider);
                                      if (error != null && context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                                SnackBar(content: Text(error)));
                                      }
                                    }
                                  }
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                      value: 'admin', child: Text('Admin qilish')),
                                  PopupMenuItem(
                                      value: 'sotuvchi',
                                      child: Text('Sotuvchi qilish')),
                                  PopupMenuDivider(),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text('O\'chirish',
                                        style:
                                            TextStyle(color: AppColors.danger)),
                                  ),
                                ],
                                icon: const Icon(Icons.more_vert),
                              ),
                            ],
                          ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  void _showCreateEmployeeDialog(BuildContext context, WidgetRef ref) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    UserRole role = UserRole.sotuvchi;
    bool loading = false;
    String? error;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Yangi xodim qo\'shish'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Ism familiya'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Kiriting' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: emailCtrl,
                    decoration: const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) =>
                        (v == null || !v.contains('@')) ? 'To\'g\'ri email' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: passwordCtrl,
                    decoration: const InputDecoration(labelText: 'Vaqtinchalik parol'),
                    validator: (v) =>
                        (v == null || v.length < 6) ? 'Kamida 6 ta belgi' : null,
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<UserRole>(
                    segments: const [
                      ButtonSegment(
                          value: UserRole.sotuvchi, label: Text('Sotuvchi')),
                      ButtonSegment(value: UserRole.admin, label: Text('Admin')),
                    ],
                    selected: {role},
                    onSelectionChanged: (s) => setState(() => role = s.first),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 10),
                    Text(error!, style: const TextStyle(color: AppColors.danger)),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Bekor qilish'),
            ),
            FilledButton(
              onPressed: loading
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setState(() => loading = true);
                      final err = await ref
                          .read(authControllerProvider)
                          .createEmployee(
                            email: emailCtrl.text,
                            password: passwordCtrl.text,
                            fullName: nameCtrl.text.trim(),
                            role: role,
                          );
                      if (err != null) {
                        setState(() {
                          loading = false;
                          error = err;
                        });
                        return;
                      }
                      ref.invalidate(allProfilesProvider);
                      if (dialogContext.mounted) Navigator.pop(dialogContext);
                    },
              child: loading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Qo\'shish'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoriesTab extends ConsumerStatefulWidget {
  const _CategoriesTab();

  @override
  ConsumerState<_CategoriesTab> createState() => _CategoriesTabState();
}

class _CategoriesTabState extends ConsumerState<_CategoriesTab> {
  final _controller = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Kategoriya nomini kiriting'),
        backgroundColor: AppColors.danger,
      ));
      return;
    }
    setState(() => _saving = true);
    final error = await ref.read(catalogControllerProvider).addCategory(name);
    if (!mounted) return;
    setState(() => _saving = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error),
        backgroundColor: AppColors.danger,
      ));
      return;
    }
    _controller.clear();
    ref.invalidate(categoriesProvider);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('"$name" kategoriyasi qo\'shildi'),
      backgroundColor: AppColors.primary,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                      labelText: 'Yangi kategoriya nomi'),
                  onSubmitted: (_) => _add(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _saving ? null : _add,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.add),
              ),
            ],
          ),
        ),
        Expanded(
          child: categoriesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => AsyncErrorView(
                error: e, onRetry: () => ref.invalidate(categoriesProvider)),
            data: (categories) => ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: categories.length,
              itemBuilder: (context, i) => Card(
                child: ListTile(title: Text(categories[i].name)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ReceiptTab extends ConsumerStatefulWidget {
  const _ReceiptTab();

  @override
  ConsumerState<_ReceiptTab> createState() => _ReceiptTabState();
}

class _ReceiptTabState extends ConsumerState<_ReceiptTab> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _footerCtrl;
  int _paperWidth = 58;
  bool _saving = false;
  PrinterDevice? _selectedPrinter;
  bool _loadingPrinter = true;

  @override
  void initState() {
    super.initState();
    final s = ref.read(storeSettingsProvider);
    _nameCtrl = TextEditingController(text: s.name);
    _phoneCtrl = TextEditingController(text: s.phone);
    _addressCtrl = TextEditingController(text: s.address);
    _footerCtrl = TextEditingController(text: s.footer);
    _paperWidth = s.paperWidthMm;
    _loadSelectedPrinter();
  }

  Future<void> _loadSelectedPrinter() async {
    final device = await receiptPrinterService.getSelected();
    if (!mounted) return;
    setState(() {
      _selectedPrinter = device;
      _loadingPrinter = false;
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _footerCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveStoreInfo() async {
    setState(() => _saving = true);
    await ref.read(storeSettingsProvider.notifier).save(
          name: _nameCtrl.text.trim().isEmpty
              ? 'Ustun Do\'kon'
              : _nameCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          address: _addressCtrl.text.trim(),
          footer: _footerCtrl.text.trim().isEmpty
              ? 'Xaridingiz uchun rahmat!'
              : _footerCtrl.text.trim(),
          paperWidthMm: _paperWidth,
        );
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Chek sozlamalari saqlandi'),
      backgroundColor: AppColors.primary,
    ));
  }

  Future<void> _pickPrinter() async {
    final granted = await receiptPrinterService.ensurePermission();
    if (!granted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Bluetooth ruxsati kerak. Ruxsat berilgach, qayta bosing.'),
      ));
      return;
    }
    final devices = await receiptPrinterService.pairedDevices();
    if (!mounted) return;
    if (devices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Ulangan Bluetooth qurilma topilmadi. Avval printerni telefon Bluetooth sozlamalaridan ulang (pair).'),
      ));
      return;
    }
    final chosen = await showModalBottomSheet<PrinterDevice>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Printerni tanlang',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            for (final d in devices)
              ListTile(
                leading: const Icon(Icons.print_outlined),
                title: Text(d.name.isEmpty ? '(nomsiz)' : d.name),
                subtitle: Text(d.mac),
                onTap: () => Navigator.pop(context, d),
              ),
          ],
        ),
      ),
    );
    if (chosen != null) {
      await receiptPrinterService.select(chosen);
      if (!mounted) return;
      setState(() => _selectedPrinter = chosen);
    }
  }

  Future<void> _forgetPrinter() async {
    await receiptPrinterService.forget();
    if (!mounted) return;
    setState(() => _selectedPrinter = null);
  }

  Future<void> _testPrint() async {
    final testData = ReceiptData(
      saleId: 0,
      createdAt: DateTime.now(),
      cashierName: 'Sinov',
      paymentType: PaymentType.naqd,
      items: [
        ReceiptItem(name: 'Sinov tovari', qty: 1, unit: 'dona', price: 10000),
      ],
      total: 10000,
    );
    await showReceiptSheet(context, ref, testData);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Do\'kon ma\'lumotlari (chek sarlavhasi)',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        TextField(
          controller: _nameCtrl,
          decoration: const InputDecoration(labelText: 'Do\'kon nomi'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _phoneCtrl,
          decoration: const InputDecoration(labelText: 'Telefon (ixtiyoriy)'),
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _addressCtrl,
          decoration: const InputDecoration(labelText: 'Manzil (ixtiyoriy)'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _footerCtrl,
          decoration:
              const InputDecoration(labelText: 'Chek pastidagi matn'),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const Text('Qog\'oz kengligi:'),
            const SizedBox(width: 12),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 58, label: Text('58mm')),
                ButtonSegment(value: 80, label: Text('80mm')),
              ],
              selected: {_paperWidth},
              onSelectionChanged: (s) =>
                  setState(() => _paperWidth = s.first),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ElevatedButton(
          onPressed: _saving ? null : _saveStoreInfo,
          child: _saving
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Saqlash'),
        ),
        const SizedBox(height: 28),
        const Divider(),
        const SizedBox(height: 14),
        Text('Bluetooth printer',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        if (_loadingPrinter)
          const Center(child: CircularProgressIndicator())
        else
          Card(
            child: ListTile(
              leading: const Icon(Icons.print_outlined),
              title: Text(_selectedPrinter?.name.isNotEmpty == true
                  ? _selectedPrinter!.name
                  : 'Printer tanlanmagan'),
              subtitle: _selectedPrinter != null
                  ? Text(_selectedPrinter!.mac)
                  : const Text('Chek chiqarish uchun printer tanlang'),
              trailing: _selectedPrinter != null
                  ? IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Unutish',
                      onPressed: _forgetPrinter,
                    )
                  : null,
            ),
          ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _pickPrinter,
          icon: const Icon(Icons.bluetooth_searching),
          label: Text(_selectedPrinter == null
              ? 'Printer tanlash'
              : 'Boshqa printer tanlash'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _testPrint,
          icon: const Icon(Icons.receipt_long_outlined),
          label: const Text('Sinov chekini ko\'rish'),
        ),
      ],
    );
  }
}

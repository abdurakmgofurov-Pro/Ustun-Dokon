import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final error = await ref
        .read(authControllerProvider)
        .signIn(_email.text, _password.text);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned(top: -80, left: -60, child: _blob(AppColors.primary)),
          Positioned(
            bottom: -100,
            right: -80,
            child: _blob(AppColors.secondary),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(
                                  alpha: 0.12,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.storefront,
                                size: 40,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "Ustun Do'kon",
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Tizimga kirish',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 24),
                          TextFormField(
                            controller: _email,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                            ),
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) => (v == null || !v.contains('@'))
                                ? 'To\'g\'ri email kiriting'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _password,
                            decoration: const InputDecoration(
                              labelText: 'Parol',
                            ),
                            obscureText: true,
                            validator: (v) => (v == null || v.length < 6)
                                ? 'Kamida 6 ta belgi'
                                : null,
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _error!,
                              style: const TextStyle(color: AppColors.danger),
                            ),
                          ],
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: _loading ? null : _submit,
                            child: _loading
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Kirish'),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Yangi xodim hisobini faqat admin yarata oladi\n(Sozlamalar → Xodimlar)',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.5),
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _blob(Color color) {
    return IgnorePointer(
      child: Container(
        width: 260,
        height: 260,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}

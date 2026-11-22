import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/utils/formatters.dart';
import 'auth_widgets.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  DateTime? _birthday;
  bool _busy = false;
  ApiException? _error;

  @override
  void dispose() {
    for (final c in [_name, _email, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthday ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(1920),
      lastDate: now.subtract(const Duration(days: 1)),
      helpText: 'Tu cumpleaños',
    );
    if (picked != null) setState(() => _birthday = picked);
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(sessionProvider.notifier)
          .register(name: _name.text, email: _email.text, password: _password.text, birthday: _birthday);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _error = e);
        _form.currentState!.validate(); // shows the server's field errors
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Crea tu cuenta',
      subtitle: 'Guarda tus recetas y comparte tus versiones',
      children: [
        Form(
          key: _form,
          child: AutofillGroup(
            child: Column(
              children: [
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.name],
                  textInputAction: TextInputAction.next,
                  validator: (v) => (v ?? '').trim().length < 2 ? 'Escribe tu nombre' : _error?.errorFor('name'),
                  decoration: const InputDecoration(
                    labelText: 'Nombre y apellido',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.next,
                  validator: (v) => validateEmail(v) ?? _error?.errorFor('email'),
                  decoration: const InputDecoration(labelText: 'Correo', prefixIcon: Icon(Icons.mail_outline_rounded)),
                ),
                const SizedBox(height: 12),
                PasswordField(
                  controller: _password,
                  label: 'Contraseña (mínimo 8 caracteres)',
                  validator: (v) => (v ?? '').length < 8 ? 'Usa al menos 8 caracteres' : _error?.errorFor('password'),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  tileColor: AppColors.surface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  leading: const Icon(Icons.cake_outlined),
                  title: Text(_birthday == null ? 'Cumpleaños (opcional)' : Fmt.date(_birthday!)),
                  subtitle: const Text('Tus amigos podrán sorprenderte ese día'),
                  trailing: _birthday == null
                      ? const Icon(Icons.chevron_right_rounded)
                      : IconButton(
                          tooltip: 'Quitar',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => setState(() => _birthday = null),
                        ),
                  onTap: _pickBirthday,
                ),
              ],
            ),
          ),
        ),
        if (_error != null && _error!.fieldErrors.isEmpty) ...[
          const SizedBox(height: 12),
          Text(
            _error!.message,
            style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600),
          ),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Crear cuenta'),
        ),
        const SizedBox(height: 12),
        TextButton(onPressed: _busy ? null : () => context.go('/login'), child: const Text('Ya tengo cuenta')),
      ],
    );
  }
}

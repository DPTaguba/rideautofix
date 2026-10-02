import 'package:flutter/material.dart';

import '../data/ride_repository.dart';
import '../ui/format.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'ride_app.dart';

/// Switches between Login and Register without pushing routes (the session
/// router swaps this whole widget once the user signs in).
class AuthFlow extends StatefulWidget {
  const AuthFlow({super.key});

  @override
  State<AuthFlow> createState() => _AuthFlowState();
}

class _AuthFlowState extends State<AuthFlow> {
  bool _register = false;

  @override
  Widget build(BuildContext context) => _register
      ? RegisterPage(onLogin: () => setState(() => _register = false))
      : LoginPage(onRegister: () => setState(() => _register = true));
}

class AuthLayout extends StatelessWidget {
  const AuthLayout({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
  });
  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) {
            final wide = c.maxWidth >= 900;
            final form = Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!wide) ...[
                        const Center(child: BrandLogo(size: 96)),
                        const SizedBox(height: 14),
                        Center(
                          child: Text(
                            'RideAutoFix',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1,
                                ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                      Text(
                        title,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: const TextStyle(color: AppColors.muted),
                      ),
                      const SizedBox(height: 24),
                      ...children,
                    ],
                  ),
                ),
              ),
            );
            if (!wide) return form;
            return Row(
              children: [
                Expanded(
                  child: Container(
                    color: AppColors.surface,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const BrandLogo(size: 170),
                          const SizedBox(height: 28),
                          Text(
                            'RideAutoFix',
                            style: Theme.of(context).textTheme.displaySmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 2,
                                ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Vehicle repair that comes to you',
                            style: TextStyle(color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(child: form),
              ],
            );
          },
        ),
      ),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.onRegister});
  final VoidCallback onRegister;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final repo = AppScope.read(context).repository;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await repo.signIn(_email.text, _password.text);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgot() async {
    final repo = AppScope.read(context).repository;
    final messenger = ScaffoldMessenger.of(context);
    final email = await showDialog<String>(
      context: context,
      builder: (_) => _ForgotDialog(initial: _email.text),
    );
    if (email == null) return;
    try {
      await repo.sendPasswordReset(email);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('If an account exists, a reset link has been sent.'),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(friendlyError(e)), backgroundColor: AppColors.danger),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: 'Welcome back',
      subtitle: 'Log in to book and track your home-service repairs.',
      children: [
        Form(
          key: _form,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null) ...[
                  ErrorBanner(_error!),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.mail_outline),
                  ),
                  validator: emailValidator,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _password,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  onFieldSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      tooltip: _obscure ? 'Show password' : 'Hide password',
                      icon: Icon(
                        _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Enter your password' : null,
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _forgot,
                    child: const Text('Forgot password?'),
                  ),
                ),
                const SizedBox(height: 4),
                BusyButton(label: 'Log in', busy: _busy, onPressed: _submit),
                const SizedBox(height: 16),
                GoogleSignInButton(
                  enabled: !_busy,
                  onError: (m) => setState(() => _error = m),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'New here?',
                      style: TextStyle(color: AppColors.muted),
                    ),
                    TextButton(
                      onPressed: widget.onRegister,
                      child: const Text('Create an account'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ForgotDialog extends StatefulWidget {
  const _ForgotDialog({required this.initial});
  final String initial;

  @override
  State<_ForgotDialog> createState() => _ForgotDialogState();
}

class _ForgotDialogState extends State<_ForgotDialog> {
  late final _email = TextEditingController(text: widget.initial);
  final _form = GlobalKey<FormState>();

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Reset password'),
    content: Form(
      key: _form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Enter your email and we will send you a link to reset your password.',
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _email,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email'),
            validator: emailValidator,
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        style: FilledButton.styleFrom(minimumSize: const Size(88, 44)),
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.pop(context, _email.text.trim());
          }
        },
        child: const Text('Send link'),
      ),
    ],
  );
}

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key, required this.onLogin});
  final VoidCallback onLogin;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _phone, _email, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final repo = AppScope.read(context).repository;
    // The page may be replaced while Firebase signs the new user in, so keep a
    // handle that outlives it for reporting failures.
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await repo.register(_name.text, _phone.text, _email.text, _password.text);
    } catch (e) {
      final msg = friendlyError(e);
      messenger.showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppColors.danger),
      );
      if (mounted) setState(() => _error = msg);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: 'Create your account',
      subtitle: 'It takes less than a minute.',
      children: [
        Form(
          key: _form,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null) ...[
                  ErrorBanner(_error!),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                  decoration: const InputDecoration(
                    labelText: 'Full name',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (v) => requiredText(v, 'your full name'),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  decoration: const InputDecoration(
                    labelText: 'Mobile number',
                    hintText: '09171234567',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  validator: phoneValidator,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.mail_outline),
                  ),
                  validator: emailValidator,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _password,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.newPassword],
                  decoration: InputDecoration(
                    labelText: 'Password',
                    helperText: 'At least 8 characters',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      tooltip: _obscure ? 'Show password' : 'Hide password',
                      icon: Icon(
                        _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: passwordValidator,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _confirm,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: const InputDecoration(
                    labelText: 'Confirm password',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: (v) =>
                      v != _password.text ? 'Passwords do not match' : null,
                ),
                const SizedBox(height: 20),
                BusyButton(label: 'Register', busy: _busy, onPressed: _submit),
                const SizedBox(height: 16),
                GoogleSignInButton(
                  enabled: !_busy,
                  onError: (m) => setState(() => _error = m),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Already have an account?',
                      style: TextStyle(color: AppColors.muted),
                    ),
                    TextButton(
                      onPressed: widget.onLogin,
                      child: const Text('Log in'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class GoogleSignInButton extends StatefulWidget {
  const GoogleSignInButton({
    super.key,
    required this.onError,
    this.enabled = true,
  });
  final ValueChanged<String> onError;
  final bool enabled;

  @override
  State<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<GoogleSignInButton> {
  bool _busy = false;

  Future<void> _go() async {
    final repo = AppScope.read(context).repository;
    setState(() => _busy = true);
    try {
      await repo.signInWithGoogle();
    } catch (e) {
      if (!isCancelled(e) && mounted) widget.onError(friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Row(
        children: [
          Expanded(child: Divider()),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text('or', style: TextStyle(color: AppColors.muted)),
          ),
          Expanded(child: Divider()),
        ],
      ),
      const SizedBox(height: 16),
      OutlinedButton.icon(
        onPressed: (!widget.enabled || _busy) ? null : _go,
        icon: _busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.g_mobiledata, size: 32),
        label: const Text('Continue with Google'),
      ),
    ],
  );
}
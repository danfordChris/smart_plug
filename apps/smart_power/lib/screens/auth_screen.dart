import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../config/app_icons.dart';
import '../config/constants.dart';
import '../config/images.dart';
import '../config/theme.dart';
import '../providers/settings_provider.dart';
import '../services/auth_api.dart';
import 'root_gate.dart';

/// Login / Sign up against the Plug Assistance gateway. Replaces the old
/// paste-the-HA-token setup: users authenticate here and the gateway issues a
/// per-user token, keeping the Home Assistant credential server-side.
class AuthScreen extends ConsumerStatefulWidget {
  /// Opens the form pre-selected on Sign up instead of Log in.
  final bool startWithSignUp;

  const AuthScreen({super.key, this.startWithSignUp = false});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

enum _Mode { login, signup }

class _AuthScreenState extends ConsumerState<AuthScreen> {
  late final TextEditingController _gatewayCtrl;
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _inviteCtrl = TextEditingController();

  late _Mode _mode = widget.startWithSignUp ? _Mode.signup : _Mode.login;
  bool _obscure = true;
  bool _advancedOpen = false;
  bool _busy = false;
  String? _error;
  String? _info;

  @override
  void initState() {
    super.initState();
    final stored = ref.read(settingsProvider).valueOrNull;
    _gatewayCtrl = TextEditingController(text: stored?.gatewayUrl ?? AppConstants.gatewayDefaultUrl);
  }

  @override
  void dispose() {
    _gatewayCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _inviteCtrl.dispose();
    super.dispose();
  }

  bool get _canSubmit => _gatewayCtrl.text.trim().length > 8 && _emailCtrl.text.trim().contains('@') && _passwordCtrl.text.length >= 8 && !_busy;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    final gatewayUrl = _gatewayCtrl.text.trim();
    final email = _emailCtrl.text.trim().toLowerCase();
    final password = _passwordCtrl.text;
    final api = AuthApi(baseUrl: gatewayUrl);
    try {
      if (_mode == _Mode.signup) {
        final result = await api.signup(email: email, password: password, inviteCode: _inviteCtrl.text.trim());
        if (!result.isActive) {
          // Pending admin approval — can't log in yet.
          setState(() {
            _mode = _Mode.login;
            _info = result.message.isNotEmpty ? result.message : 'Account created — waiting for an administrator to approve it.';
          });
          return;
        }
        // Active (first user / valid invite) → continue to log in.
      }
      final session = await api.login(email: email, password: password);
      await ref.read(settingsProvider.notifier).saveSession(gatewayUrl: gatewayUrl, session: session, email: email);
      // RootGate reacts to the new session and swaps to the dashboard.
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Something went wrong: $e');
    } finally {
      api.dispose();
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isSignup = _mode == _Mode.signup;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            AppBar(title: const Text('Plug Assistance'), backgroundColor: Colors.transparent),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, AppSpacing.s, AppSpacing.xxl, AppSpacing.xxl),
                children: [
                  _hero(context),
                  SegmentedButton<_Mode>(
                    segments: const [
                      ButtonSegment(value: _Mode.login, label: Text('Log in')),
                      ButtonSegment(value: _Mode.signup, label: Text('Sign up')),
                    ],
                    selected: {_mode},
                    showSelectedIcon: false,
                    onSelectionChanged: (s) => setState(() {
                      _mode = s.first;
                      _error = null;
                      _info = null;
                    }),
                  ),
                  const SizedBox(height: AppSpacing.l),
                  TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: _decoration(scheme, 'Email', AppIcons.profile),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: AppSpacing.l),
                  TextField(
                    controller: _passwordCtrl,
                    obscureText: _obscure,
                    decoration: _decoration(
                      scheme,
                      'Password',
                      AppIcons.lock,
                      suffix: IconButton(
                        tooltip: _obscure ? 'Show' : 'Hide',
                        icon: HugeIcon(icon: _obscure ? AppIcons.eye : AppIcons.eyeOff, size: 20, color: scheme.onSurfaceVariant),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                      helper: isSignup ? 'At least 8 characters.' : null,
                    ),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _submit(),
                  ),
                  if (isSignup) ...[
                    const SizedBox(height: AppSpacing.l),
                    TextField(
                      controller: _inviteCtrl,
                      decoration: _decoration(
                        scheme,
                        'Invite code (optional)',
                        AppIcons.key,
                        helper:
                            'With a code you can use the app right away. Without '
                            'one, an admin approves your account first.',
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.m),
                  _advanced(context),
                  if (_info != null) ...[
                    const SizedBox(height: AppSpacing.l),
                    _banner(context, _info!, scheme.secondaryContainer, scheme.onSecondaryContainer, AppIcons.check),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.l),
                    _banner(context, _error!, scheme.errorContainer, scheme.onErrorContainer, AppIcons.alert),
                  ],
                ],
              ),
            ),
            _bottomBar(context, isSignup),
          ],
        ),
      ),
    );
  }

  Widget _hero(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.m, bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.asset(Images.logo, fit: BoxFit.scaleDown, height: MediaQuery.of(context).size.height * 0.15),

          const SizedBox(height: AppSpacing.l),
          Text(
            _mode == _Mode.signup ? 'Create your account' : 'Welcome back',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 30, height: 1.15, letterSpacing: -0.5),
          ),
          const SizedBox(height: 6),
          Text(
            'Sign in to control your plugs. Your login is managed by Plug '
            'Assistance — the home hub credentials stay on the server.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _advanced(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(color: scheme.surfaceContainer, borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _advancedOpen = !_advancedOpen),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  HugeIcon(icon: AppIcons.link, size: 20, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Gateway server',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurface, fontWeight: FontWeight.w500),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _advancedOpen ? 0.25 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: HugeIcon(icon: AppIcons.chevronRight, size: 18, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: AppMotion.emphasized,
            child: _advancedOpen
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: TextField(
                      controller: _gatewayCtrl,
                      keyboardType: TextInputType.url,
                      decoration: _decoration(
                        scheme,
                        'Gateway URL',
                        AppIcons.link,
                        helper: 'Default: ${AppConstants.gatewayDefaultUrl} (Tailscale).',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _bottomBar(BuildContext context, bool isSignup) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
        color: scheme.surface,
      ),
      padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, AppSpacing.m, AppSpacing.xxl, AppSpacing.l),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton(
            onPressed: _canSubmit ? _submit : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.button)),
            ),
            child: _busy
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4))
                : Text(isSignup ? 'Create account' : 'Log in'),
          ),
          TextButton(onPressed: () => ref.read(previewModeProvider.notifier).state = true, child: const Text('Preview with demo data')),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 4,
            children: [
              HugeIcon(icon: HugeIcons.strokeRoundedCopyright, size: 12, color: scheme.onSurfaceVariant),
              Text("${DateTime.now().year}", style: TextTheme.of(context).labelSmall),
              Text("NM-AIST", style: TextTheme.of(context).labelSmall),
            ],
          ),
        ],
      ),
    );
  }

  InputDecoration _decoration(ColorScheme scheme, String label, dynamic icon, {Widget? suffix, String? helper}) {
    return InputDecoration(
      labelText: label,
      helperText: helper,
      helperMaxLines: 3,
      prefixIcon: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: HugeIcon(icon: icon, size: 20, color: scheme.onSurfaceVariant),
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      suffixIcon: suffix,
      border: const OutlineInputBorder(),
      filled: true,
      fillColor: scheme.surfaceContainerLow,
    );
  }

  Widget _banner(BuildContext context, String message, Color bg, Color fg, dynamic icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HugeIcon(icon: icon, size: 18, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: fg, height: 1.4)),
          ),
        ],
      ),
    );
  }
}

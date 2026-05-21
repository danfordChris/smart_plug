import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../config/app_icons.dart';
import '../config/constants.dart';
import '../config/theme.dart';
import '../providers/settings_provider.dart';
import '../services/ha_api.dart';
import 'root_gate.dart';

/// Setup / Connection screen — mirrors `SetupScreen` in
/// `implementation_plan/mobile_design_docs/screens.jsx` (lines 8-180).
class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

enum _TestResult { idle, testing, ok, fail }

class _SetupScreenState extends ConsumerState<SetupScreen> {
  late final TextEditingController _urlCtrl;
  late final TextEditingController _tokenCtrl;
  bool _obscureToken = true;
  _TestResult _testResult = _TestResult.idle;
  String? _haVersion;
  int? _switchCount;
  String? _errorMessage;
  bool _helpOpen = false;

  @override
  void initState() {
    super.initState();
    final stored = ref.read(settingsProvider).valueOrNull;
    _urlCtrl = TextEditingController(
      text: stored?.haUrl ?? AppConstants.haDefaultUrl,
    );
    _tokenCtrl = TextEditingController(text: stored?.haToken ?? '');
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _tokenCtrl.dispose();
    super.dispose();
  }

  bool get _canTest =>
      _urlCtrl.text.trim().length > 8 && _tokenCtrl.text.trim().length > 8;

  Future<void> _runTest() async {
    if (!_canTest) return;
    setState(() {
      _testResult = _TestResult.testing;
      _haVersion = null;
      _switchCount = null;
      _errorMessage = null;
    });
    final api = HaApi(
      baseUrl: _urlCtrl.text.trim(),
      token: _tokenCtrl.text.trim(),
    );
    try {
      await api.testConnection();
      final config = await api.getConfig();
      List entities = const [];
      try {
        entities = await api.listStates();
      } catch (_) {
        /* swallow */
      }
      if (!mounted) return;
      setState(() {
        _testResult = _TestResult.ok;
        _haVersion = config?['version'] as String? ?? 'Home Assistant';
        _switchCount = entities
            .where((e) =>
                (e as dynamic).entityId?.toString().startsWith('switch.') ??
                false)
            .length;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _testResult = _TestResult.fail;
        _errorMessage = _humanError(e);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _testResult = _TestResult.fail;
        _errorMessage = 'Unexpected error: $e';
      });
    } finally {
      api.dispose();
    }
  }

  String _humanError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Connection timed out. Is the URL reachable from this device?';
    }
    if (e.response?.statusCode == 401) {
      return 'Token rejected (401). Generate a new long-lived token.';
    }
    if (e.response?.statusCode == 404) {
      return "URL responded but isn't Home Assistant.";
    }
    return e.message ?? "Couldn't connect.";
  }

  Future<void> _save() async {
    await ref.read(settingsProvider.notifier).saveCredentials(
          url: _urlCtrl.text.trim(),
          token: _tokenCtrl.text.trim(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            AppBar(
              title: const Text('Setup'),
              backgroundColor: Colors.transparent,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xxl,
                  AppSpacing.s,
                  AppSpacing.xxl,
                  AppSpacing.xxl,
                ),
                children: [
                  _heroHeader(context),
                  TextField(
                    controller: _urlCtrl,
                    decoration: InputDecoration(
                      labelText: 'Home Assistant URL',
                      helperText:
                          'Tailscale IP, LAN IP, or domain. Include http(s):// and port.',
                      helperMaxLines: 2,
                      hintText: AppConstants.haDefaultUrl,
                      border: const OutlineInputBorder(),
                      filled: true,
                      fillColor: scheme.surfaceContainerLow,
                    ),
                    keyboardType: TextInputType.url,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: AppSpacing.l),
                  TextField(
                    controller: _tokenCtrl,
                    obscureText: _obscureToken,
                    decoration: InputDecoration(
                      labelText: 'Long-Lived Access Token',
                      helperText:
                          'Profile → Security → Long-Lived Access Tokens → Create Token',
                      helperMaxLines: 2,
                      border: const OutlineInputBorder(),
                      filled: true,
                      fillColor: scheme.surfaceContainerLow,
                      suffixIcon: IconButton(
                        tooltip: _obscureToken ? 'Show token' : 'Hide token',
                        icon: HugeIcon(
                          icon:
                              _obscureToken ? AppIcons.eye : AppIcons.eyeOff,
                          size: 20,
                          color: scheme.onSurfaceVariant,
                        ),
                        onPressed: () =>
                            setState(() => _obscureToken = !_obscureToken),
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: AppSpacing.l),
                  _testButton(context),
                  if (_testResult == _TestResult.ok) ...[
                    const SizedBox(height: AppSpacing.l),
                    _successCard(context),
                  ],
                  if (_testResult == _TestResult.fail) ...[
                    const SizedBox(height: AppSpacing.l),
                    _errorCard(context),
                  ],
                  const SizedBox(height: AppSpacing.xxl),
                  _tokenHelp(context),
                ],
              ),
            ),
            _bottomBar(context),
          ],
        ),
      ),
    );
  }

  Widget _heroHeader(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.m,
        bottom: AppSpacing.xxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: HugeIcon(
                icon: AppIcons.bolt,
                size: 32,
                color: scheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.l),
          Text(
            'Connect your Home Assistant',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontSize: 30,
                  height: 1.15,
                  letterSpacing: -0.5,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Paste your instance URL and a long-lived access token. The app '
            'talks directly to Home Assistant — no cloud in between.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.5,
                ),
          ),
        ],
      ),
    );
  }

  Widget _testButton(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final Widget icon;
    final String label;
    final VoidCallback? onPressed =
        (!_canTest || _testResult == _TestResult.testing) ? null : _runTest;
    switch (_testResult) {
      case _TestResult.testing:
        icon = SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            color: scheme.onSecondaryContainer,
          ),
        );
        label = 'Testing…';
        break;
      case _TestResult.ok:
        icon = HugeIcon(
          icon: AppIcons.check,
          size: 18,
          color: scheme.onSecondaryContainer,
        );
        label = 'Connected';
        break;
      case _TestResult.fail:
        icon = HugeIcon(
          icon: AppIcons.alert,
          size: 18,
          color: scheme.onSecondaryContainer,
        );
        label = "Couldn't reach instance";
        break;
      case _TestResult.idle:
        icon = HugeIcon(
          icon: AppIcons.wifi,
          size: 18,
          color: scheme.onSecondaryContainer,
        );
        label = 'Test connection';
    }
    return FilledButton.tonalIcon(
      onPressed: onPressed,
      icon: icon,
      label: Text(label),
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.button),
        ),
      ),
    );
  }

  Widget _successCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: scheme.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HugeIcon(icon: AppIcons.check, size: 18, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _haVersion ?? 'Home Assistant',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontSize: 13, color: scheme.onSurface),
                ),
                const SizedBox(height: 2),
                Text(
                  _switchCount != null
                      ? 'Found $_switchCount switch entities'
                      : 'Connection verified',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HugeIcon(icon: AppIcons.alert, size: 18, color: scheme.error),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Couldn't connect",
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: scheme.error,
                        fontSize: 13,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  _errorMessage ??
                      'Check that the URL is reachable from this device and the token is valid.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tokenHelp(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _helpOpen = !_helpOpen),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  HugeIcon(
                    icon: AppIcons.help,
                    size: 20,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'How to generate a token',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurface,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _helpOpen ? 0.25 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: HugeIcon(
                      icon: AppIcons.chevronRight,
                      size: 18,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: AppMotion.emphasized,
            child: _helpOpen
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        _HelpStep(
                          n: 1,
                          text: 'Open Home Assistant in your browser.',
                        ),
                        _HelpStep(
                          n: 2,
                          text: 'Click your profile avatar (bottom-left).',
                        ),
                        _HelpStep(n: 3, text: 'Switch to the Security tab.'),
                        _HelpStep(
                          n: 4,
                          text:
                              'Scroll to Long-Lived Access Tokens → Create Token.',
                        ),
                        _HelpStep(
                          n: 5,
                          text:
                              'Name it (e.g. "Phone"), copy the token once, paste it above.',
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _bottomBar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
        color: scheme.surface,
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.m,
        AppSpacing.xxl,
        AppSpacing.l,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton(
            onPressed: _testResult == _TestResult.ok ? _save : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.button),
              ),
            ),
            child: const Text('Save & Continue'),
          ),
          TextButton(
            onPressed: () =>
                ref.read(previewModeProvider.notifier).state = true,
            child: const Text('Preview with demo data'),
          ),
        ],
      ),
    );
  }
}

class _HelpStep extends StatelessWidget {
  final int n;
  final String text;
  const _HelpStep({required this.n, required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(11),
            ),
            alignment: Alignment.center,
            child: Text(
              '$n',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.5,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

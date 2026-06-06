import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../config/app_icons.dart';
import '../config/images.dart';
import '../config/theme.dart';
import '../utils/snackbars.dart' show AppSnack;
import 'auth_screen.dart';
import 'root_gate.dart';

/// Landing screen — brand, tagline, and the two entry points (Sign in /
/// Register), with social links. Routes into [AuthScreen] for the actual form.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  void _openAuth(BuildContext context, {required bool signup}) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => AuthScreen(startWithSignUp: signup)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar — preview affordance (mirrors the reference's top chip).
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, AppSpacing.s, AppSpacing.l, 0),
                child: ActionChip(
                  avatar: HugeIcon(icon: AppIcons.eye, size: 16, color: scheme.onSurfaceVariant),
                  label: const Text('Preview'),
                  onPressed: () => ref.read(previewModeProvider.notifier).state = true,
                  backgroundColor: scheme.surfaceContainerHigh,
                  side: BorderSide(color: scheme.outlineVariant),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                child: Column(
                  children: [
                    const SizedBox(height: AppSpacing.xl),
                    Image.asset(Images.logo, fit: BoxFit.scaleDown, height: MediaQuery.of(context).size.height * 0.15),
                    const SizedBox(height: AppSpacing.xl),
                    // Brand: light top word + bold bottom word.
                    Text(
                      'SMART',
                      style: Theme.of(
                        context,
                      ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w300, letterSpacing: 6, color: scheme.onSurface),
                    ),
                    Text(
                      'POWER',
                      style: Theme.of(
                        context,
                      ).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 2, color: scheme.onSurface, height: 1.05),
                    ),
                    const SizedBox(height: AppSpacing.l),
                    _taglinePill(context, scheme),
                    const SizedBox(height: AppSpacing.xxl),

                    // Primary actions
                    _signInButton(context, scheme),
                    const SizedBox(height: AppSpacing.m),
                    _registerButton(context, scheme),
                    const SizedBox(height: AppSpacing.xl),

                    _orDivider(context, scheme),
                    const SizedBox(height: AppSpacing.l),
                    Text(
                      'Connect With Us',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: AppSpacing.m),
                    _socials(context, scheme),
                    const SizedBox(height: AppSpacing.l),
                  ],
                ),
              ),
            ),
            _footer(context, scheme),
          ],
        ),
      ),
    );
  }

  Widget _taglinePill(BuildContext context, ColorScheme scheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(color: scheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(28)),
      child: Text(
        'Your smart energy companion',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
      ),
    );
  }

  Widget _signInButton(BuildContext context, ColorScheme scheme) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: () => _openAuth(context, signup: false),
        icon: HugeIcon(icon: AppIcons.login, size: 22, color: scheme.onPrimary),
        label: const Text('Sign In'),
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.button)),
        ),
      ),
    );
  }

  Widget _registerButton(BuildContext context, ColorScheme scheme) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _openAuth(context, signup: true),
        icon: HugeIcon(icon: AppIcons.register, size: 22, color: scheme.primary),
        label: const Text('Register Account'),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          foregroundColor: scheme.primary,
          side: BorderSide(color: scheme.primary.withValues(alpha: 0.6)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.button)),
        ),
      ),
    );
  }

  Widget _orDivider(BuildContext context, ColorScheme scheme) {
    return Row(
      children: [
        Expanded(child: Divider(color: scheme.outlineVariant)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('OR', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant, letterSpacing: 1)),
        ),
        Expanded(child: Divider(color: scheme.outlineVariant)),
      ],
    );
  }

  Widget _socials(BuildContext context, ColorScheme scheme) {
    final items = <(dynamic, String)>[
      (AppIcons.instagram, 'Instagram'),
      (AppIcons.twitterX, 'X'),
      (AppIcons.facebook, 'Facebook'),
      (AppIcons.youtube, 'YouTube'),
      (AppIcons.whatsapp, 'WhatsApp'),
      (AppIcons.support, 'Support'),
    ];
    return Wrap(
      spacing: AppSpacing.s,
      runSpacing: AppSpacing.s,
      alignment: WrapAlignment.center,
      children: [
        for (final (icon, label) in items)
          Material(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => AppSnack.comingSoon(context, label),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: HugeIcon(icon: icon, size: 22, color: scheme.primary),
              ),
            ),
          ),
      ],
    );
  }

  Widget _footer(BuildContext context, ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s, top: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          HugeIcon(icon: HugeIcons.strokeRoundedCopyright, size: 12, color: scheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text('${DateTime.now().year} · Plug Assistance', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

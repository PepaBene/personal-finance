import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../core/l10n/generated/app_localizations.dart';
import '../../core/utils/error_text.dart';

/// Email + password sign-up / sign-in (FR-AUTH-01/02). Minimal Phase 0 surface;
/// OAuth, magic-link, MFA and password reset land later (docs/13 §6.1).
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _signUp = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = ref.read(authServiceProvider);
    try {
      if (_signUp) {
        await auth.signUp(email: _email.text.trim(), password: _password.text);
      } else {
        await auth.signIn(email: _email.text.trim(), password: _password.text);
      }
    } on Exception catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(context.space.lg),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: context.space.contentMaxWidth),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _BrandHero(
                    title: l10n.appTitle,
                    subtitle:
                        _signUp ? l10n.authSignUpTitle : l10n.authSignInTitle,
                  ),
                  SizedBox(height: context.space.xl),
                  AppCard(
                    padding: EdgeInsets.all(context.space.lg),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          decoration:
                              InputDecoration(labelText: l10n.authEmailLabel),
                        ),
                        SizedBox(height: context.space.md),
                        TextField(
                          controller: _password,
                          obscureText: true,
                          autofillHints: const [AutofillHints.password],
                          decoration: InputDecoration(
                            labelText: l10n.authPasswordLabel,
                          ),
                          onSubmitted: (_) => _busy ? null : _submit(),
                        ),
                        if (_error != null) ...[
                          SizedBox(height: context.space.md),
                          Text(
                            _error!,
                            style: context.texts.bodySmall?.copyWith(
                              color: context.semantic.danger,
                            ),
                          ),
                        ],
                        SizedBox(height: context.space.lg),
                        FilledButton(
                          onPressed: _busy ? null : _submit,
                          child: _busy
                              ? const ButtonSpinner()
                              : Text(
                                  _signUp
                                      ? l10n.authSignUpAction
                                      : l10n.authSignInAction,
                                ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: context.space.sm),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() => _signUp = !_signUp),
                    child: Text(
                      _signUp
                          ? l10n.authToggleToSignIn
                          : l10n.authToggleToSignUp,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Calm brand header: a soft hero band with the Ledgerly wordmark in the
/// Fraunces display serif, plus a contextual sign-in / sign-up subtitle.
class _BrandHero extends StatelessWidget {
  const _BrandHero({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: context.space.lg,
            vertical: context.space.xl,
          ),
          decoration: BoxDecoration(
            gradient: context.gradients.hero,
            borderRadius: context.radii.lgRadius,
            boxShadow: context.elevation.hero,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.account_balance_wallet_outlined,
                color: context.gradients.heroOn,
                size: context.space.xl,
              ),
              SizedBox(height: context.space.sm),
              Text(
                title,
                textAlign: TextAlign.center,
                style: context.texts.displaySmall?.copyWith(
                  color: context.gradients.heroOn,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: context.space.lg),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: context.texts.headlineSmall,
        ),
      ],
    );
  }
}

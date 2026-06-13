import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/glass_card.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _magicLinkSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    auth.clearError();
    await auth.signIn(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
  }

  Future<void> _sendMagicLink() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez saisir un email valide')),
      );
      return;
    }
    final auth = context.read<AuthProvider>();
    auth.clearError();
    await auth.sendMagicLink(email: email);
    if (mounted) {
      setState(() => _magicLinkSent = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: AppSpacing.screenPadding,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_outline,
                      size: 64, color: AppColors.primaryBlue),
                  const SizedBox(height: AppSpacing.lg),
                  Text('pLOCKet',
                      style: theme.textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w300, letterSpacing: 4)),
                  const SizedBox(height: AppSpacing.xxl),
                  GlassCard(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Connexion',
                              style: theme.textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w600)),
                          const SizedBox(height: AppSpacing.lg),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            autocorrect: false,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.email_outlined),
                              hintText: 'votre@email.com',
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Email requis';
                              }
                              if (!v.contains('@')) {
                                return 'Email invalide';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: 'Mot de passe',
                              prefixIcon: const Icon(Icons.lock_outlined),
                              suffixIcon: IconButton(
                                icon: Icon(_obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined),
                                onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Mot de passe requis';
                              }
                              return null;
                            },
                            onFieldSubmitted: (_) => _signIn(),
                          ),
                          if (auth.error != null) ...[
                            const SizedBox(height: AppSpacing.sm),
                            Container(
                              padding: const EdgeInsets.all(AppSpacing.sm),
                              decoration: BoxDecoration(
                                color: AppColors.accentRed.withValues(alpha: 0.1),
                                borderRadius:
                                    BorderRadius.circular(AppSpacing.radiusSm),
                              ),
                              child: Text(
                                auth.error!,
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(color: AppColors.accentRed),
                              ),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.lg),
                          FilledButton(
                            onPressed: auth.isLoading ? null : _signIn,
                            style: FilledButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: auth.isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text('Se connecter'),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Row(
                            children: [
                              const Expanded(child: Divider()),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                child: Text('ou',
                                    style: theme.textTheme.bodySmall
                                        ?.copyWith(color: AppColors.textTertiary)),
                              ),
                              const Expanded(child: Divider()),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          OutlinedButton.icon(
                            onPressed:
                                auth.isLoading ? null : _sendMagicLink,
                            icon: const Icon(Icons.email_outlined, size: 18),
                            label: const Text('Recevoir un lien magique'),
                          ),
                          if (_magicLinkSent) ...[
                            const SizedBox(height: AppSpacing.sm),
                            Container(
                              padding: const EdgeInsets.all(AppSpacing.sm),
                              decoration: BoxDecoration(
                                color: AppColors.accentGreen.withValues(alpha: 0.1),
                                borderRadius:
                                    BorderRadius.circular(AppSpacing.radiusSm),
                              ),
                              child: Text(
                                'Lien envoyé ! Vérifiez votre boîte mail.',
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(color: AppColors.accentGreen),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.lg),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const SignupScreen()),
                              );
                            },
                            child: const Text('Créer un compte'),
                          ),
                          TextButton(
                            onPressed: () => _showForgotPassword(context),
                            child: Text('Mot de passe oublié ?',
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(color: AppColors.textTertiary)),
                          ),
                        ],
                      ),
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

  void _showForgotPassword(BuildContext context) {
    final emailController = TextEditingController(text: _emailController.text);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface1,
        title: const Text('Mot de passe oublié'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Saisissez votre email pour recevoir un lien de réinitialisation.'),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              context
                  .read<AuthProvider>()
                  .resetPassword(email: emailController.text.trim());
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Email de réinitialisation envoyé')),
              );
            },
            child: const Text('Envoyer'),
          ),
        ],
      ),
    );
  }
}

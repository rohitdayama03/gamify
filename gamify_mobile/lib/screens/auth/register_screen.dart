import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/form_options.dart';
import '../../providers/auth_provider.dart';
import '../../providers/player_provider.dart';
import '../../widgets/primary_button.dart';
import '../onboarding/onboarding_screen.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _secretAnswerController = TextEditingController();
  String? _secretQuestion;
  bool _acceptedTerms = false;
  bool _obscurePassword = true;
  bool _submitted = false;

  // Errors the server reported for a specific field, e.g. "Username is already taken"
  String? _usernameServerError;
  String? _emailServerError;
  String? _formError;

  @override
  void dispose() {
    for (final c in [
      _usernameController,
      _emailController,
      _passwordController,
      _confirmController,
      _secretAnswerController,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _handleRegister() async {
    setState(() {
      _submitted = true;
      _usernameServerError = null;
      _emailServerError = null;
      _formError = null;
    });
    final valid = _formKey.currentState!.validate();
    if (!valid || !_acceptedTerms) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.register(
      username: _usernameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      secretQuestion: _secretQuestion!,
      secretAnswer: _secretAnswerController.text,
      acceptedTerms: _acceptedTerms,
    );
    if (!mounted) return;

    if (success) {
      await Provider.of<PlayerProvider>(
        context,
        listen: false,
      ).fetchMyProfile();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        (_) => false,
      );
      return;
    }

    final message =
        auth.errorMessage ?? 'Registration failed. Please try again.';
    final lower = message.toLowerCase();
    setState(() {
      if (lower.contains('username')) {
        _usernameServerError = message;
      } else if (lower.contains('email')) {
        _emailServerError = message;
      } else {
        _formError = message;
      }
    });
    _formKey.currentState!.validate();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                autovalidateMode: _submitted
                    ? AutovalidateMode.onUserInteraction
                    : AutovalidateMode.disabled,
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Create your account',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      const Text(
                        "You'll pick your games and set up a game profile next. You can skip anything optional.",
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      TextFormField(
                        controller: _usernameController,
                        autofillHints: const [AutofillHints.newUsername],
                        textInputAction: TextInputAction.next,
                        maxLength: 50,
                        onChanged: (_) {
                          if (_usernameServerError != null) {
                            setState(() => _usernameServerError = null);
                          }
                        },
                        decoration: const InputDecoration(
                          labelText: 'Username',
                          prefixIcon: Icon(Icons.person_outline),
                          helperText: 'This is how other players find you.',
                          counterText: '',
                        ),
                        validator: (v) {
                          final value = v?.trim() ?? '';
                          if (value.isEmpty) return 'Choose a username';
                          if (value.length < 3) {
                            return 'Username must be at least 3 characters';
                          }
                          return _usernameServerError;
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        textInputAction: TextInputAction.next,
                        onChanged: (_) {
                          if (_emailServerError != null) {
                            setState(() => _emailServerError = null);
                          }
                        },
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.mail_outline),
                        ),
                        validator: (v) {
                          final value = v?.trim() ?? '';
                          if (value.isEmpty) return 'Enter your email';
                          if (!_emailPattern.hasMatch(value)) {
                            return 'Enter a valid email, like name@example.com';
                          }
                          return _emailServerError;
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        autofillHints: const [AutofillHints.newPassword],
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          helperText: 'At least 6 characters.',
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            tooltip: _obscurePassword
                                ? 'Show passwords'
                                : 'Hide passwords',
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Create a password';
                          }
                          if (v.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _confirmController,
                        obscureText: _obscurePassword,
                        autofillHints: const [AutofillHints.newPassword],
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Confirm password',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Re-enter your password';
                          }
                          if (v != _passwordController.text) {
                            return "Passwords don't match";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Account recovery',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "Used to reset your password if you forget it. Answers aren't case-sensitive.",
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      DropdownButtonFormField<String>(
                        initialValue: _secretQuestion,
                        isExpanded: true,
                        dropdownColor: AppColors.surfaceAlt,
                        decoration: const InputDecoration(
                          labelText: 'Security question',
                          prefixIcon: Icon(Icons.shield_outlined),
                        ),
                        items: [
                          for (final question in FormOptions.securityQuestions)
                            DropdownMenuItem(
                              value: question,
                              child: Text(
                                question,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (value) =>
                            setState(() => _secretQuestion = value),
                        validator: (v) =>
                            v == null ? 'Choose a security question' : null,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _secretAnswerController,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          labelText: 'Your answer',
                          prefixIcon: Icon(Icons.key_outlined),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Enter an answer you will remember'
                            : null,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _TermsCheckbox(
                        value: _acceptedTerms,
                        showError: _submitted && !_acceptedTerms,
                        onChanged: (v) => setState(() => _acceptedTerms = v),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (_formError != null) ...[
                        MessageBanner(message: _formError!),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      PrimaryButton(
                        label: 'Create account',
                        loading: auth.isLoading,
                        onPressed: _handleRegister,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Flexible(
                            child: Text(
                              'Already have an account?',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const LoginScreen(),
                              ),
                            ),
                            child: const Text('Sign in'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TermsCheckbox extends StatelessWidget {
  final bool value;
  final bool showError;
  final ValueChanged<bool> onChanged;

  const _TermsCheckbox({
    required this.value,
    required this.showError,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MergeSemantics(
          child: InkWell(
            onTap: () => onChanged(!value),
            borderRadius: BorderRadius.circular(AppRadius.input),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Checkbox(
                    value: value,
                    onChanged: (v) => onChanged(v ?? false),
                  ),
                  const Expanded(
                    child: Text(
                      'I agree to the GAMIFY terms and community guidelines, and confirm I am old enough to use the games I add.',
                      style: TextStyle(fontSize: 13.5, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showError)
          const Padding(
            padding: EdgeInsets.only(left: AppSpacing.md),
            child: Text(
              'Please accept to create your account',
              style: TextStyle(color: AppColors.error, fontSize: 12.5),
            ),
          ),
      ],
    );
  }
}

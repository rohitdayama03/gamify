import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/form_options.dart';
import '../../models/auth_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/player_provider.dart';
import '../../widgets/primary_button.dart';
import '../onboarding/onboarding_screen.dart';
import 'login_screen.dart';
import 'otp_widgets.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  String _dialCode = FormOptions.dialCodes.first.code;
  bool _acceptedTerms = false;
  bool _submitted = false;
  // Set once a code is sent; the screen then asks for the code
  OtpSent? _otpSent;

  // Errors the server reported for a specific field, e.g. "Username is already taken"
  String? _usernameServerError;
  String? _phoneServerError;
  String? _formError;

  @override
  void dispose() {
    for (final c in [_usernameController, _phoneController, _codeController]) {
      c.dispose();
    }
    super.dispose();
  }

  String get _phoneNumber =>
      PhoneNumberField.fullNumber(_dialCode, _phoneController.text);

  void _clearErrors() {
    _usernameServerError = null;
    _phoneServerError = null;
    _formError = null;
  }

  Future<void> _sendCode() async {
    setState(() {
      _submitted = true;
      _clearErrors();
    });
    final valid = _formKey.currentState!.validate();
    if (!valid || !_acceptedTerms) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final sent = await auth.sendOtp(
      phoneNumber: _phoneNumber,
      purpose: OtpPurpose.register,
      username: _usernameController.text.trim(),
    );
    if (!mounted) return;
    if (sent != null) {
      setState(() {
        _otpSent = sent;
        _submitted = false;
        _codeController.clear();
      });
    } else {
      _showServerError(auth.errorMessage ?? 'Could not send the code.');
    }
  }

  Future<void> _resend() async {
    setState(_clearErrors);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final sent = await auth.resendOtp(
      _otpSent!,
      phoneNumber: _phoneNumber,
      purpose: OtpPurpose.register,
      username: _usernameController.text.trim(),
    );
    if (!mounted) return;
    if (sent != null) {
      setState(() {
        _otpSent = sent;
        _codeController.clear();
      });
    } else {
      _showServerError(auth.errorMessage ?? 'Could not resend the code.');
    }
  }

  Future<void> _handleRegister() async {
    setState(() {
      _submitted = true;
      _clearErrors();
    });
    if (!_formKey.currentState!.validate()) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.register(
      username: _usernameController.text.trim(),
      phoneNumber: _phoneNumber,
      sent: _otpSent!,
      otp: _codeController.text,
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

    _showServerError(
      auth.errorMessage ?? 'Registration failed. Please try again.',
    );
  }

  // Shows a field's error under that field, going back to the details step if the code step is open
  void _showServerError(String message) {
    final lower = message.toLowerCase();
    final isCodeError = lower.contains('code');
    setState(() {
      if (!isCodeError) _otpSent = null;
      if (isCodeError) {
        _formError = message;
      } else if (lower.contains('username')) {
        _usernameServerError = message;
      } else if (lower.contains('phone')) {
        _phoneServerError = message;
      } else {
        _formError = message;
      }
    });
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _formKey.currentState?.validate(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final otpSent = _otpSent;

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
                        otpSent == null
                            ? 'Create your account'
                            : 'Verify your number',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      if (otpSent == null) ...[
                        const Text(
                          "You'll pick your games and set up a game profile next. You can skip anything optional.",
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        ..._detailsFields(),
                      ] else ...[
                        const SizedBox(height: AppSpacing.md),
                        OtpCodeStep(
                          phoneNumber:
                              '$_dialCode ${_phoneController.text.trim()}',
                          controller: _codeController,
                          remainingToday: otpSent.remainingToday,
                          busy: auth.isLoading,
                          onCompleted: (_) => _handleRegister(),
                          onResend: _resend,
                          onChangeNumber: () => setState(() {
                            _otpSent = null;
                            _submitted = false;
                            _clearErrors();
                          }),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      if (_formError != null) ...[
                        MessageBanner(message: _formError!),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      PrimaryButton(
                        label: otpSent == null ? 'Send code' : 'Create account',
                        loading: auth.isLoading,
                        onPressed: otpSent == null
                            ? _sendCode
                            : _handleRegister,
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

  List<Widget> _detailsFields() => [
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
    PhoneNumberField(
      dialCode: _dialCode,
      onDialCodeChanged: (code) => setState(() => _dialCode = code),
      controller: _phoneController,
      serverError: _phoneServerError,
      onChanged: (_) {
        if (_phoneServerError != null) {
          setState(() => _phoneServerError = null);
        }
      },
    ),
    const Padding(
      padding: EdgeInsets.only(top: 6, left: AppSpacing.sm),
      child: Text(
        "You'll sign in with a code we send to this number.",
        style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
      ),
    ),
    const SizedBox(height: AppSpacing.md),
    _TermsCheckbox(
      value: _acceptedTerms,
      showError: _submitted && !_acceptedTerms,
      onChanged: (v) => setState(() => _acceptedTerms = v),
    ),
  ];
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

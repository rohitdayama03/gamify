import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/form_options.dart';
import '../../models/auth_model.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/primary_button.dart';
import '../start_screen.dart';
import 'otp_widgets.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  String _dialCode = FormOptions.dialCodes.first.code;
  // Set once a code is sent; the screen then asks for the code
  OtpSent? _otpSent;
  bool _submitted = false;
  String? _error;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  String get _phoneNumber =>
      PhoneNumberField.fullNumber(_dialCode, _phoneController.text);

  Future<void> _sendCode() async {
    setState(() {
      _submitted = true;
      _error = null;
    });
    if (!_formKey.currentState!.validate()) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final sent = await auth.sendOtp(
      phoneNumber: _phoneNumber,
      purpose: OtpPurpose.login,
    );
    if (!mounted) return;
    setState(() {
      if (sent != null) {
        _otpSent = sent;
        _submitted = false;
        _codeController.clear();
      } else {
        _error = auth.errorMessage ?? 'Could not send the code.';
      }
    });
  }

  Future<void> _resend() async {
    setState(() => _error = null);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final sent = await auth.resendOtp(
      _otpSent!,
      phoneNumber: _phoneNumber,
      purpose: OtpPurpose.login,
    );
    if (!mounted) return;
    setState(() {
      if (sent != null) {
        _otpSent = sent;
        _codeController.clear();
      } else {
        _error = auth.errorMessage ?? 'Could not resend the code.';
      }
    });
  }

  Future<void> _verify() async {
    setState(() {
      _submitted = true;
      _error = null;
    });
    if (!_formKey.currentState!.validate()) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.login(
      phoneNumber: _phoneNumber,
      sent: _otpSent!,
      otp: _codeController.text,
    );
    if (!mounted) return;

    if (success) {
      // StartScreen loads the profile and routes to onboarding or Home
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const StartScreen()),
        (_) => false,
      );
    } else {
      setState(
        () => _error = auth.errorMessage ?? 'Sign in failed. Please try again.',
      );
    }
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
                        'Welcome back',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      const Text(
                        "Sign in with your phone number. We'll send you a code.",
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      if (otpSent == null)
                        PhoneNumberField(
                          dialCode: _dialCode,
                          onDialCodeChanged: (code) =>
                              setState(() => _dialCode = code),
                          controller: _phoneController,
                          onSubmitted: (_) => _sendCode(),
                        )
                      else
                        OtpCodeStep(
                          phoneNumber:
                              '$_dialCode ${_phoneController.text.trim()}',
                          controller: _codeController,
                          remainingToday: otpSent.remainingToday,
                          busy: auth.isLoading,
                          onCompleted: (_) => _verify(),
                          onResend: _resend,
                          onChangeNumber: () => setState(() {
                            _otpSent = null;
                            _error = null;
                            _submitted = false;
                          }),
                        ),
                      const SizedBox(height: AppSpacing.md),
                      if (_error != null) ...[
                        MessageBanner(message: _error!),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      PrimaryButton(
                        label: otpSent == null ? 'Send code' : 'Sign in',
                        loading: auth.isLoading,
                        onPressed: otpSent == null ? _sendCode : _verify,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Flexible(
                            child: Text(
                              'New to GAMIFY?',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const RegisterScreen(),
                              ),
                            ),
                            child: const Text('Create account'),
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

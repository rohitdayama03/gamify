import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/form_options.dart';

/// Phone number with a country calling code picker. [fullNumber] gives the E.164 form the server expects.
class PhoneNumberField extends StatelessWidget {
  final String dialCode;
  final ValueChanged<String> onDialCodeChanged;
  final TextEditingController controller;
  final String? serverError;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction textInputAction;

  const PhoneNumberField({
    super.key,
    required this.dialCode,
    required this.onDialCodeChanged,
    required this.controller,
    this.serverError,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction = TextInputAction.done,
  });

  /// "+91" and "98765 43210" become "+919876543210"
  static String fullNumber(String dialCode, String number) =>
      dialCode + number.replaceAll(RegExp(r'\D'), '');

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 104,
          child: DropdownButtonFormField<String>(
            initialValue: dialCode,
            isExpanded: true,
            dropdownColor: AppColors.surfaceAlt,
            decoration: const InputDecoration(labelText: 'Code'),
            selectedItemBuilder: (_) => [
              for (final d in FormOptions.dialCodes) Text(d.code),
            ],
            items: [
              for (final d in FormOptions.dialCodes)
                DropdownMenuItem(
                  value: d.code,
                  child: Text(
                    '${d.code}  ${d.country}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (v) => onDialCodeChanged(v ?? dialCode),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: TextFormField(
            controller: controller,
            keyboardType: TextInputType.phone,
            autofillHints: const [AutofillHints.telephoneNumberNational],
            textInputAction: textInputAction,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d ]')),
              LengthLimitingTextInputFormatter(15),
            ],
            onChanged: onChanged,
            onFieldSubmitted: onSubmitted,
            decoration: const InputDecoration(
              labelText: 'WhatsApp number',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
            validator: (v) {
              final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
              if (digits.isEmpty) return 'Enter your phone number';
              if (digits.length < 7) return 'Enter a valid phone number';
              return serverError;
            },
          ),
        ),
      ],
    );
  }
}

/// Second step of sign-in: the code sent on WhatsApp, with resend and change-number links.
class OtpCodeStep extends StatefulWidget {
  final String phoneNumber;
  final TextEditingController controller;
  final int remainingToday;
  final bool busy;
  final ValueChanged<String> onCompleted;
  final Future<void> Function() onResend;
  final VoidCallback onChangeNumber;

  const OtpCodeStep({
    super.key,
    required this.phoneNumber,
    required this.controller,
    required this.remainingToday,
    required this.busy,
    required this.onCompleted,
    required this.onResend,
    required this.onChangeNumber,
  });

  static const int codeLength = 6;

  @override
  State<OtpCodeStep> createState() => _OtpCodeStepState();
}

class _OtpCodeStepState extends State<OtpCodeStep> {
  // Keeps players from burning through the daily code limit by tapping Resend repeatedly
  static const int _resendDelaySeconds = 30;

  Timer? _timer;
  int _secondsLeft = _resendDelaySeconds;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _secondsLeft = _resendDelaySeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft <= 1) timer.cancel();
      setState(() => _secondsLeft--);
    });
  }

  Future<void> _resend() async {
    await widget.onResend();
    if (mounted) _startCountdown();
  }

  @override
  Widget build(BuildContext context) {
    final canResend =
        _secondsLeft <= 0 && widget.remainingToday > 0 && !widget.busy;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text.rich(
                TextSpan(
                  text:
                      'We sent a ${OtpCodeStep.codeLength}-digit code on WhatsApp to ',
                  children: [
                    TextSpan(
                      text: widget.phoneNumber,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ),
            TextButton(
              onPressed: widget.busy ? null : widget.onChangeNumber,
              child: const Text('Change'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        TextFormField(
          controller: widget.controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          autofillHints: const [AutofillHints.oneTimeCode],
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: 12,
          ),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(OtpCodeStep.codeLength),
          ],
          decoration: const InputDecoration(
            hintText: '––––––',
            counterText: '',
          ),
          onChanged: (v) {
            if (v.length == OtpCodeStep.codeLength) widget.onCompleted(v);
          },
          validator: (v) => (v ?? '').length == OtpCodeStep.codeLength
              ? null
              : 'Enter the ${OtpCodeStep.codeLength}-digit code',
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                widget.remainingToday == 0
                    ? 'No more codes today for this number'
                    : _secondsLeft > 0
                    ? 'Resend in ${_secondsLeft}s'
                    : "Didn't get it?",
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            TextButton(
              onPressed: canResend ? _resend : null,
              child: Text(
                widget.remainingToday == 1
                    ? 'Resend (1 left today)'
                    : 'Resend code',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// lib/features/auth/otp_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';

class OtpScreen extends StatefulWidget {
  final String phone;
  const OtpScreen({super.key, required this.phone});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final List<TextEditingController> _ctrs =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  int _resendCountdown = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendCountdown == 0) {
        t.cancel();
      } else {
        setState(() => _resendCountdown--);
      }
    });
  }

  String get _otp => _ctrs.map((c) => c.text).join();

  void _onDigitEntered(int index, String value) {
    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    if (_otp.length == 6) _verifyOtp();
  }

  void _verifyOtp() {
    // TODO: Call OTP verification API
    debugPrint('OTP entered: $_otp');
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _ctrs) c.dispose();
    for (final f in _focusNodes) f.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Verify OTP')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter the 6-digit code\nsent to ${widget.phone}',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 36),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(6, (i) => _OtpDigitBox(
                controller: _ctrs[i],
                focusNode: _focusNodes[i],
                onChanged: (v) => _onDigitEntered(i, v),
                onBackspace: () {
                  if (_ctrs[i].text.isEmpty && i > 0) {
                    _focusNodes[i - 1].requestFocus();
                  }
                },
              )),
            ),
            const SizedBox(height: 32),
            Center(
              child: _resendCountdown > 0
                  ? Text(
                      'Resend in ${_resendCountdown}s',
                      style: const TextStyle(color: AppColors.textSecondary),
                    )
                  : TextButton(
                      onPressed: () {
                        setState(() => _resendCountdown = 60);
                        _startTimer();
                      },
                      child: const Text('Resend OTP'),
                    ),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: _otp.length == 6 ? _verifyOtp : null,
              child: const Text('Verify'),
            ),
          ],
        ),
      ),
    );
  }
}

class _OtpDigitBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onBackspace;

  const _OtpDigitBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onBackspace,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 46,
      height: 54,
      child: RawKeyboardListener(
        focusNode: FocusNode(),
        onKey: (event) {
          if (event.logicalKey == LogicalKeyboardKey.backspace) {
            onBackspace();
          }
        },
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          maxLength: 1,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            counterText: '',
            contentPadding: EdgeInsets.zero,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.divider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
          ),
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

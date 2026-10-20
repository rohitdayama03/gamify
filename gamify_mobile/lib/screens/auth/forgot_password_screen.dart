import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _usernameController = TextEditingController();
  final _answerController = TextEditingController();
  final _newPasswordController = TextEditingController();

  String? _question;
  bool _stepOneCompleted = false;

  void _getQuestion() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final res = await auth.getSecretQuestion(_usernameController.text.trim());
    if (res != null) {
      setState(() {
        _question = res.secretQuestion;
        _stepOneCompleted = true;
      });
    }
  }

  void _resetPassword() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.resetPassword(
      _usernameController.text.trim(),
      _answerController.text.trim(),
      _newPasswordController.text,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password Reset Successful! Please Login.')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            TextField(
              controller: _usernameController,
              enabled: !_stepOneCompleted,
              decoration: const InputDecoration(labelText: 'Username', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            if (!_stepOneCompleted)
              ElevatedButton(
                onPressed: _getQuestion,
                child: const Text('Get Secret Question'),
              ),
            if (_stepOneCompleted) ...[
              Text('Security Question: $_question', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 16),
              TextField(controller: _answerController, decoration: const InputDecoration(labelText: 'Secret Answer', border: OutlineInputBorder())),
              const SizedBox(height: 16),
              TextField(controller: _newPasswordController, obscureText: true, decoration: const InputDecoration(labelText: 'New Password', border: OutlineInputBorder())),
              const SizedBox(height: 24),
              auth.isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50), backgroundColor: AppColors.primary),
                      onPressed: _resetPassword,
                      child: const Text('Submit New Password', style: TextStyle(color: Colors.white)),
                    ),
            ]
          ],
        ),
      ),
    );
  }
}
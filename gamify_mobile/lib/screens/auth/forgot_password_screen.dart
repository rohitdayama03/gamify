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
  final _confirmPasswordController = TextEditingController();

  String? _question;
  bool _stepOneCompleted = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _answerController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _getQuestion() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty) {
      _showMessage('Please enter your username');
      return;
    }
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final res = await auth.getSecretQuestion(username);
    if (!mounted) return;
    if (res != null) {
      setState(() {
        _question = res.secretQuestion;
        _stepOneCompleted = true;
      });
    } else {
      _showMessage(auth.errorMessage ?? 'User not found');
    }
  }

  void _resetPassword() async {
    if (_answerController.text.trim().isEmpty) {
      _showMessage('Please enter your answer');
      return;
    }
    if (_newPasswordController.text.length < 6) {
      _showMessage('New password must be at least 6 characters');
      return;
    }
    if (_newPasswordController.text != _confirmPasswordController.text) {
      _showMessage('Passwords do not match');
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.resetPassword(
      _usernameController.text.trim(),
      _answerController.text.trim(),
      _newPasswordController.text,
    );
    if (!mounted) return;

    if (success) {
      _showMessage('Password Reset Successful! Please Login.');
      Navigator.pop(context);
    } else {
      _showMessage(auth.errorMessage ?? 'Password reset failed');
    }
  }

  // Go back to step one, e.g. if the wrong username was entered
  void _changeUsername() {
    setState(() {
      _stepOneCompleted = false;
      _question = null;
      _answerController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _usernameController,
              enabled: !_stepOneCompleted,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _getQuestion(),
              decoration: InputDecoration(
                labelText: 'Username',
                border: const OutlineInputBorder(),
                suffixIcon: _stepOneCompleted
                    ? IconButton(icon: const Icon(Icons.edit), tooltip: 'Change username', onPressed: _changeUsername)
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            if (!_stepOneCompleted)
              auth.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50), backgroundColor: AppColors.primary),
                      onPressed: _getQuestion,
                      child: const Text('Get Security Question', style: TextStyle(color: Colors.white)),
                    ),
            if (_stepOneCompleted) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Security Question', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(_question ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(controller: _answerController, decoration: const InputDecoration(labelText: 'Your Answer', border: OutlineInputBorder())),
              const SizedBox(height: 16),
              TextField(controller: _newPasswordController, obscureText: true, decoration: const InputDecoration(labelText: 'New Password', border: OutlineInputBorder())),
              const SizedBox(height: 16),
              TextField(controller: _confirmPasswordController, obscureText: true, decoration: const InputDecoration(labelText: 'Confirm New Password', border: OutlineInputBorder())),
              const SizedBox(height: 24),
              auth.isLoading
                  ? const Center(child: CircularProgressIndicator())
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

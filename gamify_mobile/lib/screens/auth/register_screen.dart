import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../profile/profile_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _bioController = TextEditingController();
  final _languageController = TextEditingController();
  final _countryController = TextEditingController();
  final _secretQuestionController = TextEditingController();
  final _secretAnswerController = TextEditingController();

  void _handleRegister() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.register(
      username: _usernameController.text.trim(),
      password: _passwordController.text,
      playerBio: _bioController.text,
      language: _languageController.text,
      country: _countryController.text,
      secretQuestion: _secretQuestionController.text,
      secretAnswer: _secretAnswerController.text,
    );

    if (success && mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const ProfileScreen()),
        (route) => false,
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.errorMessage ?? 'Registration Failed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Create Gamer Account')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            TextField(controller: _usernameController, decoration: const InputDecoration(labelText: 'Username *', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: _passwordController, obscureText: true, decoration: const InputDecoration(labelText: 'Password *', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: _bioController, decoration: const InputDecoration(labelText: 'Bio', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: _languageController, decoration: const InputDecoration(labelText: 'Language (e.g. English)', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: _countryController, decoration: const InputDecoration(labelText: 'Country (e.g. India)', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: _secretQuestionController, decoration: const InputDecoration(labelText: 'Secret Security Question *', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: _secretAnswerController, decoration: const InputDecoration(labelText: 'Secret Answer *', border: OutlineInputBorder())),
            const SizedBox(height: 24),
            auth.isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50), backgroundColor: AppColors.primary),
                    onPressed: _handleRegister,
                    child: const Text('Register Account', style: TextStyle(color: Colors.white)),
                  ),
          ],
        ),
      ),
    );
  }
}
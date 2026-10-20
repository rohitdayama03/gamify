import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/form_options.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/country_dropdown.dart';
import '../../widgets/multi_select_autocomplete.dart';
import '../main/main_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _bioController = TextEditingController();
  final _secretAnswerController = TextEditingController();
  List<String> _languages = [];
  String? _country;
  String? _secretQuestion;

  void _handleRegister() async {
    if (_secretQuestion == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose a security question')),
      );
      return;
    }
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.register(
      username: _usernameController.text.trim(),
      password: _passwordController.text,
      playerBio: _bioController.text,
      language: FormOptions.joinLanguages(_languages),
      country: _country,
      secretQuestion: _secretQuestion!,
      secretAnswer: _secretAnswerController.text,
    );

    if (success && mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainScreen()),
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
            MultiSelectAutocomplete(
              label: 'Languages',
              options: FormOptions.languages,
              selected: _languages,
              maxSelections: FormOptions.maxLanguages,
              onChanged: (value) => setState(() => _languages = value),
            ),
            const SizedBox(height: 12),
            CountryDropdown(value: _country, onChanged: (value) => setState(() => _country = value)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _secretQuestion,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Security Question *', border: OutlineInputBorder()),
              items: [
                for (final question in FormOptions.securityQuestions)
                  DropdownMenuItem(value: question, child: Text(question, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (value) => setState(() => _secretQuestion = value),
            ),
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
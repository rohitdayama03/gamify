import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/form_options.dart';
import '../../providers/player_provider.dart';
import '../../widgets/country_dropdown.dart';
import '../../widgets/multi_select_autocomplete.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _bio = TextEditingController();
  List<String> _languages = [];
  String? _country;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = Provider.of<PlayerProvider>(context, listen: false).currentPlayer;
    _bio.text = p?.playerBio ?? '';
    _country = p?.country == null || p!.country!.isEmpty ? null : p.country;
    _languages = FormOptions.splitLanguages(p?.language);
  }

  @override
  void dispose() {
    _bio.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final provider = Provider.of<PlayerProvider>(context, listen: false);
    final ok = await provider.updateProfile({
      'playerBio': _bio.text.trim(),
      'country': _country ?? '',
      'language': FormOptions.joinLanguages(_languages),
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(provider.errorMessage ?? 'Update failed')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final username = Provider.of<PlayerProvider>(context, listen: false).currentPlayer?.username ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // The backend does not support changing usernames
            TextFormField(
              initialValue: username,
              enabled: false,
              decoration: const InputDecoration(labelText: 'Username', helperText: 'Username cannot be changed'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bio,
              maxLines: 4,
              maxLength: 500,
              decoration: const InputDecoration(labelText: 'Bio', alignLabelWithHint: true),
            ),
            const SizedBox(height: 12),
            CountryDropdown(value: _country, onChanged: (value) => setState(() => _country = value)),
            const SizedBox(height: 12),
            MultiSelectAutocomplete(
              label: 'Languages',
              options: FormOptions.languages,
              selected: _languages,
              maxSelections: FormOptions.maxLanguages,
              onChanged: (value) => setState(() => _languages = value),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50), backgroundColor: AppColors.primary),
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onPrimary))
                  : const Text('Save', style: TextStyle(color: AppColors.onPrimary)),
            ),
          ],
        ),
      ),
    );
  }
}

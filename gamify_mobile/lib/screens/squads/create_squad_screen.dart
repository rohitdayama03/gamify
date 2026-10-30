import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/connection_provider.dart';
import '../../providers/squad_provider.dart';
import '../../widgets/primary_button.dart';
import '../messages/chat_screen.dart';
import 'friend_picker.dart';

/// Name a new squad and pick friends to invite; opens the squad chat once it's created.
class CreateSquadScreen extends StatefulWidget {
  const CreateSquadScreen({super.key});

  @override
  State<CreateSquadScreen> createState() => _CreateSquadScreenState();
}

class _CreateSquadScreenState extends State<CreateSquadScreen> {
  // Same rule as the backend: 3-30 letters, numbers, spaces, - and _
  static final RegExp _allowed = RegExp(r'^[A-Za-z0-9 _-]+$');

  final _nameController = TextEditingController();
  Set<int> _selected = {};
  bool _creating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() => setState(() => _error = null));
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String get _name => _nameController.text.trim().replaceAll(RegExp(r'\s+'), ' ');

  String? get _nameProblem {
    final name = _name;
    if (name.isEmpty) return null;
    if (!_allowed.hasMatch(name)) return 'Use letters, numbers, spaces, - and _ only';
    if (name.length < 3) return 'At least 3 characters';
    return null;
  }

  Future<void> _create() async {
    if (_name.length < 3 || _nameProblem != null || _creating) return;
    setState(() => _creating = true);
    final provider = Provider.of<SquadProvider>(context, listen: false);
    final squad = await provider.createSquad(_name, _selected.toList());
    if (!mounted) return;
    setState(() => _creating = false);
    if (squad == null) {
      setState(() => _error = provider.errorMessage ?? 'Could not create the squad');
      return;
    }
    final invited = _selected.length;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => ChatScreen.squad(squadId: squad.id, squadName: squad.name)),
    );
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(invited == 0
          ? '${squad.name} created'
          : '${squad.name} created. Invited $invited friend${invited == 1 ? '' : 's'}.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final friends = Provider.of<ConnectionProvider>(context).friends;
    final problem = _nameProblem;
    final canCreate = _name.length >= 3 && problem == null;

    return Scaffold(
      appBar: AppBar(title: const Text('New squad')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: TextField(
              controller: _nameController,
              autofocus: true,
              maxLength: 30,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _create(),
              decoration: InputDecoration(
                labelText: 'Squad name',
                helperText: 'Must be unique across GAMIFY',
                errorText: problem ?? _error,
                prefixIcon: const Icon(Icons.groups_outlined),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Text(
              _selected.isEmpty ? 'INVITE FRIENDS (OPTIONAL)' : 'INVITE FRIENDS · ${_selected.length} SELECTED',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.6),
            ),
          ),
          Expanded(
            child: FriendPicker(
              friends: friends,
              selected: _selected,
              onChanged: (next) => setState(() => _selected = next),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: PrimaryButton(
                label: 'Create squad',
                icon: Icons.group_add,
                loading: _creating,
                onPressed: canCreate ? _create : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

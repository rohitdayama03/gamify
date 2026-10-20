import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/player_provider.dart';

class EditGameProfilesScreen extends StatefulWidget {
  final int initialTab;
  const EditGameProfilesScreen({super.key, this.initialTab = 0});

  @override
  State<EditGameProfilesScreen> createState() => _EditGameProfilesScreenState();
}

class _EditGameProfilesScreenState extends State<EditGameProfilesScreen> {
  final _bgmiId = TextEditingController();
  final _role = TextEditingController();
  final _exp = TextEditingController();
  final _time = TextEditingController();
  final _achievements = TextEditingController();
  final _lookingFor = TextEditingController();

  final _efootballId = TextEditingController();
  final _highTier = TextEditingController();

  @override
  void initState() {
    super.initState();
    final p = Provider.of<PlayerProvider>(context, listen: false).currentPlayer;
    if (p?.bgmiProfile != null) {
      _bgmiId.text = p!.bgmiProfile!.bgmiId;
      _role.text = p.bgmiProfile!.currentRole ?? '';
      _exp.text = p.bgmiProfile!.experience ?? '';
      _time.text = p.bgmiProfile!.availableTime ?? '';
      _achievements.text = p.bgmiProfile!.achievements ?? '';
      _lookingFor.text = p.bgmiProfile!.lookingFor ?? '';
    }
    if (p?.efootballProfile != null) {
      _efootballId.text = p!.efootballProfile!.efootballId;
      _highTier.text = p.efootballProfile!.highTier ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final playerProvider = Provider.of<PlayerProvider>(context);

    return DefaultTabController(
      initialIndex: widget.initialTab,
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Edit Game Profiles'),
          bottom: const TabBar(tabs: [Tab(text: 'BGMI'), Tab(text: 'E-Football')]),
        ),
        body: TabBarView(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    TextField(controller: _bgmiId, decoration: const InputDecoration(labelText: 'BGMI In-Game ID *', border: OutlineInputBorder())),
                    const SizedBox(height: 12),
                    TextField(controller: _role, decoration: const InputDecoration(labelText: 'Current Role (e.g. IGL, Assaulter)', border: OutlineInputBorder())),
                    const SizedBox(height: 12),
                    TextField(controller: _exp, decoration: const InputDecoration(labelText: 'Experience (e.g. 2 Years)', border: OutlineInputBorder())),
                    const SizedBox(height: 12),
                    TextField(controller: _time, decoration: const InputDecoration(labelText: 'Available Time (e.g. 8 PM - 11 PM)', border: OutlineInputBorder())),
                    const SizedBox(height: 12),
                    TextField(controller: _achievements, decoration: const InputDecoration(labelText: 'Achievements', border: OutlineInputBorder())),
                    const SizedBox(height: 12),
                    TextField(controller: _lookingFor, decoration: const InputDecoration(labelText: 'Looking For (e.g. Esports Squad)', border: OutlineInputBorder())),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50), backgroundColor: AppColors.primary),
                      onPressed: () async {
                        final ok = await playerProvider.updateBgmiProfile({
                          'bgmiId': _bgmiId.text,
                          'currentRole': _role.text,
                          'experience': _exp.text,
                          'availableTime': _time.text,
                          'achievements': _achievements.text,
                          'lookingFor': _lookingFor.text,
                        });
                        if (ok && mounted) Navigator.pop(context);
                      },
                      child: const Text('Save BGMI Profile', style: TextStyle(color: Colors.white)),
                    )
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextField(controller: _efootballId, decoration: const InputDecoration(labelText: 'E-Football ID *', border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  TextField(controller: _highTier, decoration: const InputDecoration(labelText: 'Highest Tier (e.g. Div 1)', border: OutlineInputBorder())),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50), backgroundColor: AppColors.primary),
                    onPressed: () async {
                      final ok = await playerProvider.updateEfootballProfile({
                        'efootballId': _efootballId.text,
                        'highTier': _highTier.text,
                      });
                      if (ok && mounted) Navigator.pop(context);
                    },
                    child: const Text('Save E-Football Profile', style: TextStyle(color: Colors.white)),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
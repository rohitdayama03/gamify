import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/player_provider.dart';
import '../auth/login_screen.dart';
import '../search/search_players_screen.dart';
import 'edit_game_profiles_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<PlayerProvider>(context, listen: false).fetchMyProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    final playerProvider = Provider.of<PlayerProvider>(context);
    final player = playerProvider.currentPlayer;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Player Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchPlayersScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await Provider.of<AuthProvider>(context, listen: false).logout();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (r) => false);
              }
            },
          )
        ],
      ),
      body: playerProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : player == null
              ? const Center(child: Text('No Profile Found'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Card(
                        color: AppColors.cardBackground,
                        child: ListTile(
                          leading: const CircleAvatar(backgroundColor: AppColors.primary, child: Icon(Icons.person, color: Colors.white)),
                          title: Text(player.username, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                          subtitle: Text('${player.country ?? "N/A"} | ${player.language ?? "N/A"}\n${player.playerBio ?? "No Bio"}'),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('BGMI Profile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          TextButton(
                            child: const Text('Edit BGMI'),
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditGameProfilesScreen(initialTab: 0))),
                          )
                        ],
                      ),
                      _buildGameCard(
                        title: 'BGMI ID: ${player.bgmiProfile?.bgmiId ?? "Not Setup"}',
                        details: 'Role: ${player.bgmiProfile?.currentRole ?? "N/A"}\nExp: ${player.bgmiProfile?.experience ?? "N/A"}\nLooking For: ${player.bgmiProfile?.lookingFor ?? "N/A"}',
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('E-Football Profile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          TextButton(
                            child: const Text('Edit E-Football'),
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditGameProfilesScreen(initialTab: 1))),
                          )
                        ],
                      ),
                      _buildGameCard(
                        title: 'E-Football ID: ${player.efootballProfile?.efootballId ?? "Not Setup"}',
                        details: 'Highest Tier: ${player.efootballProfile?.highTier ?? "N/A"}',
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildGameCard({required String title, required String details}) {
    return Card(
      color: AppColors.cardBackground,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.secondary)),
            const SizedBox(height: 8),
            Text(details, style: const TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
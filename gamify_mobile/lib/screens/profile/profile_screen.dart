import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/connection_model.dart';
import '../../models/player_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/connection_provider.dart';
import '../../providers/player_provider.dart';
import '../auth/login_screen.dart';
import '../messages/messages_screen.dart';
import 'edit_game_profiles_screen.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const List<String> _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<PlayerProvider>(context, listen: false).fetchMyProfile();
    });
  }

  void _openGameEditor(int tab) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => EditGameProfilesScreen(initialTab: tab)));
  }

  @override
  Widget build(BuildContext context) {
    final playerProvider = Provider.of<PlayerProvider>(context);
    final player = playerProvider.currentPlayer;
    final friends = Provider.of<ConnectionProvider>(context).friends;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Player Profile'),
        actions: [
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
      // Only show the full-page spinner on first load, so refreshes keep the page visible
      body: player == null
          ? playerProvider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : const Center(child: Text('No Profile Found'))
          : RefreshIndicator(
              onRefresh: () => Future.wait([
                playerProvider.fetchMyProfile(),
                Provider.of<ConnectionProvider>(context, listen: false).fetchConnections(),
              ]),
              child: ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  _buildHeader(player, friends.length),
                  const SizedBox(height: 8),
                  _buildAboutSection(player),
                  const SizedBox(height: 8),
                  _buildFriendsSection(friends),
                  const SizedBox(height: 8),
                  _buildBgmiSection(player.bgmiProfile),
                  const SizedBox(height: 8),
                  _buildEfootballSection(player.efootballProfile),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader(PlayerResponse player, int friendCount) {
    final location = [player.country, player.language].whereType<String>().where((s) => s.isNotEmpty).join(' · ');

    return Container(
      color: AppColors.cardBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                height: 90,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [AppColors.primary, AppColors.secondary]),
                ),
              ),
              Positioned(
                left: 16,
                bottom: -40,
                child: CircleAvatar(
                  radius: 44,
                  backgroundColor: AppColors.cardBackground,
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: AppColors.primary,
                    child: Text(
                      player.username.isEmpty ? '?' : player.username[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 48),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(player.username, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                if (player.playerBio != null && player.playerBio!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(player.playerBio!, style: const TextStyle(color: AppColors.textPrimary)),
                ],
                if (location.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(location, style: const TextStyle(color: AppColors.textSecondary)),
                ],
                const SizedBox(height: 4),
                Text(
                  '$friendCount ${friendCount == 1 ? 'friend' : 'friends'}',
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Edit profile'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen())),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSection(PlayerResponse player) {
    return _Section(
      title: 'About',
      onEdit: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen())),
      children: [
        _InfoRow(icon: Icons.tag, label: 'Player ID', value: '${player.playerId}'),
        _InfoRow(icon: Icons.person_outline, label: 'Username', value: player.username),
        _InfoRow(icon: Icons.notes, label: 'Bio', value: player.playerBio),
        _InfoRow(icon: Icons.public, label: 'Country', value: player.country),
        _InfoRow(icon: Icons.translate, label: 'Language', value: player.language),
        _InfoRow(icon: Icons.calendar_today_outlined, label: 'Member since', value: _formatDate(player.createdAt)),
        _InfoRow(icon: Icons.update, label: 'Last updated', value: _formatDate(player.updatedAt)),
      ],
    );
  }

  Widget _buildFriendsSection(List<PlayerSummary> friends) {
    return _Section(
      title: 'Friends (${friends.length})',
      children: friends.isEmpty
          ? const [
              Padding(
                padding: EdgeInsets.only(right: 8, top: 4, bottom: 4),
                child: Text('No friends yet. Find players on Home and send them an invite.', style: TextStyle(color: AppColors.textSecondary)),
              ),
            ]
          : [
              for (final friend in friends)
                ListTile(
                  contentPadding: const EdgeInsets.only(right: 8),
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary,
                    child: Text(
                      friend.username.isEmpty ? '?' : friend.username[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(friend.username, style: const TextStyle(fontWeight: FontWeight.w600)),
                  trailing: IconButton(
                    icon: const Icon(Icons.chat_bubble_outline, color: AppColors.primary),
                    tooltip: 'Message',
                    onPressed: () => MessagesScreen.openChat(context, friend),
                  ),
                  onTap: () => MessagesScreen.openChat(context, friend),
                  subtitle: Text(
                    [friend.country, friend.language].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ),
            ],
    );
  }

  Widget _buildBgmiSection(BgmiProfileResponse? bgmi) {
    return _Section(
      title: 'BGMI',
      accent: AppColors.secondary,
      onEdit: bgmi == null ? null : () => _openGameEditor(0),
      children: bgmi == null
          ? [_EmptyGameProfile(game: 'BGMI', onAdd: () => _openGameEditor(0))]
          : [
              _InfoRow(icon: Icons.badge_outlined, label: 'BGMI ID', value: bgmi.bgmiId),
              _InfoRow(icon: Icons.sports_esports_outlined, label: 'Current role', value: bgmi.currentRole),
              _InfoRow(icon: Icons.timeline, label: 'Experience', value: bgmi.experience),
              _InfoRow(icon: Icons.schedule, label: 'Available time', value: bgmi.availableTime),
              _InfoRow(icon: Icons.emoji_events_outlined, label: 'Achievements', value: bgmi.achievements),
              _InfoRow(icon: Icons.group_add_outlined, label: 'Looking for', value: bgmi.lookingFor),
            ],
    );
  }

  Widget _buildEfootballSection(EfootballProfileResponse? efootball) {
    return _Section(
      title: 'eFootball',
      accent: AppColors.success,
      onEdit: efootball == null ? null : () => _openGameEditor(1),
      children: efootball == null
          ? [_EmptyGameProfile(game: 'eFootball', onAdd: () => _openGameEditor(1))]
          : [
              _InfoRow(icon: Icons.badge_outlined, label: 'eFootball ID', value: efootball.efootballId),
              _InfoRow(icon: Icons.military_tech_outlined, label: 'Highest tier', value: efootball.highTier),
            ],
    );
  }

  String? _formatDate(DateTime? date) =>
      date == null ? null : '${date.day} ${_months[date.month - 1]} ${date.year}';
}

class _Section extends StatelessWidget {
  final String title;
  final Color? accent;
  final VoidCallback? onEdit;
  final List<Widget> children;

  const _Section({required this.title, this.accent, this.onEdit, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.cardBackground,
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (accent != null) ...[
                Container(width: 4, height: 20, color: accent),
                const SizedBox(width: 8),
              ],
              Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
              if (onEdit != null)
                IconButton(icon: const Icon(Icons.edit_outlined, color: AppColors.textSecondary), onPressed: onEdit),
            ],
          ),
          const SizedBox(height: 4),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;

  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null && value!.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                const SizedBox(height: 2),
                Text(
                  hasValue ? value! : 'Not added',
                  style: TextStyle(
                    color: hasValue ? AppColors.textPrimary : AppColors.textSecondary,
                    fontStyle: hasValue ? FontStyle.normal : FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyGameProfile extends StatelessWidget {
  final String game;
  final VoidCallback onAdd;

  const _EmptyGameProfile({required this.game, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8, top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Add your $game details so squads can find you.', style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.add, size: 18),
            label: Text('Add $game profile'),
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }
}

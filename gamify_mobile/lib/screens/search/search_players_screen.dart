import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/player_provider.dart';

class SearchPlayersScreen extends StatefulWidget {
  const SearchPlayersScreen({super.key});

  @override
  State<SearchPlayersScreen> createState() => _SearchPlayersScreenState();
}

class _SearchPlayersScreenState extends State<SearchPlayersScreen> {
  final _usernameController = TextEditingController();
  final _bgmiRoleController = TextEditingController();

  void _triggerSearch() {
    Provider.of<PlayerProvider>(context, listen: false).searchPlayers(
      username: _usernameController.text.trim(),
      bgmiRole: _bgmiRoleController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final playerProvider = Provider.of<PlayerProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Find Teammates & Players')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _usernameController,
                    decoration: const InputDecoration(labelText: 'Username', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _bgmiRoleController,
                    decoration: const InputDecoration(labelText: 'BGMI Role (e.g. IGL)', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  icon: const Icon(Icons.search),
                  onPressed: _triggerSearch,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: playerProvider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : playerProvider.searchResults.isEmpty
                      ? const Center(child: Text('No players found match filters.'))
                      : ListView.builder(
                          itemCount: playerProvider.searchResults.length,
                          itemBuilder: (context, index) {
                            final p = playerProvider.searchResults[index];
                            return Card(
                              color: AppColors.cardBackground,
                              child: ListTile(
                                leading: const CircleAvatar(child: Icon(Icons.person)),
                                title: Text(p.username, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('Country: ${p.country ?? "N/A"} | BGMI Role: ${p.bgmiProfile?.currentRole ?? "N/A"}'),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
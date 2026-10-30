import 'package:flutter/material.dart';

/// Profile | Posts tabs at the top of a profile page.
class ProfileTabs extends StatelessWidget {
  final Widget profile;
  final Widget posts;

  const ProfileTabs({super.key, required this.profile, required this.posts});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.person_outline), text: 'Profile'),
              Tab(icon: Icon(Icons.grid_on), text: 'Posts'),
            ],
          ),
          Expanded(child: TabBarView(children: [profile, posts])),
        ],
      ),
    );
  }
}

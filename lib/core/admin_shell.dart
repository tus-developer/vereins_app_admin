import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'user_permissions.dart';
import '../features/news/news_admin_view.dart';
import '../features/termine/termine_admin_view.dart';

class AdminShell extends StatefulWidget {
  final UserPermissions permissions;
  const AdminShell({super.key, required this.permissions});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final modules = [
      (
        label: 'News',
        icon: Icons.article_outlined,
        selectedIcon: Icons.article,
        view: NewsAdminView(permissions: widget.permissions),
      ),
      (
        label: 'Termine',
        icon: Icons.event_outlined,
        selectedIcon: Icons.event,
        view: TermineAdminView(permissions: widget.permissions),
      ),
    ];

    final roleLabel = widget.permissions.isSuperadmin
        ? 'Superadmin'
        : widget.permissions.isAbteilungsAdmin
            ? 'Abteilungsleitung'
            : 'Teams: ${widget.permissions.adminTeams.join(', ')}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('TuS Neuhofen Handball – Web-Verwaltung'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(
              child: Text(
                '${widget.permissions.fullName} ($roleLabel)',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Abmelden',
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            extended: MediaQuery.of(context).size.width >= 900,
            selectedIndex: _selectedIndex,
            onDestinationSelected: (i) => setState(() => _selectedIndex = i),
            destinations: modules
                .map((m) => NavigationRailDestination(
                      icon: Icon(m.icon),
                      selectedIcon: Icon(m.selectedIcon),
                      label: Text(m.label),
                    ))
                .toList(),
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: modules[_selectedIndex].view),
        ],
      ),
    );
  }
}
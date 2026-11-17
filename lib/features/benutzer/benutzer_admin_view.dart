import 'package:flutter/material.dart';
import '../../core/user_permissions.dart';
import 'benutzer_model.dart';
import 'benutzer_service.dart';

class BenutzerAdminView extends StatefulWidget {
  final UserPermissions permissions;
  const BenutzerAdminView({super.key, required this.permissions});

  @override
  State<BenutzerAdminView> createState() => _BenutzerAdminViewState();
}

class _BenutzerAdminViewState extends State<BenutzerAdminView> {
  final _service = BenutzerService();
  final _searchCtrl = TextEditingController();

  String _searchQuery = '';
  String _selectedTeamFilter = 'Alle';
  bool _onlyOpenRequests = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _openUserDetails(VereinBenutzer user) async {
    final allTeams = await _service.fetchAllTeamNames();
    if (!mounted) return;

    final vornameCtrl = TextEditingController(text: user.vorname);
    final nachnameCtrl = TextEditingController(text: user.nachname);
    final telefonCtrl = TextEditingController(text: user.telefon);
    final strasseCtrl = TextEditingController(text: user.strasse);
    final plzOrtCtrl = TextEditingController(text: user.plzOrt);
    final notfallCtrl = TextEditingController(text: user.notfallKontakt);

    List<BenutzerRolle> currentRollen = List.from(user.rollen);
    List<BenutzerKind> currentKinder = List.from(user.kinder);

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.fullName),
                    if (widget.permissions.isSuperadmin || widget.permissions.isAbteilungsAdmin)
                      Text(
                        user.email,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
          content: SizedBox(
            width: 680,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Zugewiesene & beantragte Rollen',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      if (widget.permissions.isSuperadmin ||
                          widget.permissions.isAbteilungsAdmin)
                        FilledButton.tonalIcon(
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Rolle zuweisen'),
                          onPressed: () async {
                            final newRole = await _showAddRoleDialog(ctx, allTeams);
                            if (newRole != null) {
                              currentRollen.add(newRole);
                              await _service.updateRollen(user.uid, currentRollen);
                              setDialogState(() {});
                            }
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (currentRollen.isEmpty)
                    const Text('Keine Rollen eingetragen.', style: TextStyle(color: Colors.grey))
                  else
                    ...currentRollen.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final r = entry.value;
                      final canApprove = widget.permissions.canApproveTeam(r.team) ||
                          (r.rolle == 'Eltern' && widget.permissions.canAccessUserAdmin);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          dense: true,
                          leading: Icon(
                            r.isFreigegeben ? Icons.verified : Icons.hourglass_top,
                            color: r.isFreigegeben ? Colors.green : Colors.orange,
                          ),
                          title: Text('${r.rolle} • ${r.team}'),
                          subtitle: Text(
                            r.isFreigegeben ? 'Status: Freigegeben' : 'Status: Ausstehend',
                          ),
                          trailing: canApprove
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (!r.isFreigegeben)
                                      IconButton(
                                        tooltip: 'Freigeben',
                                        icon: const Icon(Icons.check_circle, color: Colors.green),
                                        onPressed: () async {
                                          currentRollen[idx] = BenutzerRolle(
                                            rolle: r.rolle,
                                            team: r.team,
                                            status: 'freigegeben',
                                          );
                                          await _service.updateRollen(user.uid, currentRollen);
                                          setDialogState(() {});
                                        },
                                      ),
                                    if (r.rolle != 'Superadmin')
                                      IconButton(
                                        tooltip: 'Rolle entfernen / ablehnen',
                                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                                        onPressed: () async {
                                          currentRollen.removeAt(idx);
                                          await _service.updateRollen(user.uid, currentRollen);
                                          setDialogState(() {});
                                        },
                                      ),
                                  ],
                                )
                              : null,
                        ),
                      );
                    }),
                  if (currentKinder.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Verknüpfte Kinder',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    ...currentKinder.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final k = entry.value;
                      final isApproved = k.status == 'freigegeben';
                      final canApprove = widget.permissions.canApproveTeam(k.team);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          dense: true,
                          leading: Icon(
                            isApproved ? Icons.child_care : Icons.hourglass_top,
                            color: isApproved ? Colors.green : Colors.orange,
                          ),
                          title: Text('${k.vorname} ${k.nachname} (${k.team})'),
                          subtitle: Text(
                            'Geb.: ${k.gebDatum} • Status: ${isApproved ? 'Freigegeben' : 'Ausstehend'}',
                          ),
                          trailing: canApprove
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (!isApproved)
                                      IconButton(
                                        tooltip: 'Kind freigeben',
                                        icon: const Icon(Icons.check_circle, color: Colors.green),
                                        onPressed: () async {
                                          currentKinder[idx] = BenutzerKind(
                                            vorname: k.vorname,
                                            nachname: k.nachname,
                                            gebDatum: k.gebDatum,
                                            team: k.team,
                                            status: 'freigegeben',
                                            handballDaten: k.handballDaten,
                                          );
                                          await _service.updateKinder(user.uid, currentKinder);
                                          setDialogState(() {});
                                        },
                                      ),
                                    IconButton(
                                      tooltip: 'Kind-Zuordnung entfernen',
                                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                                      onPressed: () async {
                                        currentKinder.removeAt(idx);
                                        await _service.updateKinder(user.uid, currentKinder);
                                        setDialogState(() {});
                                      },
                                    ),
                                  ],
                                )
                              : null,
                        ),
                      );
                    }),
                  ],
                  if (widget.permissions.isSuperadmin ||
                      widget.permissions.isAbteilungsAdmin) ...[
                    const Divider(height: 32),
                    Text(
                      'Stammdaten bearbeiten',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: vornameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Vorname',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: nachnameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Nachname',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: telefonCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Telefon',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: notfallCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Notfallkontakt',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: strasseCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Straße & Hausnummer',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: plzOrtCtrl,
                            decoration: const InputDecoration(
                              labelText: 'PLZ & Ort',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        icon: const Icon(Icons.save, size: 18),
                        label: const Text('Stammdaten speichern'),
                        onPressed: () async {
                          await _service.updateStammdaten(
                            uid: user.uid,
                            vorname: vornameCtrl.text.trim(),
                            nachname: nachnameCtrl.text.trim(),
                            telefon: telefonCtrl.text.trim(),
                            strasse: strasseCtrl.text.trim(),
                            plzOrt: plzOrtCtrl.text.trim(),
                            notfallKontakt: notfallCtrl.text.trim(),
                          );
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(content: Text('Stammdaten gespeichert')),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<BenutzerRolle?> _showAddRoleDialog(
    BuildContext parentContext,
    List<String> allTeams,
  ) async {
    final availableTeams = <String>[
      'TuS Neuhofen Handball',
      'Verein',
      ...allTeams,
    ].toSet().toList();

    final availableRoles = <String>[
      'Spieler',
      'Trainer',
      'Teamadmin',
      'Eltern',
      if (widget.permissions.isSuperadmin) ...[
        'Abteilungsleiter',
        'Jugendleiter',
        'Superadmin',
      ],
    ];

    String selectedRole = availableRoles.first;
    String selectedTeam = allTeams.isNotEmpty ? allTeams.first : availableTeams.first;

    return showDialog<BenutzerRolle>(
      context: parentContext,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Neue Rolle direkt zuweisen'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Rolle',
                    border: OutlineInputBorder(),
                  ),
                  items: availableRoles
                      .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => selectedRole = val);
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedTeam,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Mannschaft / Bereich',
                    border: OutlineInputBorder(),
                  ),
                  items: availableTeams
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => selectedTeam = val);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  ctx,
                  BenutzerRolle(
                    rolle: selectedRole,
                    team: selectedTeam,
                    status: selectedRole == 'Superadmin' ? null : 'freigegeben',
                  ),
                );
              },
              child: const Text('Zuweisen'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Benutzer verwalten', style: Theme.of(context).textTheme.headlineSmall),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<List<VereinBenutzer>>(
              stream: _service.streamManageableUsers(widget.permissions),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Fehler: ${snapshot.error}'));
                }

                final allUsers = snapshot.data ?? [];
                final openCount = allUsers.where((u) => u.hasOpenRequests).length;

                final teamFilterOptions = <String>{
                  'Alle',
                  ...allUsers.expand((u) => [
                        ...u.rollen.map((r) => r.team),
                        ...u.kinder.map((k) => k.team),
                      ]).where((t) => t.isNotEmpty),
                }.toList();

                if (!teamFilterOptions.contains(_selectedTeamFilter)) {
                  _selectedTeamFilter = 'Alle';
                }

                final filteredUsers = allUsers.where((u) {
                  if (_onlyOpenRequests && !u.hasOpenRequests) {
                    return false;
                  }
                  if (_selectedTeamFilter != 'Alle') {
                    final inRole = u.rollen.any((r) => r.team == _selectedTeamFilter);
                    final inChild = u.kinder.any((k) => k.team == _selectedTeamFilter);
                    if (!inRole && !inChild) return false;
                  }
                  if (_searchQuery.isNotEmpty) {
                    final q = _searchQuery.toLowerCase();
                    final matchesName = u.fullName.toLowerCase().contains(q);
                    final matchesEmail = u.email.toLowerCase().contains(q);
                    final matchesRole = u.rollen.any(
                      (r) => r.rolle.toLowerCase().contains(q) || r.team.toLowerCase().contains(q),
                    );
                    final matchesChild = u.kinder.any(
                      (k) =>
                          k.vorname.toLowerCase().contains(q) ||
                          k.nachname.toLowerCase().contains(q),
                    );
                    if (!matchesName && !matchesEmail && !matchesRole && !matchesChild) {
                      return false;
                    }
                  }
                  return true;
                }).toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SizedBox(
                          width: 280,
                          child: TextField(
                            controller: _searchCtrl,
                            decoration: InputDecoration(
                              hintText: 'Suche nach Name, E-Mail, Rolle, Kind...',
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: () {
                                        _searchCtrl.clear();
                                        setState(() => _searchQuery = '');
                                      },
                                    )
                                  : null,
                              border: const OutlineInputBorder(),
                              isDense: true,
                            ),
                            onChanged: (val) => setState(() => _searchQuery = val.trim()),
                          ),
                        ),
                        SizedBox(
                          width: 260,
                          child: DropdownButtonFormField<String>(
                            value: _selectedTeamFilter,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Team-Filter',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: teamFilterOptions
                                .map((t) => DropdownMenuItem(
                                      value: t,
                                      child: Text(t, overflow: TextOverflow.ellipsis),
                                    ))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedTeamFilter = val);
                            },
                          ),
                        ),
                        FilterChip(
                          label: Text(
                            openCount > 0
                                ? 'Nur offene Anträge ($openCount)'
                                : 'Nur offene Anträge',
                          ),
                          selected: _onlyOpenRequests,
                          onSelected: (val) => setState(() => _onlyOpenRequests = val),
                        ),
                        Text(
                          '${filteredUsers.length} Benutzer',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: filteredUsers.isEmpty
                          ? const Center(child: Text('Keine passenden Benutzer gefunden.'))
                          : Card(
                              child: ListView.separated(
                                itemCount: filteredUsers.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final u = filteredUsers[index];
                                  final rollenText = u.rollen.isEmpty
                                      ? 'Keine Rollen'
                                      : u.rollen
                                          .map((r) =>
                                              '${r.rolle} (${r.team})${r.isFreigegeben ? '' : ' [Ausstehend]'}')
                                          .join(' • ');

                                  return ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 6,
                                    ),
                                    leading: CircleAvatar(
                                      backgroundColor: u.hasOpenRequests
                                          ? Colors.orange.shade100
                                          : Theme.of(context).colorScheme.primaryContainer,
                                      child: Icon(
                                        u.hasOpenRequests ? Icons.person_add : Icons.person,
                                        color: u.hasOpenRequests
                                            ? Colors.orange.shade900
                                            : Theme.of(context).colorScheme.onPrimaryContainer,
                                      ),
                                    ),
                                    title: Row(
                                      children: [
                                        Text(
                                          u.fullName,
                                          style: const TextStyle(fontWeight: FontWeight.w600),
                                        ),
                                        if (u.hasOpenRequests) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.orange.shade100,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              'Antrag offen',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.orange.shade900,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    subtitle: Text(
                                      '${(widget.permissions.isSuperadmin || widget.permissions.isAbteilungsAdmin) && u.email.isNotEmpty ? '${u.email}\n' : ''}$rollenText',
                                    ),
                                    isThreeLine: (widget.permissions.isSuperadmin ||
                                            widget.permissions.isAbteilungsAdmin) &&
                                        u.email.isNotEmpty,
                                    trailing: FilledButton.tonalIcon(
                                      icon: const Icon(Icons.manage_accounts, size: 18),
                                      label: const Text('Verwalten'),
                                      onPressed: () => _openUserDetails(u),
                                    ),
                                  );
                                },
                              ),
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
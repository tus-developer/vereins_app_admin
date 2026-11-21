import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/user_permissions.dart';
import 'mannschaft_model.dart';
import 'mannschaft_service.dart';

class MannschaftenAdminView extends StatefulWidget {
  final UserPermissions permissions;
  const MannschaftenAdminView({super.key, required this.permissions});

  @override
  State<MannschaftenAdminView> createState() => _MannschaftenAdminViewState();
}

class _MannschaftenAdminViewState extends State<MannschaftenAdminView> {
  final _service = MannschaftService();
  final _teamSearchCtrl = TextEditingController();
  final _memberSearchCtrl = TextEditingController();

  String _teamSearchQuery = '';
  String _memberSearchQuery = '';
  String? _selectedTeamName;

  bool _trainerExpanded = true;
  bool _spielerExpanded = true;
  bool _elternExpanded = true;

  bool get _anyExpanded =>
      _trainerExpanded || _spielerExpanded || _elternExpanded;

  void _toggleAllSections() {
    final targetState = !_anyExpanded;
    setState(() {
      _trainerExpanded = targetState;
      _spielerExpanded = targetState;
      _elternExpanded = targetState;
    });
  }

  @override
  void dispose() {
    _teamSearchCtrl.dispose();
    _memberSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _openTeamEditor([Mannschaft? existing, int nextSortIndex = 100]) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final sortCtrl = TextEditingController(
      text: (existing?.sortIndex ?? nextSortIndex).toString(),
    );
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Neue Mannschaft anlegen' : 'Mannschaft bearbeiten'),
        content: SizedBox(
          width: 450,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Mannschaftsname (z. B. mB-Jugend, Damen, ADHS)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Pflichtfeld' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: sortCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Sortier-Index (kleinere Zahl = weiter oben)',
                    helperText:
                        'Steuert die Reihenfolge in den Auswahlmenüs der App (z. B. 10, 20, 30...)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) =>
                      (v == null || int.tryParse(v) == null) ? 'Gültige Zahl eingeben' : null,
                ),
                if (existing != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, size: 18, color: Colors.amber),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Hinweis: Bestehende Spielerrollen und Termine sind über den exakten Namen verknüpft.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final newName = nameCtrl.text.trim();
              final team = Mannschaft(
                id: existing?.id ?? '',
                name: newName,
                sortIndex: int.parse(sortCtrl.text.trim()),
              );
              await _service.saveMannschaft(team);
              if (existing != null && _selectedTeamName == existing.name) {
                setState(() => _selectedTeamName = newName);
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteTeam(Mannschaft team) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mannschaft löschen?'),
        content: Text(
          'Soll "${team.name}" wirklich gelöscht werden? Bestehende Termine oder Benutzerrollen mit diesem Namen bleiben erhalten, erscheinen aber nicht mehr in der Team-Auswahl.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _service.deleteMannschaft(team.id);
      if (_selectedTeamName == team.name) {
        setState(() => _selectedTeamName = null);
      }
    }
  }

  Future<void> _openAddMemberDialog(String teamName) async {
    final users = await _service.fetchAllUsersSummary();
    if (!mounted || users.isEmpty) return;

    String selectedUid = users.first.uid;
    String selectedRole = 'Spieler';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Person zu "$teamName" zuordnen'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedUid,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Registrierter Benutzer',
                    border: OutlineInputBorder(),
                  ),
                  items: users
                      .map((u) => DropdownMenuItem(
                            value: u.uid,
                            child: Text(u.label, overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedUid = val);
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Rolle in dieser Mannschaft',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Spieler', child: Text('Spieler')),
                    DropdownMenuItem(value: 'Trainer', child: Text('Trainer')),
                    DropdownMenuItem(value: 'Betreuer', child: Text('Betreuer')),
                    DropdownMenuItem(value: 'Teamadmin', child: Text('Teamadmin')),
                    DropdownMenuItem(value: 'Eltern', child: Text('Eltern')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedRole = val);
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
              onPressed: () async {
                await _service.addRoleToUser(
                  uid: selectedUid,
                  rolle: selectedRole,
                  teamName: teamName,
                );
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Zuordnen'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmRemoveMember(TeamMemberEntry entry, String teamName) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Zuordnung entfernen?'),
        content: Text(
          'Soll "${entry.displayName}" (${entry.subtitle}) aus "$teamName" entfernt werden?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Entfernen'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _service.removeTeamEntry(entry);
    }
  }

  Widget _buildRelationBadges(BuildContext context, TeamMemberEntry entry) {
    if (entry.relatedNames.isEmpty) return const SizedBox.shrink();

    final isParentEntry = entry.category == 'eltern';
    final primaryColor = Theme.of(context).colorScheme.primary;
    final badgeBg = isParentEntry
        ? primaryColor.withValues(alpha: 0.08)
        : const Color(0xFFECEFF3);
    final badgeFg = isParentEntry ? primaryColor : const Color(0xFF1E242B);
    final badgeIcon = isParentEntry ? Icons.child_care : Icons.family_restroom;
    final prefix = isParentEntry ? 'Kind:' : 'Eltern:';

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: entry.relatedNames.map((name) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isParentEntry
                    ? primaryColor.withValues(alpha: 0.25)
                    : const Color(0xFFCBD2D9),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(badgeIcon, size: 14, color: badgeFg),
                const SizedBox(width: 5),
                Text(
                  '$prefix $name',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: badgeFg,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRosterSection({
    required BuildContext context,
    required String title,
    required IconData icon,
    required List<TeamMemberEntry> entries,
    required String teamName,
    required bool canEditTeam,
    required bool isExpanded,
    required ValueChanged<bool> onToggle,
  }) {
    final filtered = entries.where((e) {
      if (_memberSearchQuery.isEmpty) return true;
      final q = _memberSearchQuery.toLowerCase();
      final matchesMain = e.displayName.toLowerCase().contains(q) ||
          e.subtitle.toLowerCase().contains(q);
      final matchesRelated =
          e.relatedNames.any((name) => name.toLowerCase().contains(q));
      return matchesMain || matchesRelated;
    }).toList();

    final effectiveExpanded = _memberSearchQuery.isNotEmpty ? true : isExpanded;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: () => onToggle(!effectiveExpanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '$title (${filtered.length})',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: effectiveExpanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 180),
                      child: Icon(
                        Icons.expand_more,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (effectiveExpanded) ...[
              const Divider(height: 1),
              if (filtered.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Keine Einträge in dieser Kategorie.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final entry = filtered[index];
                    final canDeleteEntry = entry.arrayIndex >= 0;

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      leading: CircleAvatar(
                        radius: 19,
                        backgroundColor: entry.isFreigegeben
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Colors.orange.shade100,
                        child: Icon(
                          entry.isChild
                              ? Icons.child_care
                              : (entry.category == 'trainer'
                                  ? Icons.sports
                                  : (entry.category == 'eltern'
                                      ? Icons.family_restroom
                                      : Icons.person)),
                          size: 19,
                          color: entry.isFreigegeben
                              ? Theme.of(context).colorScheme.onPrimaryContainer
                              : Colors.orange.shade900,
                        ),
                      ),
                      title: Row(
                        children: [
                          Flexible(
                            child: Text(
                              entry.displayName,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (!entry.isFreigegeben) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Ausstehend',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade900,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 2),
                          Text(entry.subtitle),
                          _buildRelationBadges(context, entry),
                        ],
                      ),
                      trailing: canEditTeam
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!entry.isFreigegeben && entry.arrayIndex >= 0)
                                  IconButton(
                                    tooltip: 'Freigeben',
                                    icon: const Icon(Icons.check_circle, color: Colors.green),
                                    onPressed: () => _service.approveTeamEntry(entry),
                                  ),
                                if (canDeleteEntry)
                                  IconButton(
                                    tooltip: entry.category == 'eltern'
                                        ? 'Eltern-Rolle entfernen'
                                        : 'Aus Mannschaft entfernen',
                                    icon: const Icon(Icons.person_remove_outlined, color: Colors.red),
                                    onPressed: () => _confirmRemoveMember(entry, teamName),
                                  ),
                              ],
                            )
                          : null,
                    );
                  },
                ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canManageTeams = widget.permissions.canManageMannschaften;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: StreamBuilder<List<Mannschaft>>(
        stream: _service.streamMannschaften(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Fehler: ${snapshot.error}'));
          }

          final allTeams = snapshot.data ?? [];

          final visibleTeams = canManageTeams
              ? allTeams
              : allTeams
                  .where((t) => widget.permissions.adminTeams.contains(t.name))
                  .toList();

          final nextSort = allTeams.isEmpty
              ? 10
              : (allTeams.map((t) => t.sortIndex).reduce((a, b) => a > b ? a : b) + 10);

          if (_selectedTeamName == null ||
              !visibleTeams.any((t) => t.name == _selectedTeamName)) {
            _selectedTeamName = visibleTeams.isNotEmpty ? visibleTeams.first.name : null;
          }

          final filteredTeams = visibleTeams.where((t) {
            if (_teamSearchQuery.isEmpty) return true;
            return t.name.toLowerCase().contains(_teamSearchQuery.toLowerCase());
          }).toList();

          final canEditSelectedTeam = _selectedTeamName != null &&
              widget.permissions.canApproveTeam(_selectedTeamName!);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Mannschaften & Kader',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  if (canManageTeams)
                    FilledButton.icon(
                      onPressed: () => _openTeamEditor(null, nextSort),
                      icon: const Icon(Icons.add),
                      label: const Text('Neue Mannschaft'),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // LINKE SPALTE: Mannschafts-Auswahl
                    SizedBox(
                      width: 320,
                      child: Card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: TextField(
                                controller: _teamSearchCtrl,
                                decoration: InputDecoration(
                                  hintText: 'Mannschaft filtern...',
                                  prefixIcon: const Icon(Icons.search, size: 20),
                                  suffixIcon: _teamSearchQuery.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.clear, size: 18),
                                          onPressed: () {
                                            _teamSearchCtrl.clear();
                                            setState(() => _teamSearchQuery = '');
                                          },
                                        )
                                      : null,
                                  isDense: true,
                                ),
                                onChanged: (val) =>
                                    setState(() => _teamSearchQuery = val.trim()),
                              ),
                            ),
                            const Divider(height: 1),
                            Expanded(
                              child: filteredTeams.isEmpty
                                  ? const Center(child: Text('Keine Mannschaft gefunden.'))
                                  : ListView.separated(
                                      itemCount: filteredTeams.length,
                                      separatorBuilder: (_, __) => const Divider(height: 1),
                                      itemBuilder: (context, index) {
                                        final team = filteredTeams[index];
                                        final isSelected = team.name == _selectedTeamName;
                                        return ListTile(
                                          selected: isSelected,
                                          selectedTileColor: Theme.of(context)
                                              .colorScheme
                                              .primary
                                              .withValues(alpha: 0.08),
                                          leading: CircleAvatar(
                                            radius: 16,
                                            backgroundColor: isSelected
                                                ? Theme.of(context).colorScheme.primary
                                                : Theme.of(context)
                                                    .colorScheme
                                                    .primaryContainer,
                                            child: Text(
                                              '${team.sortIndex}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: isSelected
                                                    ? Colors.white
                                                    : Theme.of(context)
                                                        .colorScheme
                                                        .onPrimaryContainer,
                                              ),
                                            ),
                                          ),
                                          title: Text(
                                            team.name,
                                            style: TextStyle(
                                              fontWeight: isSelected
                                                  ? FontWeight.bold
                                                  : FontWeight.w500,
                                            ),
                                          ),
                                          onTap: () =>
                                              setState(() => _selectedTeamName = team.name),
                                          trailing: canManageTeams
                                              ? Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    IconButton(
                                                      tooltip: 'Bearbeiten',
                                                      icon: const Icon(
                                                        Icons.edit_outlined,
                                                        size: 18,
                                                      ),
                                                      onPressed: () => _openTeamEditor(team),
                                                    ),
                                                    IconButton(
                                                      tooltip: 'Löschen',
                                                      icon: const Icon(
                                                        Icons.delete_outline,
                                                        size: 18,
                                                        color: Colors.red,
                                                      ),
                                                      onPressed: () => _confirmDeleteTeam(team),
                                                    ),
                                                  ],
                                                )
                                              : const Icon(Icons.chevron_right),
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),

                    // RECHTE SPALTE: Zugeordnete Trainer, Spieler & Eltern
                    Expanded(
                      child: _selectedTeamName == null
                          ? const Card(
                              child: Center(
                                child: Text('Bitte links eine Mannschaft auswählen.'),
                              ),
                            )
                          : StreamBuilder<TeamRoster>(
                              stream: _service.streamTeamRoster(_selectedTeamName!),
                              builder: (context, rosterSnap) {
                                if (rosterSnap.connectionState == ConnectionState.waiting) {
                                  return const Card(
                                    child: Center(child: CircularProgressIndicator()),
                                  );
                                }
                                if (rosterSnap.hasError) {
                                  return Card(
                                    child: Center(
                                      child: Text('Fehler beim Laden: ${rosterSnap.error}'),
                                    ),
                                  );
                                }

                                final roster = rosterSnap.data ??
                                    TeamRoster(trainer: [], spieler: [], eltern: []);

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Card(
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Wrap(
                                          spacing: 16,
                                          runSpacing: 12,
                                          alignment: WrapAlignment.spaceBetween,
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          children: [
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  _selectedTeamName!,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleLarge
                                                      ?.copyWith(fontWeight: FontWeight.bold),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  '${roster.trainer.length} Trainer/Betreuer • '
                                                  '${roster.spieler.length} Spieler • '
                                                  '${roster.eltern.length} Eltern',
                                                  style: Theme.of(context).textTheme.bodySmall,
                                                ),
                                              ],
                                            ),
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                SizedBox(
                                                  width: 220,
                                                  child: TextField(
                                                    controller: _memberSearchCtrl,
                                                    decoration: InputDecoration(
                                                      hintText: 'Im Kader suchen...',
                                                      prefixIcon:
                                                          const Icon(Icons.search, size: 18),
                                                      suffixIcon: _memberSearchQuery.isNotEmpty
                                                          ? IconButton(
                                                              icon: const Icon(Icons.clear,
                                                                  size: 18),
                                                              onPressed: () {
                                                                _memberSearchCtrl.clear();
                                                                setState(() =>
                                                                    _memberSearchQuery = '');
                                                              },
                                                            )
                                                          : null,
                                                      isDense: true,
                                                    ),
                                                    onChanged: (val) => setState(
                                                        () => _memberSearchQuery = val.trim()),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                IconButton.outlined(
                                                  tooltip: _anyExpanded
                                                      ? 'Alle Bereiche zuklappen'
                                                      : 'Alle Bereiche aufklappen',
                                                  icon: Icon(
                                                    _anyExpanded
                                                        ? Icons.unfold_less
                                                        : Icons.unfold_more,
                                                    size: 20,
                                                  ),
                                                  onPressed: _memberSearchQuery.isNotEmpty
                                                      ? null
                                                      : _toggleAllSections,
                                                ),
                                                if (canEditSelectedTeam) ...[
                                                  const SizedBox(width: 8),
                                                  FilledButton.tonalIcon(
                                                    icon: const Icon(Icons.person_add, size: 18),
                                                    label: const Text('Person zuordnen'),
                                                    onPressed: () =>
                                                        _openAddMemberDialog(_selectedTeamName!),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Expanded(
                                      child: SingleChildScrollView(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          children: [
                                            _buildRosterSection(
                                              context: context,
                                              title: 'Trainer & Betreuer',
                                              icon: Icons.sports,
                                              entries: roster.trainer,
                                              teamName: _selectedTeamName!,
                                              canEditTeam: canEditSelectedTeam,
                                              isExpanded: _trainerExpanded,
                                              onToggle: (val) =>
                                                  setState(() => _trainerExpanded = val),
                                            ),
                                            _buildRosterSection(
                                              context: context,
                                              title: 'Mannschaft (Aktive Spieler & Jugend)',
                                              icon: Icons.groups,
                                              entries: roster.spieler,
                                              teamName: _selectedTeamName!,
                                              canEditTeam: canEditSelectedTeam,
                                              isExpanded: _spielerExpanded,
                                              onToggle: (val) =>
                                                  setState(() => _spielerExpanded = val),
                                            ),
                                            _buildRosterSection(
                                              context: context,
                                              title: 'Eltern',
                                              icon: Icons.family_restroom,
                                              entries: roster.eltern,
                                              teamName: _selectedTeamName!,
                                              canEditTeam: canEditSelectedTeam,
                                              isExpanded: _elternExpanded,
                                              onToggle: (val) =>
                                                  setState(() => _elternExpanded = val),
                                            ),
                                          ],
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
              ),
            ],
          );
        },
      ),
    );
  }
}
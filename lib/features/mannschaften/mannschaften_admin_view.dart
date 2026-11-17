import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'mannschaft_model.dart';
import 'mannschaft_service.dart';

class MannschaftenAdminView extends StatefulWidget {
  const MannschaftenAdminView({super.key});

  @override
  State<MannschaftenAdminView> createState() => _MannschaftenAdminViewState();
}

class _MannschaftenAdminViewState extends State<MannschaftenAdminView> {
  final _service = MannschaftService();
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _openEditor([Mannschaft? existing, int nextSortIndex = 100]) async {
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
                    helperText: 'Steuert die Reihenfolge in den Auswahlmenüs der App (z. B. 10, 20, 30...)',
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
              final team = Mannschaft(
                id: existing?.id ?? '',
                name: nameCtrl.text.trim(),
                sortIndex: int.parse(sortCtrl.text.trim()),
              );
              await _service.saveMannschaft(team);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(Mannschaft team) async {
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
    if (ok == true) await _service.deleteMannschaft(team.id);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StreamBuilder<List<Mannschaft>>(
            stream: _service.streamMannschaften(),
            builder: (context, snapshot) {
              final allTeams = snapshot.data ?? [];
              final nextSort = allTeams.isEmpty
                  ? 10
                  : (allTeams.map((t) => t.sortIndex).reduce((a, b) => a > b ? a : b) + 10);

              final filteredTeams = allTeams.where((t) {
                if (_searchQuery.isEmpty) return true;
                return t.name.toLowerCase().contains(_searchQuery.toLowerCase());
              }).toList();

              return Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Mannschaften verwalten',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        FilledButton.icon(
                          onPressed: () => _openEditor(null, nextSort),
                          icon: const Icon(Icons.add),
                          label: const Text('Neue Mannschaft'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        SizedBox(
                          width: 280,
                          child: TextField(
                            controller: _searchCtrl,
                            decoration: InputDecoration(
                              hintText: 'Mannschaft suchen...',
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
                        const SizedBox(width: 16),
                        Text(
                          '${filteredTeams.length} Mannschaften (sortiert nach sortIndex)',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (snapshot.connectionState == ConnectionState.waiting)
                      const Expanded(child: Center(child: CircularProgressIndicator()))
                    else if (snapshot.hasError)
                      Expanded(child: Center(child: Text('Fehler: ${snapshot.error}')))
                    else if (filteredTeams.isEmpty)
                      const Expanded(child: Center(child: Text('Keine Mannschaften gefunden.')))
                    else
                      Expanded(
                        child: Card(
                          child: ListView.separated(
                            itemCount: filteredTeams.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final team = filteredTeams[index];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor:
                                      Theme.of(context).colorScheme.primaryContainer,
                                  child: Text(
                                    '${team.sortIndex}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  team.name,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                subtitle: Text('Sortier-Index: ${team.sortIndex}'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: 'Bearbeiten',
                                      icon: const Icon(Icons.edit_outlined),
                                      onPressed: () => _openEditor(team),
                                    ),
                                    IconButton(
                                      tooltip: 'Löschen',
                                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                                      onPressed: () => _confirmDelete(team),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
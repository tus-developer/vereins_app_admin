import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/user_permissions.dart';
import 'news_model.dart';
import 'news_service.dart';

class NewsAdminView extends StatefulWidget {
  final UserPermissions permissions;
  const NewsAdminView({super.key, required this.permissions});

  @override
  State<NewsAdminView> createState() => _NewsAdminViewState();
}

class _NewsAdminViewState extends State<NewsAdminView> {
  final _service = NewsService();
  final _dateFormat = DateFormat('dd.MM.yyyy • HH:mm', 'de_DE');
  final _searchCtrl = TextEditingController();

  String _searchQuery = '';
  String _selectedSichtbarkeit = 'Alle';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _openEditor([NewsItem? existing]) async {
    final allTeams = await _service.fetchAllTeamNames();
    final allowedOptions = widget.permissions.allowedSichtbarkeiten(allTeams);
    if (allowedOptions.isEmpty) return;

    final titelCtrl = TextEditingController(text: existing?.titel ?? '');
    final inhaltCtrl = TextEditingController(text: existing?.inhalt ?? '');
    String sichtbarkeit = (existing != null && allowedOptions.contains(existing.sichtbarkeit))
        ? existing.sichtbarkeit
        : allowedOptions.first;
    final formKey = GlobalKey<FormState>();

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Neue Nachricht' : 'Nachricht bearbeiten'),
        content: SizedBox(
          width: 600,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: titelCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Titel',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Pflichtfeld' : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: sichtbarkeit,
                    decoration: const InputDecoration(
                      labelText: 'Sichtbarkeit (Zielgruppe)',
                      border: OutlineInputBorder(),
                    ),
                    items: allowedOptions
                        .map((opt) => DropdownMenuItem(value: opt, child: Text(opt)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) sichtbarkeit = val;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: inhaltCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Inhalt',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    maxLines: 8,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Pflichtfeld' : null,
                  ),
                ],
              ),
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
              final now = DateTime.now();
              final item = NewsItem(
                id: existing?.id ?? '',
                titel: titelCtrl.text.trim(),
                inhalt: inhaltCtrl.text.trim(),
                sichtbarkeit: sichtbarkeit,
                datum: existing?.datum ?? now,
                erstelltAm: existing?.erstelltAm ?? now,
                erstellerId: existing?.erstellerId ?? widget.permissions.uid,
              );
              await _service.saveNews(item);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(NewsItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nachricht löschen?'),
        content: Text('Soll "${item.titel}" wirklich gelöscht werden?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (ok == true) await _service.deleteNews(item.id);
  }

  Widget _buildDateBadge(BuildContext context, DateTime date) {
    final day = DateFormat('dd').format(date);
    final month = DateFormat('MMM', 'de_DE').format(date).replaceAll('.', '').toUpperCase();
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            day,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              height: 1.1,
              color: colors.onSecondaryContainer,
            ),
          ),
          Text(
            month,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: colors.onSecondaryContainer.withValues(alpha: 0.8),
            ),
          ),
        ],
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
              Text('News verwalten', style: Theme.of(context).textTheme.headlineSmall),
              FilledButton.icon(
                onPressed: () => _openEditor(),
                icon: const Icon(Icons.add),
                label: const Text('Neue Nachricht'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<List<NewsItem>>(
              stream: _service.streamManageableNews(widget.permissions),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Fehler: ${snapshot.error}'));
                }

                final allItems = snapshot.data ?? [];

                final sichtbarkeiten = <String>{
                  'Alle',
                  ...allItems.map((item) => item.sichtbarkeit),
                }.toList();
                if (!sichtbarkeiten.contains(_selectedSichtbarkeit)) {
                  _selectedSichtbarkeit = 'Alle';
                }

                final filteredItems = allItems.where((item) {
                  if (_selectedSichtbarkeit != 'Alle' &&
                      item.sichtbarkeit != _selectedSichtbarkeit) {
                    return false;
                  }
                  if (_searchQuery.isNotEmpty) {
                    final q = _searchQuery.toLowerCase();
                    final matchesTitel = item.titel.toLowerCase().contains(q);
                    final matchesInhalt = item.inhalt.toLowerCase().contains(q);
                    final matchesTeam = item.sichtbarkeit.toLowerCase().contains(q);
                    if (!matchesTitel && !matchesInhalt && !matchesTeam) {
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
                          width: 300,
                          child: TextField(
                            controller: _searchCtrl,
                            decoration: InputDecoration(
                              hintText: 'Suche nach Titel, Text, Team...',
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
                          width: 240,
                          child: DropdownButtonFormField<String>(
                            value: _selectedSichtbarkeit,
                            decoration: const InputDecoration(
                              labelText: 'Team / Sichtbarkeit',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: sichtbarkeiten
                                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedSichtbarkeit = val);
                            },
                          ),
                        ),
                        Text(
                          '${filteredItems.length} Nachrichten',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: filteredItems.isEmpty
                          ? const Center(child: Text('Keine passenden Nachrichten gefunden.'))
                          : Card(
                              child: ListView.separated(
                                itemCount: filteredItems.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final item = filteredItems[index];
                                  return ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 6,
                                    ),
                                    leading: _buildDateBadge(context, item.datum),
                                    title: Text(
                                      item.titel,
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                    subtitle: Text(
                                      '${item.sichtbarkeit} • ${_dateFormat.format(item.datum)} Uhr\n${item.inhalt}',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    isThreeLine: true,
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          tooltip: 'Bearbeiten',
                                          icon: const Icon(Icons.edit_outlined),
                                          onPressed: () => _openEditor(item),
                                        ),
                                        IconButton(
                                          tooltip: 'Löschen',
                                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                                          onPressed: () => _confirmDelete(item),
                                        ),
                                      ],
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
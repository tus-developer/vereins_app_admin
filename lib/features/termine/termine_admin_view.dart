import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/user_permissions.dart';
import 'termin_model.dart';
import 'termin_service.dart';

class TermineAdminView extends StatefulWidget {
  final UserPermissions permissions;
  const TermineAdminView({super.key, required this.permissions});

  @override
  State<TermineAdminView> createState() => _TermineAdminViewState();
}

class _TermineAdminViewState extends State<TermineAdminView> {
  final _service = TerminService();
  final _dateFormat = DateFormat('EE, dd.MM.yyyy', 'de_DE');
  final _searchCtrl = TextEditingController();

  String _searchQuery = '';
  String _selectedSichtbarkeit = 'Alle';
  String _selectedTerminArt = 'Alle';
  bool _showPastEvents = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  TimeOfDay _parseZeit(String zeit) {
    final parts = zeit.split(':');
    if (parts.length == 2) {
      return TimeOfDay(
        hour: int.tryParse(parts[0]) ?? 18,
        minute: int.tryParse(parts[1]) ?? 0,
      );
    }
    return const TimeOfDay(hour: 18, minute: 0);
  }

  String _formatZeit(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _openEditor([VereinTermin? existing]) async {
    final allTeams = await _service.fetchAllTeamNames();
    final allowedOptions = widget.permissions.allowedSichtbarkeiten(allTeams);
    if (allowedOptions.isEmpty) return;

    final titelCtrl = TextEditingController(text: existing?.titel ?? '');
    final ortCtrl = TextEditingController(text: existing?.ort ?? 'Rehbachhalle Neuhofen');
    final inhaltCtrl = TextEditingController(text: existing?.inhalt ?? '');
    String terminArt = existing?.terminArt ?? 'Training';
    String sichtbarkeit = (existing != null && allowedOptions.contains(existing.sichtbarkeit))
        ? existing.sichtbarkeit
        : allowedOptions.first;
    DateTime selectedDate = existing?.datum ?? DateTime.now().add(const Duration(days: 1));
    TimeOfDay selectedTime =
        existing != null ? _parseZeit(existing.zeit) : const TimeOfDay(hour: 18, minute: 0);
    final formKey = GlobalKey<FormState>();

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Neuer Termin' : 'Termin bearbeiten'),
          content: SizedBox(
            width: 550,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: terminArt,
                            decoration: const InputDecoration(
                              labelText: 'Terminart',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'Training', child: Text('Training')),
                              DropdownMenuItem(value: 'Spiel', child: Text('Spiel')),
                              DropdownMenuItem(value: 'Event', child: Text('Event')),
                            ],
                            onChanged: (val) {
                              if (val != null) setDialogState(() => terminArt = val);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: sichtbarkeit,
                            decoration: const InputDecoration(
                              labelText: 'Sichtbarkeit',
                              border: OutlineInputBorder(),
                            ),
                            items: allowedOptions
                                .map((opt) => DropdownMenuItem(value: opt, child: Text(opt)))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) setDialogState(() => sichtbarkeit = val);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.calendar_today),
                            label: Text(_dateFormat.format(selectedDate)),
                            style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(16)),
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: ctx,
                                initialDate: selectedDate,
                                firstDate: DateTime(2024),
                                lastDate: DateTime(2035),
                              );
                              if (picked != null) {
                                setDialogState(() => selectedDate = picked);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.access_time),
                            label: Text('${_formatZeit(selectedTime)} Uhr'),
                            style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(16)),
                            onPressed: () async {
                              final picked = await showTimePicker(
                                context: ctx,
                                initialTime: selectedTime,
                              );
                              if (picked != null) {
                                setDialogState(() => selectedTime = picked);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: ortCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Ort',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: inhaltCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Beschreibung / Inhalt (optional)',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen')),
            FilledButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final now = DateTime.now();
                final termin = VereinTermin(
                  id: existing?.id ?? '',
                  titel: titelCtrl.text.trim(),
                  inhalt: inhaltCtrl.text.trim(),
                  ort: ortCtrl.text.trim(),
                  terminArt: terminArt,
                  datum: selectedDate,
                  zeit: _formatZeit(selectedTime),
                  sichtbarkeit: sichtbarkeit,
                  erstellerId: existing?.erstellerId ?? widget.permissions.uid,
                  erstelltAm: existing?.erstelltAm ?? now,
                  teilnehmer: existing?.teilnehmer ?? {},
                );
                await _service.saveTermin(termin);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Speichern'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(VereinTermin termin) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Termin löschen?'),
        content: Text('Soll "${termin.titel}" (${_dateFormat.format(termin.datum)}) wirklich gelöscht werden?'),
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
    if (ok == true) await _service.deleteTermin(termin.id);
  }

  Widget _buildDateBadge(BuildContext context, DateTime date) {
    final day = DateFormat('dd').format(date);
    final month = DateFormat('MMM', 'de_DE').format(date).replaceAll('.', '').toUpperCase();
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: colors.primaryContainer,
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
              color: colors.onPrimaryContainer,
            ),
          ),
          Text(
            month,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: colors.onPrimaryContainer.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final todayStart = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Termine verwalten', style: Theme.of(context).textTheme.headlineSmall),
              FilledButton.icon(
                onPressed: () => _openEditor(),
                icon: const Icon(Icons.add),
                label: const Text('Neuer Termin'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<List<VereinTermin>>(
              stream: _service.streamManageableTermine(widget.permissions),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Fehler: ${snapshot.error}'));
                }

                final allTermine = snapshot.data ?? [];

                // Dynamische Liste aller vorhandenen Sichtbarkeiten für das Filter-Dropdown
                final sichtbarkeiten = <String>{
                  'Alle',
                  ...allTermine.map((t) => t.sichtbarkeit),
                }.toList();
                if (!sichtbarkeiten.contains(_selectedSichtbarkeit)) {
                  _selectedSichtbarkeit = 'Alle';
                }

                // Gefilterte Liste berechnen
                final filteredTermine = allTermine.where((t) {
                  if (!_showPastEvents && t.datum.isBefore(todayStart)) {
                    return false;
                  }
                  if (_selectedSichtbarkeit != 'Alle' && t.sichtbarkeit != _selectedSichtbarkeit) {
                    return false;
                  }
                  if (_selectedTerminArt != 'Alle' && t.terminArt != _selectedTerminArt) {
                    return false;
                  }
                  if (_searchQuery.isNotEmpty) {
                    final q = _searchQuery.toLowerCase();
                    final matchesTitel = t.titel.toLowerCase().contains(q);
                    final matchesOrt = t.ort.toLowerCase().contains(q);
                    final matchesInhalt = t.inhalt.toLowerCase().contains(q);
                    final matchesTeam = t.sichtbarkeit.toLowerCase().contains(q);
                    if (!matchesTitel && !matchesOrt && !matchesInhalt && !matchesTeam) {
                      return false;
                    }
                  }
                  return true;
                }).toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Filter- und Suchleiste
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
                              hintText: 'Suche nach Titel, Ort, Team...',
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
                          width: 220,
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
                        SizedBox(
                          width: 170,
                          child: DropdownButtonFormField<String>(
                            value: _selectedTerminArt,
                            decoration: const InputDecoration(
                              labelText: 'Terminart',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: const [
                              DropdownMenuItem(value: 'Alle', child: Text('Alle Arten')),
                              DropdownMenuItem(value: 'Training', child: Text('Training')),
                              DropdownMenuItem(value: 'Spiel', child: Text('Spiel')),
                              DropdownMenuItem(value: 'Event', child: Text('Event')),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedTerminArt = val);
                            },
                          ),
                        ),
                        FilterChip(
                          label: const Text('Vergangene anzeigen'),
                          selected: _showPastEvents,
                          onSelected: (val) => setState(() => _showPastEvents = val),
                        ),
                        Text(
                          '${filteredTermine.length} Termine',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: filteredTermine.isEmpty
                          ? const Center(child: Text('Keine passenden Termine gefunden.'))
                          : Card(
                              child: ListView.separated(
                                itemCount: filteredTermine.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final t = filteredTermine[index];
                                  final rueckmeldungen = t.teilnehmer.length;
                                  return ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 6,
                                    ),
                                    leading: _buildDateBadge(context, t.datum),
                                    title: Text(
                                      '${t.titel} (${t.terminArt})',
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                    subtitle: Text(
                                      '${_dateFormat.format(t.datum)} • ${t.zeit} Uhr • ${t.sichtbarkeit}'
                                      '${t.ort.isNotEmpty ? ' • ${t.ort}' : ''}'
                                      '${rueckmeldungen > 0 ? ' • $rueckmeldungen ${rueckmeldungen == 1 ? 'Rückmeldung' : 'Rückmeldungen'}' : ''}',
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          tooltip: 'Bearbeiten',
                                          icon: const Icon(Icons.edit_outlined),
                                          onPressed: () => _openEditor(t),
                                        ),
                                        IconButton(
                                          tooltip: 'Löschen',
                                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                                          onPressed: () => _confirmDelete(t),
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
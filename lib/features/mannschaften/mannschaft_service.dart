import 'package:cloud_firestore/cloud_firestore.dart';
import 'mannschaft_model.dart';

typedef MannschaftList = List<Mannschaft>;
typedef UserSummaryList = List<UserSummaryItem>;

class UserSummaryItem {
  final String uid;
  final String label;

  const UserSummaryItem({
    required this.uid,
    required this.label,
  });
}

class TeamMemberEntry {
  final String userUid;
  final String displayName;
  final String subtitle;
  final String category; // 'trainer', 'spieler', 'eltern'
  final String status; // 'freigegeben' oder 'ausstehend'
  final bool isChild;
  final int arrayIndex; // Index im rollen- bzw. kinder-Array für direktes Bearbeiten
  final List<String> relatedNames; // Verknüpfte Eltern (bei Kindern) bzw. Kinder (bei Eltern)
  final bool hasExplicitRole;

  TeamMemberEntry({
    required this.userUid,
    required this.displayName,
    required this.subtitle,
    required this.category,
    required this.status,
    required this.isChild,
    required this.arrayIndex,
    this.relatedNames = const [],
    this.hasExplicitRole = false,
  });

  bool get isFreigegeben => status == 'freigegeben';
}

class TeamRoster {
  final List<TeamMemberEntry> trainer;
  final List<TeamMemberEntry> spieler;
  final List<TeamMemberEntry> eltern;

  TeamRoster({
    required this.trainer,
    required this.spieler,
    required this.eltern,
  });

  int get totalCount => trainer.length + spieler.length + eltern.length;
}

class MannschaftService {
  final _teamsRef = FirebaseFirestore.instance.collection('mannschaften');
  final _usersRef = FirebaseFirestore.instance.collection('benutzer');

  Stream<MannschaftList> streamMannschaften() {
    return _teamsRef.snapshots().map((snap) {
      final list = snap.docs.map(Mannschaft.fromFirestore).toList();
      list.sort((a, b) {
        final cmp = a.sortIndex.compareTo(b.sortIndex);
        if (cmp != 0) return cmp;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      return list;
    });
  }

  Future<void> saveMannschaft(Mannschaft team) async {
    if (team.id.isEmpty) {
      await _teamsRef.add(team.toMap());
    } else {
      await _teamsRef.doc(team.id).update(team.toMap());
    }
  }

  Future<void> deleteMannschaft(String id) async {
    await _teamsRef.doc(id).delete();
  }

  /// Streamt alle zugeordneten Trainer, Spieler, Kinder und Eltern (ohne Dubletten)
  Stream<TeamRoster> streamTeamRoster(String teamName) {
    return _usersRef.snapshots().map((snap) {
      final trainer = <TeamMemberEntry>[];
      final spieler = <TeamMemberEntry>[];
      final eltern = <TeamMemberEntry>[];

      for (final doc in snap.docs) {
        final data = doc.data();
        final uid = doc.id;
        final vorname = (data['vorname'] ?? '').toString().trim();
        final nachname = (data['nachname'] ?? '').toString().trim();
        final email = (data['email'] ?? '').toString().trim();
        final fullName = '$vorname $nachname'.trim().isNotEmpty
            ? '$vorname $nachname'.trim()
            : email;

        int? elternRoleIndex;
        String elternRoleStatus = 'freigegeben';

        // 1. Direkte Rollen im Team auswerten
        final rollen = data['rollen'] as List<dynamic>? ?? [];
        for (int i = 0; i < rollen.length; i++) {
          final r = Map<String, dynamic>.from(rollen[i]);
          if (r['team'] == teamName) {
            final rolleName = (r['rolle'] ?? '').toString();
            final rLower = rolleName.toLowerCase();
            final status = rLower == 'superadmin'
                ? 'freigegeben'
                : (r['status'] ?? 'ausstehend').toString();

            if (rLower.contains('trainer') ||
                rLower.contains('betreuer') ||
                rLower == 'teamadmin') {
              trainer.add(TeamMemberEntry(
                userUid: uid,
                displayName: fullName,
                subtitle: rolleName,
                category: 'trainer',
                status: status,
                isChild: false,
                arrayIndex: i,
                hasExplicitRole: true,
              ));
            } else if (rLower.contains('spieler')) {
              spieler.add(TeamMemberEntry(
                userUid: uid,
                displayName: fullName,
                subtitle: 'Aktive/r Spieler/in',
                category: 'spieler',
                status: status,
                isChild: false,
                arrayIndex: i,
                hasExplicitRole: true,
              ));
            } else if (rLower == 'eltern') {
              elternRoleIndex = i;
              elternRoleStatus = status;
            }
          }
        }

        // 2. Verknüpfte Kinder im Team auswerten
        final kinder = data['kinder'] as List<dynamic>? ?? [];
        final kinderInTeam = <String>[];
        String kindStatusForParent = 'freigegeben';

        for (int i = 0; i < kinder.length; i++) {
          final k = Map<String, dynamic>.from(kinder[i]);
          if (k['team'] == teamName) {
            final kVorname = (k['vorname'] ?? '').toString().trim();
            final kNachname = (k['nachname'] ?? '').toString().trim();
            final kName = '$kVorname $kNachname'.trim();
            final kGeb = (k['gebDatum'] ?? '').toString().trim();
            final status = (k['status'] ?? 'ausstehend').toString();

            if (status != 'freigegeben') {
              kindStatusForParent = status;
            }
            kinderInTeam.add(kName.isNotEmpty ? kName : 'Kind');

            spieler.add(TeamMemberEntry(
              userUid: uid,
              displayName: kName.isNotEmpty ? kName : 'Kind ($fullName)',
              subtitle:
                  'Jugendspieler/in${kGeb.isNotEmpty ? ' • Geb.: $kGeb' : ''}',
              category: 'spieler',
              status: status,
              isChild: true,
              arrayIndex: i,
              relatedNames: [fullName],
            ));
          }
        }

        // 3. Elternteil genau EINMAL hinzufügen (Rolle + Kinder zusammengeführt)
        if (elternRoleIndex != null || kinderInTeam.isNotEmpty) {
          final combinedStatus =
              (elternRoleIndex != null && elternRoleStatus != 'freigegeben')
                  ? elternRoleStatus
                  : kindStatusForParent;

          final subtitleText = elternRoleIndex != null
              ? 'Eltern-Rolle aktiv'
              : 'Über Kind-Zuordnung verknüpft';

          eltern.add(TeamMemberEntry(
            userUid: uid,
            displayName: fullName,
            subtitle: subtitleText,
            category: 'eltern',
            status: combinedStatus,
            isChild: false,
            arrayIndex: elternRoleIndex ?? -1,
            relatedNames: kinderInTeam,
            hasExplicitRole: elternRoleIndex != null,
          ));
        }
      }

      int byName(TeamMemberEntry a, TeamMemberEntry b) =>
          a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());

      trainer.sort(byName);
      spieler.sort(byName);
      eltern.sort(byName);

      return TeamRoster(trainer: trainer, spieler: spieler, eltern: eltern);
    });
  }

  Future<void> approveTeamEntry(TeamMemberEntry entry) async {
    final docRef = _usersRef.doc(entry.userUid);
    final snap = await docRef.get();
    if (!snap.exists || snap.data() == null) return;

    final data = snap.data()!;
    if (entry.isChild) {
      final kinder = List<dynamic>.from(data['kinder'] ?? []);
      if (entry.arrayIndex >= 0 && entry.arrayIndex < kinder.length) {
        final updated = Map<String, dynamic>.from(kinder[entry.arrayIndex]);
        updated['status'] = 'freigegeben';
        kinder[entry.arrayIndex] = updated;
        await docRef.update({'kinder': kinder});
      }
    } else {
      final rollen = List<dynamic>.from(data['rollen'] ?? []);
      if (entry.arrayIndex >= 0 && entry.arrayIndex < rollen.length) {
        final updated = Map<String, dynamic>.from(rollen[entry.arrayIndex]);
        updated['status'] = 'freigegeben';
        rollen[entry.arrayIndex] = updated;
        await docRef.update({'rollen': rollen});
      }
    }
  }

  Future<void> removeTeamEntry(TeamMemberEntry entry) async {
    final docRef = _usersRef.doc(entry.userUid);
    final snap = await docRef.get();
    if (!snap.exists || snap.data() == null) return;

    final data = snap.data()!;
    if (entry.isChild) {
      final kinder = List<dynamic>.from(data['kinder'] ?? []);
      if (entry.arrayIndex >= 0 && entry.arrayIndex < kinder.length) {
        kinder.removeAt(entry.arrayIndex);
        await docRef.update({'kinder': kinder});
      }
    } else {
      final rollen = List<dynamic>.from(data['rollen'] ?? []);
      if (entry.arrayIndex >= 0 && entry.arrayIndex < rollen.length) {
        rollen.removeAt(entry.arrayIndex);
        await docRef.update({'rollen': rollen});
      }
    }
  }

  Future<UserSummaryList> fetchAllUsersSummary() async {
    final snap = await _usersRef.get();
    final list = snap.docs.map((doc) {
      final d = doc.data();
      final name = '${d['vorname'] ?? ''} ${d['nachname'] ?? ''}'.trim();
      final email = (d['email'] ?? '').toString();
      return UserSummaryItem(
        uid: doc.id,
        label: name.isNotEmpty ? '$name ($email)' : email,
      );
    }).toList();
    list.sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    return list;
  }

  Future<void> addRoleToUser({
    required String uid,
    required String rolle,
    required String teamName,
  }) async {
    final docRef = _usersRef.doc(uid);
    final snap = await docRef.get();
    if (!snap.exists || snap.data() == null) return;

    final rollen = List<dynamic>.from(snap.data()!['rollen'] ?? []);
    rollen.add({
      'rolle': rolle,
      'team': teamName,
      'status': 'freigegeben',
    });
    await docRef.update({'rollen': rollen});
  }
}
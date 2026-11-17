import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/user_permissions.dart';
import 'benutzer_model.dart';

class BenutzerService {
  final _usersRef = FirebaseFirestore.instance.collection('benutzer');
  final _teamsRef = FirebaseFirestore.instance.collection('mannschaften');

  Future<List<String>> fetchAllTeamNames() async {
    final snap = await _teamsRef.get();
    final teams = snap.docs.map((doc) {
      final data = doc.data();
      return (data['name'] as String?) ?? doc.id;
    }).toList()
      ..sort();
    return teams;
  }

  Stream<List<VereinBenutzer>> streamManageableUsers(UserPermissions perms) {
    return _usersRef.snapshots().map((snap) {
      final allUsers = snap.docs.map(VereinBenutzer.fromFirestore).toList();

      // Alphabetisch nach Nachname, Vorname sortieren
      allUsers.sort((a, b) => a.nachname.toLowerCase().compareTo(b.nachname.toLowerCase()));

      if (perms.isSuperadmin || perms.isAbteilungsAdmin) {
        return allUsers;
      }

      // Teamadmins sehen nur Benutzer, die eine Rolle oder ein Kind in ihren Teams haben
      return allUsers.where((u) {
        final hasTeamRole = u.rollen.any((r) => perms.teamAdminOnlyTeams.contains(r.team));
        final hasTeamChild = u.kinder.any((k) => perms.teamAdminOnlyTeams.contains(k.team));
        return hasTeamRole || hasTeamChild;
      }).toList();
    });
  }

  Future<void> updateRollen(String uid, List<BenutzerRolle> rollen) async {
    await _usersRef.doc(uid).update({
      'rollen': rollen.map((r) => r.toMap()).toList(),
    });
  }

  Future<void> updateKinder(String uid, List<BenutzerKind> kinder) async {
    await _usersRef.doc(uid).update({
      'kinder': kinder.map((k) => k.toMap()).toList(),
    });
  }

  Future<void> updateStammdaten({
    required String uid,
    required String vorname,
    required String nachname,
    required String telefon,
    required String strasse,
    required String plzOrt,
    required String notfallKontakt,
  }) async {
    await _usersRef.doc(uid).update({
      'vorname': vorname,
      'nachname': nachname,
      'telefon': telefon,
      'strasse': strasse,
      'plzOrt': plzOrt,
      'notfallKontakt': notfallKontakt,
    });
  }
}
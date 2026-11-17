import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/user_permissions.dart';
import 'termin_model.dart';

class TerminService {
  final _termineRef = FirebaseFirestore.instance.collection('termine');
  final _teamsRef = FirebaseFirestore.instance.collection('mannschaften');

  Future<List<String>> fetchAllTeamNames() async {
    final snap = await _teamsRef.get();
    return snap.docs.map((doc) {
      final data = doc.data();
      return (data['name'] as String?) ?? doc.id;
    }).toList()
      ..sort();
  }

  Stream<List<VereinTermin>> streamManageableTermine(UserPermissions perms) {
    return _termineRef
        .orderBy('datum', descending: false)
        .snapshots()
        .map((snap) => snap.docs
            .map(VereinTermin.fromFirestore)
            .where((t) => perms.canManageSichtbarkeit(t.sichtbarkeit))
            .toList());
  }

  Future<void> saveTermin(VereinTermin termin) async {
    if (termin.id.isEmpty) {
      await _termineRef.add(termin.toCreateMap());
    } else {
      await _termineRef.doc(termin.id).update(termin.toUpdateMap());
    }
  }

  Future<void> deleteTermin(String id) async {
    await _termineRef.doc(id).delete();
  }
}
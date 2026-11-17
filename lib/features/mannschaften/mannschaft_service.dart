import 'package:cloud_firestore/cloud_firestore.dart';
import 'mannschaft_model.dart';

class MannschaftService {
  final _teamsRef = FirebaseFirestore.instance.collection('mannschaften');

  Stream<List<Mannschaft>> streamMannschaften() {
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
}
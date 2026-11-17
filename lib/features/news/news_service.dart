import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/user_permissions.dart';
import 'news_model.dart';

class NewsService {
  final _newsRef = FirebaseFirestore.instance.collection('news');
  final _teamsRef = FirebaseFirestore.instance.collection('mannschaften');

  Future<List<String>> fetchAllTeamNames() async {
    final snap = await _teamsRef.get();
    return snap.docs.map((doc) {
      final data = doc.data();
      return (data['name'] as String?) ?? doc.id;
    }).toList()
      ..sort();
  }

  Stream<List<NewsItem>> streamManageableNews(UserPermissions perms) {
    return _newsRef
        .orderBy('datum', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map(NewsItem.fromFirestore)
            .where((item) => perms.canManageSichtbarkeit(item.sichtbarkeit))
            .toList());
  }

  Future<void> saveNews(NewsItem item) async {
    if (item.id.isEmpty) {
      await _newsRef.add(item.toCreateMap());
    } else {
      await _newsRef.doc(item.id).update(item.toUpdateMap());
    }
  }

  Future<void> deleteNews(String id) async {
    await _newsRef.doc(id).delete();
  }
}
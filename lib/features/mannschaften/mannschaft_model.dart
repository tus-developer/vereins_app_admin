import 'package:cloud_firestore/cloud_firestore.dart';

class Mannschaft {
  final String id;
  final String name;
  final int sortIndex;

  Mannschaft({
    required this.id,
    required this.name,
    required this.sortIndex,
  });

  factory Mannschaft.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Mannschaft(
      id: doc.id,
      name: data['name']?.toString() ?? '',
      sortIndex: (data['sortIndex'] as num?)?.toInt() ?? 999,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'sortIndex': sortIndex,
    };
  }
}
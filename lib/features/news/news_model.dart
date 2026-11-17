import 'package:cloud_firestore/cloud_firestore.dart';

class NewsItem {
  final String id;
  final String titel;
  final String inhalt;
  final String sichtbarkeit;
  final DateTime datum;
  final DateTime erstelltAm;
  final String erstellerId;

  NewsItem({
    required this.id,
    required this.titel,
    required this.inhalt,
    required this.sichtbarkeit,
    required this.datum,
    required this.erstelltAm,
    required this.erstellerId,
  });

  factory NewsItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NewsItem(
      id: doc.id,
      titel: data['titel'] ?? '',
      inhalt: data['inhalt'] ?? '',
      sichtbarkeit: data['sichtbarkeit'] ?? 'Öffentlich',
      datum: (data['datum'] as Timestamp?)?.toDate() ?? DateTime.now(),
      erstelltAm: (data['erstelltAm'] as Timestamp?)?.toDate() ?? DateTime.now(),
      erstellerId: data['erstellerId'] ?? '',
    );
  }

  Map<String, dynamic> toCreateMap() {
    return {
      'titel': titel,
      'inhalt': inhalt,
      'sichtbarkeit': sichtbarkeit,
      'datum': Timestamp.fromDate(datum),
      'erstelltAm': Timestamp.fromDate(erstelltAm),
      'erstellerId': erstellerId,
    };
  }

  Map<String, dynamic> toUpdateMap() {
    return {
      'titel': titel,
      'inhalt': inhalt,
      'sichtbarkeit': sichtbarkeit,
      'datum': Timestamp.fromDate(datum),
    };
  }
}
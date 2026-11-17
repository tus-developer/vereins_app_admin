import 'package:cloud_firestore/cloud_firestore.dart';

class VereinTermin {
  final String id;
  final String titel;
  final String inhalt;
  final String ort;
  final String terminArt;
  final DateTime datum;
  final String zeit;
  final String sichtbarkeit;
  final String erstellerId;
  final DateTime erstelltAm;
  final Map<String, dynamic> teilnehmer;

  VereinTermin({
    required this.id,
    required this.titel,
    required this.inhalt,
    required this.ort,
    required this.terminArt,
    required this.datum,
    required this.zeit,
    required this.sichtbarkeit,
    required this.erstellerId,
    required this.erstelltAm,
    required this.teilnehmer,
  });

  factory VereinTermin.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return VereinTermin(
      id: doc.id,
      titel: data['titel'] ?? '',
      inhalt: data['inhalt'] ?? '',
      ort: data['ort'] ?? '',
      terminArt: data['terminArt'] ?? 'Training',
      datum: (data['datum'] as Timestamp?)?.toDate() ?? DateTime.now(),
      zeit: data['zeit'] ?? '18:00',
      sichtbarkeit: data['sichtbarkeit'] ?? 'Öffentlich',
      erstellerId: data['erstellerId'] ?? '',
      erstelltAm: (data['erstelltAm'] as Timestamp?)?.toDate() ?? DateTime.now(),
      teilnehmer: Map<String, dynamic>.from(data['teilnehmer'] ?? {}),
    );
  }

  Map<String, dynamic> toCreateMap() {
    final dateOnly = DateTime(datum.year, datum.month, datum.day);
    return {
      'titel': titel,
      'inhalt': inhalt,
      'ort': ort,
      'terminArt': terminArt,
      'datum': Timestamp.fromDate(dateOnly),
      'zeit': zeit,
      'sichtbarkeit': sichtbarkeit,
      'erstellerId': erstellerId,
      'erstelltAm': Timestamp.fromDate(erstelltAm),
      'teilnehmer': {},
    };
  }

  Map<String, dynamic> toUpdateMap() {
    final dateOnly = DateTime(datum.year, datum.month, datum.day);
    return {
      'titel': titel,
      'inhalt': inhalt,
      'ort': ort,
      'terminArt': terminArt,
      'datum': Timestamp.fromDate(dateOnly),
      'zeit': zeit,
      'sichtbarkeit': sichtbarkeit,
    };
  }
}
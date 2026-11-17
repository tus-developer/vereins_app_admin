import 'package:cloud_firestore/cloud_firestore.dart';

class BenutzerRolle {
  final String rolle;
  final String team;
  final String? status;

  BenutzerRolle({
    required this.rolle,
    required this.team,
    this.status,
  });

  factory BenutzerRolle.fromMap(Map<String, dynamic> map) {
    return BenutzerRolle(
      rolle: map['rolle'] ?? '',
      team: map['team'] ?? '',
      status: map['status'],
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'rolle': rolle,
      'team': team,
    };
    if (status != null) {
      map['status'] = status;
    }
    return map;
  }

  bool get isFreigegeben => rolle == 'Superadmin' || status == 'freigegeben';
}

class BenutzerKind {
  final String vorname;
  final String nachname;
  final String gebDatum;
  final String team;
  final String status;
  final Map<String, dynamic>? handballDaten;

  BenutzerKind({
    required this.vorname,
    required this.nachname,
    required this.gebDatum,
    required this.team,
    required this.status,
    this.handballDaten,
  });

  factory BenutzerKind.fromMap(Map<String, dynamic> map) {
    return BenutzerKind(
      vorname: map['vorname'] ?? '',
      nachname: map['nachname'] ?? '',
      gebDatum: map['gebDatum'] ?? '',
      team: map['team'] ?? '',
      status: map['status'] ?? 'ausstehend',
      handballDaten: map['handball_daten'] != null
          ? Map<String, dynamic>.from(map['handball_daten'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'vorname': vorname,
      'nachname': nachname,
      'gebDatum': gebDatum,
      'team': team,
      'status': status,
      if (handballDaten != null) 'handball_daten': handballDaten,
    };
  }
}

class VereinBenutzer {
  final String uid;
  final String vorname;
  final String nachname;
  final String email;
  final String telefon;
  final String strasse;
  final String plzOrt;
  final String gebDatum;
  final String notfallKontakt;
  final DateTime? registriertAm;
  final List<BenutzerRolle> rollen;
  final List<BenutzerKind> kinder;

  VereinBenutzer({
    required this.uid,
    required this.vorname,
    required this.nachname,
    required this.email,
    required this.telefon,
    required this.strasse,
    required this.plzOrt,
    required this.gebDatum,
    required this.notfallKontakt,
    this.registriertAm,
    required this.rollen,
    required this.kinder,
  });

  String get fullName {
    final name = '$vorname $nachname'.trim();
    return name.isNotEmpty ? name : email;
  }

  bool get hasOpenRequests =>
      rollen.any((r) => !r.isFreigegeben) ||
      kinder.any((k) => k.status != 'freigegeben');

  factory VereinBenutzer.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    final rollenList = (data['rollen'] as List<dynamic>? ?? [])
        .map((e) => BenutzerRolle.fromMap(Map<String, dynamic>.from(e)))
        .toList();

    final kinderList = (data['kinder'] as List<dynamic>? ?? [])
        .map((e) => BenutzerKind.fromMap(Map<String, dynamic>.from(e)))
        .toList();

    return VereinBenutzer(
      uid: doc.id,
      vorname: data['vorname'] ?? '',
      nachname: data['nachname'] ?? '',
      email: data['email'] ?? '',
      telefon: data['telefon'] ?? '',
      strasse: data['strasse'] ?? '',
      plzOrt: data['plzOrt'] ?? '',
      gebDatum: data['gebDatum'] ?? '',
      notfallKontakt: data['notfallKontakt'] ?? '',
      registriertAm: (data['registriertAm'] as Timestamp?)?.toDate(),
      rollen: rollenList,
      kinder: kinderList,
    );
  }
}
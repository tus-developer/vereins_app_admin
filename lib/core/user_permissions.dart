import 'package:cloud_firestore/cloud_firestore.dart';

class UserRoleEntry {
  final String rolle;
  final String team;
  final String? status;

  UserRoleEntry({
    required this.rolle,
    required this.team,
    this.status,
  });

  factory UserRoleEntry.fromMap(Map<String, dynamic> map) {
    return UserRoleEntry(
      rolle: map['rolle'] ?? '',
      team: map['team'] ?? '',
      status: map['status'],
    );
  }

  /// Superadmin hat in Firestore kein 'status'-Feld, alle anderen brauchen 'freigegeben'
  bool get isActive => rolle == 'Superadmin' || status == 'freigegeben';
}

class UserPermissions {
  final String uid;
  final String vorname;
  final String nachname;
  final bool isSuperadmin;
  final bool isAbteilungsAdmin;
  final List<String> adminTeams;

  UserPermissions({
    required this.uid,
    required this.vorname,
    required this.nachname,
    required this.isSuperadmin,
    required this.isAbteilungsAdmin,
    required this.adminTeams,
  });

  bool get hasWebAdminAccess =>
      isSuperadmin || isAbteilungsAdmin || adminTeams.isNotEmpty;

  String get fullName => '$vorname $nachname'.trim();

  bool canManageSichtbarkeit(String sichtbarkeit) {
    if (isSuperadmin) return true;
    if (isAbteilungsAdmin &&
        (sichtbarkeit == 'TuS Neuhofen Handball' ||
            sichtbarkeit.startsWith('Team '))) {
      return true;
    }
    if (sichtbarkeit.startsWith('Team ')) {
      final teamName = sichtbarkeit.replaceFirst('Team ', '');
      return adminTeams.contains(teamName);
    }
    return false;
  }

  List<String> allowedSichtbarkeiten(List<String> allTeamNames) {
    final options = <String>[];
    if (isSuperadmin) {
      options.addAll(['Öffentlich', 'Verein', 'TuS Neuhofen Handball']);
      for (final team in allTeamNames) {
        options.add('Team $team');
      }
    } else if (isAbteilungsAdmin) {
      options.add('TuS Neuhofen Handball');
      for (final team in allTeamNames) {
        options.add('Team $team');
      }
    } else {
      for (final team in adminTeams) {
        options.add('Team $team');
      }
    }
    return options.toSet().toList();
  }

  static Future<UserPermissions?> loadForUser(String uid) async {
    final doc = await FirebaseFirestore.instance
        .collection('benutzer')
        .doc(uid)
        .get();

    if (!doc.exists || doc.data() == null) return null;

    final data = doc.data()!;
    final rawRollen = (data['rollen'] as List<dynamic>? ?? [])
        .map((e) => UserRoleEntry.fromMap(Map<String, dynamic>.from(e)))
        .where((r) => r.isActive)
        .toList();

    final isSuperadmin = rawRollen.any((r) => r.rolle == 'Superadmin');
    final isAbteilungsAdmin = rawRollen.any(
      (r) => r.rolle == 'Abteilungsleiter' || r.rolle == 'Jugendleiter',
    );

    final adminTeams = rawRollen
        .where((r) => r.rolle == 'Teamadmin' || r.rolle == 'Trainer')
        .map((r) => r.team)
        .where((t) => t.isNotEmpty)
        .toSet()
        .toList();

    return UserPermissions(
      uid: uid,
      vorname: data['vorname'] ?? '',
      nachname: data['nachname'] ?? '',
      isSuperadmin: isSuperadmin,
      isAbteilungsAdmin: isAbteilungsAdmin,
      adminTeams: adminTeams,
    );
  }
}
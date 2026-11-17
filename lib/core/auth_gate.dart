import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../features/auth/login_screen.dart';
import 'user_permissions.dart';
import 'admin_shell.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final user = snapshot.data;
        if (user == null) {
          return const LoginScreen();
        }

        return FutureBuilder<UserPermissions?>(
          future: UserPermissions.loadForUser(user.uid),
          builder: (context, permSnap) {
            if (permSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            final perms = permSnap.data;
            if (perms != null && perms.hasWebAdminAccess) {
              return AdminShell(permissions: perms);
            }

            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    const Text(
                      'Keine Admin- oder Trainer-Berechtigung für die Web-Oberfläche hinterlegt.',
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => FirebaseAuth.instance.signOut(),
                      child: const Text('Abmelden'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
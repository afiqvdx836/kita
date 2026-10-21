import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/stream_view.dart';
import 'data/models.dart';
import 'data/repo.dart';
import 'features/auth/sign_in_screen.dart';
import 'features/home/home_shell.dart';
import 'features/pairing/pairing_screen.dart';

class KitaApp extends StatelessWidget {
  const KitaApp({super.key});

  @override
  Widget build(BuildContext context) {
    ThemeData theme(Brightness b) => ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFD9485F),
            brightness: b,
          ),
          useMaterial3: true,
        );

    return MaterialApp(
      title: 'Kita',
      debugShowCheckedModeBanner: false,
      theme: theme(Brightness.light),
      darkTheme: theme(Brightness.dark),
      home: const AuthGate(),
    );
  }
}

/// Signed out → sign in. Signed in → [CoupleGate].
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = Repo.instance;
    return StreamBuilder<AuthState>(
      stream: repo.authChanges,
      builder: (context, _) {
        final session = repo.session;
        if (session == null) return const SignInScreen();
        return CoupleGate(key: ValueKey(session.user.id));
      },
    );
  }
}

/// Not paired yet (no couple, or a couple of one) → pairing. Paired → home.
class CoupleGate extends StatelessWidget {
  const CoupleGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamView<Profile?>(
      create: Repo.instance.watchMe,
      builder: (context, snap) {
        final me = snap.data;
        if (me == null) return const _Loading();
        final coupleId = me.coupleId;
        if (coupleId == null) return const PairingScreen();
        return _MembersGate(key: ValueKey(coupleId), me: me, coupleId: coupleId);
      },
    );
  }
}

class _MembersGate extends StatelessWidget {
  const _MembersGate({super.key, required this.me, required this.coupleId});

  final Profile me;
  final String coupleId;

  @override
  Widget build(BuildContext context) {
    return StreamView<List<Profile>>(
      create: () => Repo.instance.watchMembers(coupleId),
      builder: (context, snap) {
        final members = snap.data;
        if (members == null) return const _Loading();
        final partner = members.where((p) => p.id != me.id).firstOrNull;
        if (partner == null) return const PairingScreen();
        return HomeShell(me: me, partner: partner, coupleId: coupleId);
      },
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

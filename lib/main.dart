import 'dart:async';

import 'package:crmx/authpage.dart';
import 'package:crmx/base.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';
import 'package:crmx/themes/light_theme.dart';

// =======================
// AUTH STATUS
// =======================
enum AuthStatus {
  unknown,
  authenticated,
  authenticatedAnonymous,
  unauthenticated,
}

// =======================
// AUTH NOTIFIER
// =======================
class AuthNotifier extends ChangeNotifier {
  StreamSubscription<User?>? _authSubscription;
  User? _user;
  AuthStatus _status = AuthStatus.unknown;

  AuthNotifier() {
    _authSubscription =
        FirebaseAuth.instance.idTokenChanges().listen(_onAuthStateChanged);
  }

  void _onAuthStateChanged(User? user) {
    _user = user;

    if (user == null) {
      _status = AuthStatus.unauthenticated;
    } else if (user.isAnonymous) {
      _status = AuthStatus.authenticatedAnonymous;
    } else {
      _status = AuthStatus.authenticated;
    }

    notifyListeners();
  }

  User? get user => _user;
  AuthStatus get status => _status;

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}

// =======================
// MAIN
// =======================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthNotifier()),
      ],
      child: const MyApp(),
    ),
  );
}

// =======================
// APP ROOT
// =======================
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'journeytale',
      theme: adminLightTheme,
      debugShowCheckedModeBanner: false,
      home: const RootGate(),
    );
  }
}

// =======================
// AUTH GATE (REPLACES GoRouter)
// =======================
class RootGate extends StatelessWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();

    switch (auth.status) {
      case AuthStatus.unknown:
        return const SplashPage();

      case AuthStatus.unauthenticated:
      case AuthStatus.authenticatedAnonymous:
        return const LoginOrRegister();

      case AuthStatus.authenticated:
        return const Base(); // 👈 MAIN ADMIN BASE
    }
  }
}

// =======================
// PLACEHOLDER PAGES
// (Replace with your real ones)
// =======================

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}



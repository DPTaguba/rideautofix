import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/ride_repository.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import '../viewmodels/ride_view_model.dart';
import 'admin_shell.dart';
import 'auth_pages.dart';
import 'customer_shell.dart';

class RideAutoFixApp extends StatefulWidget {
  const RideAutoFixApp({super.key, this.repository, this.startupError});
  final RideRepository? repository;
  final Object? startupError;

  @override
  State<RideAutoFixApp> createState() => _RideAutoFixAppState();
}

class _RideAutoFixAppState extends State<RideAutoFixApp> {
  final _navKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    final repo = widget.repository;
    return MaterialApp(
      title: 'RideAutoFix',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      navigatorKey: _navKey,
      // The session sits ABOVE the Navigator so every pushed page can reach it.
      builder: repo == null
          ? null
          : (context, child) => SessionHost(
              repository: repo,
              navigatorKey: _navKey,
              child: child ?? const SizedBox.shrink(),
            ),
      home: repo == null
          ? StartupErrorPage(error: widget.startupError)
          : const SessionRouter(),
    );
  }
}

// ---- session --------------------------------------------------------------

enum SessionStatus { loading, signedOut, profileMissing, error, ready }

class Session {
  const Session(this.status, {this.user, this.profile, this.error});
  final SessionStatus status;
  final User? user;
  final Map<String, dynamic>? profile;
  final Object? error;

  bool get isAdmin => profile?['role'] == 'admin';
}

class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.repository,
    required this.vm,
    required this.session,
    required super.child,
  });
  final RideRepository repository;
  final RideViewModel vm;
  final Session session;

  static AppScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!;

  /// Reads without subscribing to rebuilds (use inside initState).
  static AppScope read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!;

  String get uid => session.user?.uid ?? '';
  Map<String, dynamic> get profile => session.profile ?? const {};

  @override
  bool updateShouldNotify(AppScope old) => !identical(session, old.session);
}

class SessionHost extends StatefulWidget {
  const SessionHost({
    super.key,
    required this.repository,
    required this.navigatorKey,
    required this.child,
  });
  final RideRepository repository;
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  State<SessionHost> createState() => _SessionHostState();
}

class _SessionHostState extends State<SessionHost> {
  late final RideViewModel _vm = RideViewModel(widget.repository);
  StreamSubscription<User?>? _authSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profileSub;
  Session _core = const Session(SessionStatus.loading);
  bool _splashDone = false;

  @override
  void initState() {
    super.initState();
    _authSub = widget.repository.authChanges().listen(
      _onUser,
      onError: (Object e) =>
          setState(() => _core = Session(SessionStatus.error, error: e)),
    );
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _splashDone = true);
    });
  }

  void _onUser(User? user) {
    _profileSub?.cancel();
    _profileSub = null;
    if (user == null) {
      setState(() => _core = const Session(SessionStatus.signedOut));
      widget.navigatorKey.currentState?.popUntil((r) => r.isFirst);
      return;
    }
    setState(() => _core = Session(SessionStatus.loading, user: user));
    _profileSub = widget.repository.profile(user.uid).listen(
      (doc) => setState(
        () => _core = doc.exists
            ? Session(SessionStatus.ready, user: user, profile: doc.data())
            : Session(SessionStatus.profileMissing, user: user),
      ),
      onError: (Object e) => setState(
        () => _core = Session(SessionStatus.error, user: user, error: e),
      ),
    );
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _profileSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = _splashDone ? _core : const Session(SessionStatus.loading);
    return AppScope(
      repository: widget.repository,
      vm: _vm,
      session: session,
      child: widget.child,
    );
  }
}

class SessionRouter extends StatelessWidget {
  const SessionRouter({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final s = scope.session;
    switch (s.status) {
      case SessionStatus.loading:
        return const SplashPage();
      case SessionStatus.signedOut:
        return const AuthFlow();
      case SessionStatus.profileMissing:
        return const AccountSetupPage();
      case SessionStatus.error:
        return ProblemPage(
          message: friendlyError(s.error ?? 'error'),
          canSignOut: s.user != null,
        );
      case SessionStatus.ready:
        return s.isAdmin
            ? AdminShell(key: ValueKey('admin-${s.user!.uid}'))
            : CustomerShell(key: ValueKey('cust-${s.user!.uid}'));
    }
  }
}

// ---- simple full-screen states -------------------------------------------

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const BrandLogo(size: 110),
          const SizedBox(height: 20),
          Text(
            'R.A.F.',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
          const Text('RideAutoFix', style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 4),
          const Text(
            'Home-service repair, booked in minutes',
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 28),
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
        ],
      ),
    ),
  );
}

class AccountSetupPage extends StatelessWidget {
  const AccountSetupPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            const Text('Setting up your account…'),
            const SizedBox(height: 4),
            const Text(
              'This should only take a moment.',
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => AppScope.of(context).repository.signOut(),
              child: const Text('Sign out'),
            ),
          ],
        ),
      ),
    ),
  );
}

class ProblemPage extends StatelessWidget {
  const ProblemPage({super.key, required this.message, this.canSignOut = false});
  final String message;
  final bool canSignOut;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ErrorState(message: message),
    ),
    bottomNavigationBar: canSignOut
        ? SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: OutlinedButton(
                onPressed: () => AppScope.of(context).repository.signOut(),
                child: const Text('Sign out'),
              ),
            ),
          )
        : null,
  );
}

class StartupErrorPage extends StatelessWidget {
  const StartupErrorPage({super.key, this.error});
  final Object? error;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: EmptyState(
        icon: Icons.settings_suggest_outlined,
        title: 'App could not start',
        message:
            'Firebase failed to initialise. Check firebase_options.dart and your internet connection.\n\n$error',
      ),
    ),
  );
}
import 'package:flutter/foundation.dart';
import '../data/ride_repository.dart';

class AuthViewModel extends ChangeNotifier {
  AuthViewModel(this.repository);
  final RideRepository repository;
  bool busy = false;
  String? error;
  String? message;

  void setError(String value) {
    error = value;
    notifyListeners();
  }

  Future<bool> signIn(String email, String password) => _run(() => repository.signIn(email, password));
  Future<bool> register(String name, String phone, String email, String password) =>
      _run(() => repository.register(name, phone, email, password));
  Future<bool> resetPassword(String email) async {
    final ok = await _run(() => repository.sendPasswordReset(email));
    if (ok) message = 'Password reset link sent. Check your email.';
    notifyListeners();
    return ok;
  }

  Future<bool> _run(Future<void> Function() action) async {
    busy = true; error = null; message = null; notifyListeners();
    try { await action(); return true; }
    catch (e) { error = friendlyError(e); return false; }
    finally { busy = false; notifyListeners(); }
  }
}

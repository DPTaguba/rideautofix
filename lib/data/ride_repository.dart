import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'cloudinary_service.dart' show CloudinaryUploadException;

class RideRepository {
  RideRepository({FirebaseAuth? auth, FirebaseFirestore? db})
    : auth = auth ?? FirebaseAuth.instance,
      db = db ?? FirebaseFirestore.instance;

  final FirebaseAuth auth;
  final FirebaseFirestore db;

  CollectionReference<Map<String, dynamic>> get _users =>
      db.collection('users');
  CollectionReference<Map<String, dynamic>> get _services =>
      db.collection('services');
  CollectionReference<Map<String, dynamic>> get _appointments =>
      db.collection('appointments');

  Stream<User?> authChanges() => auth.authStateChanges();

  Future<void> signIn(String email, String password) async {
    await auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> register(
    String name,
    String phone,
    String email,
    String password,
  ) async {
    final credential = await auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    try {
      await _users.doc(credential.user!.uid).set({
        'name': name.trim(),
        'phone': phone.trim(),
        'email': email.trim(),
        'role': 'customer',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Avoid leaving an authenticated account behind without its customer profile.
      await credential.user?.delete();
      rethrow;
    }
  }

  /// Google sign-in through Firebase's provider flow (no extra package needed).
  /// Creates the customer profile on the first Google login.
  Future<void> signInWithGoogle() async {
    final provider = GoogleAuthProvider()
      ..addScope('email')
      ..setCustomParameters({'prompt': 'select_account'});

    final cred = kIsWeb
        ? await auth.signInWithPopup(provider)
        : await auth.signInWithProvider(provider);

    final user = cred.user!;
    final ref = _users.doc(user.uid);
    final snap = await ref.get();
    if (!snap.exists) {
      try {
        await ref.set({
          'name': user.displayName ?? '',
          'phone': '',
          'email': user.email ?? '',
          'role': 'customer',
          if (user.photoURL != null) 'photoUrl': user.photoURL,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {
        await auth.signOut();
        rethrow;
      }
    }
  }

  Future<void> sendPasswordReset(String email) =>
      auth.sendPasswordResetEmail(email: email.trim());

  Future<void> signOut() => auth.signOut();

  Stream<DocumentSnapshot<Map<String, dynamic>>> profile(String uid) =>
      _users.doc(uid).snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> customerVehicles(String uid) =>
      db.collection('vehicles').where('ownerId', isEqualTo: uid).snapshots();
  Stream<QuerySnapshot<Map<String, dynamic>>> allVehicles() =>
      db.collection('vehicles').snapshots();
  Stream<QuerySnapshot<Map<String, dynamic>>> allCustomers() =>
      _users.where('role', isEqualTo: 'customer').snapshots();
  Stream<QuerySnapshot<Map<String, dynamic>>> customerAppointments(
    String uid,
  ) => _appointments.where('customerId', isEqualTo: uid).snapshots();
  Stream<QuerySnapshot<Map<String, dynamic>>> allAppointments() =>
      _appointments.orderBy('createdAt', descending: true).snapshots();
  Stream<DocumentSnapshot<Map<String, dynamic>>> appointment(String id) =>
      _appointments.doc(id).snapshots();
  Stream<QuerySnapshot<Map<String, dynamic>>> activeServices() =>
      _services.where('active', isEqualTo: true).snapshots();
  Stream<QuerySnapshot<Map<String, dynamic>>> allServices() =>
      _services.snapshots();

  Future<void> saveVehicle(
    String uid,
    Map<String, dynamic> vehicle, {
    String? id,
  }) async {
    final ref = id == null
        ? db.collection('vehicles').doc()
        : db.collection('vehicles').doc(id);
    await ref.set({
      ...vehicle,
      'ownerId': uid,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> deleteVehicle(String id) =>
      db.collection('vehicles').doc(id).delete();

  /// Only the fields you pass are changed (so a photo-only update is fine).
  Future<void> updateCustomerProfile(
    String uid, {
    String? name,
    String? phone,
    String? address,
    String? photoUrl,
  }) => _users.doc(uid).update({
    if (name != null) 'name': name.trim(),
    if (phone != null) 'phone': phone.trim(),
    if (address != null) 'address': address.trim(),
    if (photoUrl != null) 'photoUrl': photoUrl,
  });

  Future<void> saveService(Map<String, dynamic> service, {String? id}) async {
    final ref = id == null ? _services.doc() : _services.doc(id);
    await ref.set({
      ...service,
      // New services start active; editing must NOT silently re-activate an
      // archived one.
      if (id == null) 'active': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> removeService(String id) =>
      _services.doc(id).update({'active': false});
  Future<void> setServiceActive(String id, bool active) => _services
      .doc(id)
      .update({'active': active, 'updatedAt': FieldValue.serverTimestamp()});

  Future<void> createAppointment(Map<String, dynamic> appointment) async {
    final ref = _appointments.doc();
    await ref.set({
      ...appointment,
      'status': 'Pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateAppointment(String id, Map<String, dynamic> values) =>
      _appointments.doc(id).update({
        ...values,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  Future<void> markPaid(String id) => _appointments.doc(id).update({
    'paymentStatus': 'Paid',
    'updatedAt': FieldValue.serverTimestamp(),
  });

  Future<Map<String, int>> dashboardCounts() async {
    final results = await Future.wait([
      _users.where('role', isEqualTo: 'customer').count().get(),
      db.collection('vehicles').count().get(),
      _services.where('active', isEqualTo: true).count().get(),
      _appointments.count().get(),
    ]);
    return {
      'customers': results[0].count ?? 0,
      'vehicles': results[1].count ?? 0,
      'services': results[2].count ?? 0,
      'appointments': results[3].count ?? 0,
    };
  }
}

/// True when the user simply closed/cancelled the Google sign-in window.
bool isCancelled(Object e) =>
    e is FirebaseAuthException &&
    const {
      'canceled',
      'cancelled',
      'web-context-canceled',
      'popup-closed-by-user',
      'cancelled-popup-request',
    }.contains(e.code);

String friendlyError(Object error) {
  if (error is CloudinaryUploadException) return error.message;
  if (error is FirebaseAuthException) {
    return switch (error.code) {
      'invalid-credential' ||
      'wrong-password' ||
      'user-not-found' => 'Email or password is incorrect.',
      'invalid-email' =>
        'Enter a valid email address, such as name@example.com.',
      'email-already-in-use' => 'An account already uses this email.',
      'weak-password' => 'Choose a stronger password (at least 8 characters).',
      'operation-not-allowed' =>
        'Email and password sign-up is disabled in Firebase Authentication.',
      'account-exists-with-different-credential' =>
        'This email is already registered with a password. Log in with your password instead.',
      'user-disabled' =>
        'This account has been disabled. Contact the administrator.',
      'network-request-failed' =>
        'Network unavailable. Check your connection and try again.',
      'too-many-requests' => 'Too many attempts. Please try again later.',
      _ => error.message ?? 'Authentication failed. Please try again.',
    };
  }
  if (error is FirebaseException) {
    return switch (error.code) {
      'permission-denied' =>
        'Firebase denied the request. Check that Firestore rules are deployed and allow this action.',
      'unavailable' =>
        'Firebase is temporarily unavailable. Check your connection and try again.',
      'unauthenticated' => 'Your session expired. Sign in and try again.',
      _ => error.message ?? 'Something went wrong. Please try again.',
    };
  }
  return 'Could not complete the request. Check your connection and try again.';
}
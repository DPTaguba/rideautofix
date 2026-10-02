import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

import '../data/cloudinary_service.dart';
import '../data/ride_repository.dart';

/// Feature-facing API for the customer and admin views. Keeps Firestore access
/// behind the repository and exposes screen-ready data/actions to the UI.
class RideViewModel {
  RideViewModel(this.repository, {CloudinaryService? cloudinary})
    : cloudinary = cloudinary ?? CloudinaryService();
  final RideRepository repository;
  final CloudinaryService cloudinary;

  Stream<QuerySnapshot<Map<String, dynamic>>> services() =>
      repository.activeServices();
  Stream<QuerySnapshot<Map<String, dynamic>>> allServices() =>
      repository.allServices();
  Stream<QuerySnapshot<Map<String, dynamic>>> vehiclesFor(String uid) =>
      repository.customerVehicles(uid);
  Stream<QuerySnapshot<Map<String, dynamic>>> vehicles() =>
      repository.allVehicles();
  Stream<QuerySnapshot<Map<String, dynamic>>> appointmentsFor(String uid) =>
      repository.customerAppointments(uid);
  Stream<QuerySnapshot<Map<String, dynamic>>> appointments() =>
      repository.allAppointments();
  Stream<DocumentSnapshot<Map<String, dynamic>>> appointment(String id) =>
      repository.appointment(id);
  Stream<QuerySnapshot<Map<String, dynamic>>> customers() =>
      repository.allCustomers();

  Future<Map<String, int>> dashboardCounts() => repository.dashboardCounts();

  Future<void> addVehicle(String uid, Map<String, dynamic> values) =>
      repository.saveVehicle(uid, values);
  Future<void> saveVehicle(
    String uid,
    Map<String, dynamic> values, {
    String? id,
  }) => repository.saveVehicle(uid, values, id: id);
  Future<void> deleteVehicle(String id) => repository.deleteVehicle(id);

  /// Cloudinary uploads. Each returns the hosted https URL to store in Firestore.
  Future<String> uploadVehiclePhoto(XFile photo) =>
      cloudinary.uploadVehiclePhoto(photo);
  Future<String> uploadPhoto(XFile photo, {required String folder}) =>
      cloudinary.uploadPhoto(photo, folder: folder);

  Future<void> updateProfile(
    String uid, {
    String? name,
    String? phone,
    String? address,
    String? photoUrl,
  }) => repository.updateCustomerProfile(
    uid,
    name: name,
    phone: phone,
    address: address,
    photoUrl: photoUrl,
  );

  Future<void> saveService(Map<String, dynamic> values, {String? id}) =>
      repository.saveService(values, id: id);
  Future<void> archiveService(String id) => repository.removeService(id);
  Future<void> setServiceActive(String id, bool active) =>
      repository.setServiceActive(id, active);
  Future<void> book(Map<String, dynamic> values) =>
      repository.createAppointment(values);
  Future<void> setAppointmentStatus(String id, String status) =>
      repository.updateAppointment(id, {'status': status});
  Future<void> cancelAppointment(String id) =>
      repository.updateAppointment(id, {'status': 'Cancelled'});
  Future<void> recordPayment(String id) => repository.markPaid(id);
}
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

/// Uploads photos to Cloudinary with an UNSIGNED upload preset, so no API
/// secret ever ships inside the app.
///
/// Cloudinary console: Settings -> Upload -> Upload presets -> the preset named
/// [_preset] must have "Signing mode" = *Unsigned*.
class CloudinaryService {
  static const _cloudName = 'udrczyzi'; // double-check on your dashboard
  static const _preset = 'rideautofix';
  static const _maxBytes = 10 * 1024 * 1024; // Cloudinary free-plan image limit

  /// Uploads [photo] into [folder] and returns its https URL.
  Future<String> uploadPhoto(
    XFile photo, {
    String folder = 'rideautofix/vehicles',
  }) async {
    final bytes = await photo.readAsBytes();
    if (bytes.length > _maxBytes) {
      throw const CloudinaryUploadException(
        'This photo is larger than 10 MB. Please choose a smaller one.',
      );
    }

    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$_cloudName/image/upload',
    );
    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = _preset
      ..fields['folder'] = folder
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: photo.name.isEmpty ? 'photo.jpg' : photo.name,
        ),
      );

    try {
      final streamed = await request.send().timeout(
        const Duration(seconds: 60),
      );
      final body = await streamed.stream.bytesToString();

      Map<String, dynamic> json = {};
      try {
        json = jsonDecode(body) as Map<String, dynamic>;
      } catch (_) {}

      if (streamed.statusCode != 200) {
        final err = json['error'];
        final msg = (err is Map ? err['message'] : null) ??
            'Upload failed (HTTP ${streamed.statusCode}).';
        debugPrint('Cloudinary error ${streamed.statusCode}: $body');
        throw CloudinaryUploadException('$msg');
      }

      final url = json['secure_url'] as String?;
      if (url == null || url.isEmpty) {
        throw const CloudinaryUploadException(
          'Cloudinary returned no photo URL.',
        );
      }
      return url;
    } on CloudinaryUploadException {
      rethrow;
    } on TimeoutException {
      throw const CloudinaryUploadException(
        'The upload timed out. Try again or pick a smaller photo.',
      );
    } on http.ClientException catch (e) {
      debugPrint('Cloudinary network error: $e');
      throw CloudinaryUploadException('Network error: ${e.message}');
    } catch (e) {
      debugPrint('Cloudinary unexpected error: $e');
      throw CloudinaryUploadException('Could not upload this photo: $e');
    }
  }

  Future<String> uploadVehiclePhoto(XFile photo) =>
      uploadPhoto(photo, folder: 'rideautofix/vehicles');
}

class CloudinaryUploadException implements Exception {
  const CloudinaryUploadException(this.message);
  final String message;
  @override
  String toString() => message;
}
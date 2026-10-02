import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'data/ride_repository.dart';
import 'firebase_options.dart';
import 'views/ride_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Object? startupError;
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (error) {
    startupError = error;
  }
  runApp(RideAutoFixApp(repository: startupError == null ? RideRepository() : null,
      startupError: startupError));
}

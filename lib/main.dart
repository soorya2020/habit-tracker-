import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'data/auth.dart';
import 'data/firestore_repository.dart';
import 'data/local_repository.dart';
import 'data/repository.dart';
import 'firebase_config.dart';
import 'services/notifications.dart';
import 'state/account.dart';
import 'state/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  // With Firebase configured, the club lives in Firestore. Without it,
  // everything stays on this phone.
  var cloud = false;
  if (firebaseOptions != null) {
    try {
      await Firebase.initializeApp(options: firebaseOptions);
      cloud = true;
    } catch (e) {
      debugPrint('Firebase failed to start, running on this phone only: $e');
    }
  }
  final Repository repo = cloud ? FirestoreRepository() : await LocalRepository.open(prefs);

  try {
    await NotificationService.instance.init();
  } catch (e) {
    debugPrint('Notifications unavailable: $e');
  }
  runApp(ProviderScope(
    overrides: [
      cloudModeProvider.overrideWithValue(cloud),
      prefsProvider.overrideWithValue(prefs),
      repositoryProvider.overrideWithValue(repo),
      authServiceProvider.overrideWithValue(LocalAuth(prefs)),
    ],
    child: const OnePercentApp(),
  ));
}

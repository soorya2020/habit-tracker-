import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'data/auth.dart';
import 'data/local_repository.dart';
import 'services/notifications.dart';
import 'state/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final repo = await LocalRepository.open(prefs);
  try {
    await NotificationService.instance.init();
  } catch (e) {
    debugPrint('Notifications unavailable: $e');
  }
  runApp(ProviderScope(
    overrides: [
      repositoryProvider.overrideWithValue(repo),
      authServiceProvider.overrideWithValue(LocalAuth(prefs)),
    ],
    child: const OnePercentApp(),
  ));
}

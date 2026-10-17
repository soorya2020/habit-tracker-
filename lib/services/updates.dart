import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Newer builds published on GitHub. Each push to main publishes a release
/// tagged build-N, and N is the app's build number.
class Updates {
  static const repo = 'soorya2020/habit-tracker-';
  static final apk = Uri.parse('https://github.com/$repo/releases/latest/download/one-percent-club.apk');

  /// Build number in a release tag such as "build-12".
  static int? buildOf(String tag) => int.tryParse(tag.replaceFirst('build-', ''));

  static Future<int> installed() async => int.tryParse((await PackageInfo.fromPlatform()).buildNumber) ?? 0;

  /// The latest release, or null when it can't be reached.
  static Future<Release?> latest() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final req = await client.getUrl(Uri.parse('https://api.github.com/repos/$repo/releases/latest'));
      req.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      final res = await req.close();
      if (res.statusCode != 200) return null;
      final json = jsonDecode(await res.transform(utf8.decoder).join()) as Map<String, dynamic>;
      final build = buildOf(json['tag_name'] as String? ?? '');
      if (build == null) return null;
      final notes = (json['body'] as String? ?? '').split('\n').first.trim();
      return Release(build, notes);
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }

  /// Opens the newest APK in the browser, which downloads it. Tapping the
  /// download installs it over the current app.
  static Future<void> download() => launchUrl(apk, mode: LaunchMode.externalApplication);
}

class Release {
  const Release(this.build, this.notes);
  final int build;

  /// First line of the commit message, which says what changed.
  final String notes;
}

class UpdateStatus {
  const UpdateStatus(this.installed, this.latest);
  final int installed;
  final Release? latest;
  bool get available => latest != null && installed > 0 && latest!.build > installed;
}

/// Checked when the app opens, and again from Settings.
final updateProvider = FutureProvider<UpdateStatus>((ref) async {
  if (kIsWeb || !Platform.isAndroid) return const UpdateStatus(0, null);
  final r = await Future.wait([Updates.installed(), Updates.latest()]);
  return UpdateStatus(r[0] as int, r[1] as Release?);
});

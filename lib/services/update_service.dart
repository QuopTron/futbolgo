import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppVersion {
  final String version;
  final String? downloadUrl;
  final String? releaseNotes;
  final DateTime publishedAt;

  AppVersion({
    required this.version,
    this.downloadUrl,
    this.releaseNotes,
    required this.publishedAt,
  });

  factory AppVersion.fromJson(Map<String, dynamic> json) {
    return AppVersion(
      version: json['tag_name'] as String? ?? '',
      downloadUrl: _extractDownloadUrl(json),
      releaseNotes: json['body'] as String?,
      publishedAt: DateTime.parse(json['published_at'] as String),
    );
  }

  static String? _extractDownloadUrl(Map<String, dynamic> json) {
    final assets = json['assets'] as List<dynamic>?;
    if (assets != null && assets.isNotEmpty) {
      return assets.first['browser_download_url'] as String?;
    }
    return json['html_url'] as String?;
  }

  bool get isValid => version.isNotEmpty;
}

class UpdateService {
  static const String _repoOwner = 'flox-app';
  static const String _repoName = 'futbolgo';
  static const String _currentVersion = '1.0.0';
  static const String _updateCheckKey = 'last_update_check';
  static const String _updateDismissedKey = 'update_dismissed_version';

  Future<AppVersion?> checkForUpdates({bool force = false}) async {
    try {
      if (!force && !await _shouldCheckForUpdate()) {
        return null;
      }

      final prefs = await SharedPreferences.getInstance();
      prefs.setString(_updateCheckKey, DateTime.now().toIso8601String());

      final url = Uri.parse(
          'https://api.github.com/repos/$_repoOwner/$_repoName/releases/latest');
      
        final response = await http.get(
        url,
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'FutbolGO-App',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final latestVersion = AppVersion.fromJson(data);
        
        if (latestVersion.isValid && await _isNewerVersion(latestVersion.version)) {
          return latestVersion;
        }
      }
    } catch (e) {
      print('Error checking for updates: $e');
    }
    return null;
  }

  Future<bool> _shouldCheckForUpdate() async {
    final prefs = await SharedPreferences.getInstance();
    final lastCheck = prefs.getString(_updateCheckKey);
    
    if (lastCheck == null) return true;
    
    final lastCheckTime = DateTime.parse(lastCheck);
    final now = DateTime.now();
    final hoursSinceLastCheck = now.difference(lastCheckTime).inHours;
    
    return hoursSinceLastCheck >= 24;
  }

  Future<bool> _isNewerVersion(String latestVersion) async {
    final prefs = await SharedPreferences.getInstance();
    final dismissedVersion = prefs.getString(_updateDismissedKey);
    
    if (dismissedVersion == latestVersion) {
      return false;
    }

    final current = _parseVersion(_currentVersion);
    final latest = _parseVersion(latestVersion);
    
    if (latest.length < 3) return false;
    if (current.length < 3) return true;

    for (int i = 0; i < 3; i++) {
      if (latest[i] > current[i]) return true;
      if (latest[i] < current[i]) return false;
    }
    
    return false;
  }

  List<int> _parseVersion(String version) {
    final cleanVersion = version.replaceAll(RegExp(r'[vV]'), '');
    final parts = cleanVersion.split('.');
    return parts.take(3).map((p) => int.tryParse(p) ?? 0).toList();
  }

  Future<void> dismissUpdate(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_updateDismissedKey, version);
  }

  Future<void> openUpdatePage(String? url) async {
    if (url == null) return;
    
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String get currentVersion => _currentVersion;
}

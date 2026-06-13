import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class BackendService {
  static final BackendService _instance = BackendService._();
  factory BackendService() => _instance;
  BackendService._();

  static const MethodChannel _channel = MethodChannel('futbolgo');
  static const String _httpBaseUrl = 'http://localhost:8080';

  bool get _isAndroid => Platform.isAndroid;

  /// Check if the backend is reachable
  Future<bool> isAvailable() async {
    if (_isAndroid) {
      try {
        await _channel.invokeMethod<String>('scrapeEvents');
        return true;
      } catch (_) {
        return false;
      }
    } else {
      try {
        final resp = await http
            .get(Uri.parse('$_httpBaseUrl/health'))
            .timeout(const Duration(seconds: 3));
        return resp.statusCode == 200;
      } catch (_) {
        return false;
      }
    }
  }

  /// Scrape all channels and events
  Future<Map<String, dynamic>> scrapeAll() async {
    final jsonStr = _isAndroid ? await _scrapeAllNative() : await _scrapeAllHttp();

    if (jsonStr == null || jsonStr.isEmpty) {
      throw Exception('No se pudieron obtener datos del backend');
    }

    final decoded = jsonDecode(jsonStr);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    // Handle server wrapping: { success: true, data: { events: [...], channels: [...] } }
    if (decoded is Map<String, dynamic> && decoded.containsKey('data')) {
      return decoded['data'] as Map<String, dynamic>;
    }

    throw Exception('Formato de datos inesperado');
  }

  Future<String?> _scrapeAllNative() async {
    return await _channel.invokeMethod<String>('scrapeAll');
  }

  Future<String?> _scrapeAllHttp() async {
    final resp = await http
        .get(Uri.parse('$_httpBaseUrl/api/scrape/all'))
        .timeout(const Duration(seconds: 30));

    if (resp.statusCode != 200) {
      throw Exception('Error HTTP ${resp.statusCode}');
    }

    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    if (body['success'] == true && body['data'] != null) {
      return jsonEncode(body['data']);
    }

    return resp.body;
  }

  /// Resolve a stream URL (e.g. global1.php) to a direct .m3u8 URL
  /// This avoids WebView and ads by extracting the real stream server-side
  Future<Map<String, dynamic>> resolveStream(String url) async {
    if (_isAndroid) {
      // On Android, call via method channel
      try {
        final result = await _channel.invokeMethod<String>(
          'resolveStream',
          {'url': url},
        );
        if (result != null) {
          return jsonDecode(result) as Map<String, dynamic>;
        }
      } catch (_) {}
      return {'resolved': false, 'error': 'No response'};
    } else {
      try {
        final resp = await http
            .get(Uri.parse('$_httpBaseUrl/api/resolve-stream?url=${Uri.encodeComponent(url)}'))
            .timeout(const Duration(seconds: 15));
        if (resp.statusCode == 200) {
          final body = jsonDecode(resp.body) as Map<String, dynamic>;
          // Unwrap server response
          if (body['data'] != null) {
            return body['data'] as Map<String, dynamic>;
          }
          return body;
        }
      } catch (_) {}
      return {'resolved': false, 'error': 'Backend unreachable'};
    }
  }

  /// Check if a specific stream URL is active
  Future<Map<String, dynamic>> checkStreamActive(String url) async {
    if (_isAndroid) {
      final result = await _channel.invokeMethod<String>(
        'checkStreamActive',
        {'url': url},
      );
      if (result != null) {
        return jsonDecode(result) as Map<String, dynamic>;
      }
      return {'is_active': false, 'error': 'No response'};
    } else {
      final resp = await http
          .get(Uri.parse('$_httpBaseUrl/api/check-stream?url=${Uri.encodeComponent(url)}'))
          .timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        return body;
      }
      return {'is_active': false, 'error': 'HTTP ${resp.statusCode}'};
    }
  }

  /// Get stream info (ad blocking analysis)
  Future<Map<String, dynamic>> getStreamInfo(String url) async {
    if (_isAndroid) {
      // On Android, we use the basic check
      return await checkStreamActive(url);
    } else {
      final resp = await http
          .get(Uri.parse('$_httpBaseUrl/api/stream-info?url=${Uri.encodeComponent(url)}'))
          .timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        return body['data'] as Map<String, dynamic>? ?? body;
      }
      return {'safe': true, 'has_ads': false};
    }
  }
}

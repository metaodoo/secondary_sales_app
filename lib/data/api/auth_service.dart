import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:secondary_sales/core/constants.dart';
import 'package:secondary_sales/data/models/auth/mobile_auth_session.dart';

class AuthService {
  AuthService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  String? _sessionId;

  void updateSessionId(String? sessionId) {
    _sessionId = sessionId;
  }

  Uri _buildUri(String path) {
    final separator = path.contains('?') ? '&' : '?';
    return Uri.parse(
      '${AppConstants.baseUrl}$path${separator}db=${AppConstants.dbName}',
    );
  }

  Map<String, String> _headers({String? accessToken}) {
    return {
      HttpHeaders.contentTypeHeader: 'application/json',
      HttpHeaders.acceptHeader: 'application/json',
      'X-Odoo-Database': AppConstants.dbName,
      'X-Odoo-Db': AppConstants.dbName,
      'X-Openerp-Database': AppConstants.dbName,
      if (_sessionId != null && _sessionId!.isNotEmpty)
        HttpHeaders.cookieHeader: 'session_id=$_sessionId',
      if (accessToken != null && accessToken.isNotEmpty)
        HttpHeaders.authorizationHeader: 'Bearer $accessToken',
    };
  }

  Future<List<String>> fetchDatabaseList(String baseUrl) async {
    final normalizedBaseUrl = AppConstants.normalizeBaseUrl(baseUrl);
    final url = Uri.parse('$normalizedBaseUrl/web/database/list');
    final response = await _client
        .post(
          url,
          headers: const {
            HttpHeaders.contentTypeHeader: 'application/json',
            HttpHeaders.acceptHeader: 'application/json',
          },
          body: jsonEncode({
            'jsonrpc': '2.0',
            'method': 'call',
            'params': <String, dynamic>{},
            'id': DateTime.now().millisecondsSinceEpoch,
          }),
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      throw Exception('Invalid database list response.');
    }

    Object? databases;
    if (decoded is Map<String, dynamic>) {
      if (decoded['error'] != null) {
        final error = decoded['error'];
        throw Exception(
          error is Map
              ? (error['message'] ?? error['data']?['message'] ?? error)
                    .toString()
              : error.toString(),
        );
      }
      databases = decoded['result'];
    } else {
      databases = decoded;
    }

    if (databases is! List) {
      throw Exception('Database list response did not include a list.');
    }

    return databases.map((db) => db.toString()).toList()..sort();
  }

  Future<String> bootstrapOdooSession({
    required String baseUrl,
    required String dbName,
  }) async {
    final normalizedBaseUrl = AppConstants.normalizeBaseUrl(baseUrl);
    final encodedDb = Uri.encodeQueryComponent(dbName);
    final url = Uri.parse(
      '$normalizedBaseUrl${AppConstants.authBootstrapSessionEndpoint}?db=$encodedDb',
    );
    final response = await _client
        .post(
          url,
          headers: const {
            HttpHeaders.contentTypeHeader: 'application/json',
            HttpHeaders.acceptHeader: 'application/json',
          },
          body: jsonEncode({'db': dbName}),
        )
        .timeout(const Duration(seconds: 20));

    final sessionId = _extractSessionId(response);
    if (sessionId != null && sessionId.isNotEmpty) {
      _sessionId = sessionId;
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        decoded is Map
            ? (decoded['message'] ?? decoded['error'] ?? response.body)
                  .toString()
            : response.body,
      );
    }
    if (sessionId == null || sessionId.isEmpty) {
      throw Exception('Odoo did not return a session cookie.');
    }
    return sessionId;
  }

  String? _extractSessionId(http.Response response) {
    final setCookie = response.headers['set-cookie'];
    if (setCookie == null || setCookie.isEmpty) return null;
    final match = RegExp(
      r'(?:^|,\s*)session_id=([^;,\s]+)',
    ).firstMatch(setCookie);
    return match?.group(1);
  }

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, dynamic> body, {
    String? accessToken,
  }) async {
    final url = _buildUri(path);

    if (kDebugMode) {
      debugPrint('Mobile auth POST $url');
      debugPrint('Mobile auth params: ${jsonEncode(body)}');
    }

    final response = await _client
        .post(
          url,
          headers: _headers(accessToken: accessToken),
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 20));

    if (kDebugMode) {
      debugPrint(
        'Mobile auth response ${response.statusCode}: ${response.body}',
      );
      debugPrint('Mobile auth set-cookie: ${response.headers['set-cookie']}');
    }

    final sessionId = _extractSessionId(response);
    if (sessionId != null && sessionId.isNotEmpty) {
      _sessionId = sessionId;
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid mobile auth response.');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        decoded['message'] ??
            decoded['error'] ??
            'Mobile authentication failed.',
      );
    }

    return decoded;
  }

  Future<MobileAuthSession> login({
    required String login,
    required String password,
  }) async {
    final result = await _postJson(AppConstants.authLoginEndpoint, {
      'db': AppConstants.dbName,
      'login': login,
      'password': password,
      'device_info': 'secondary_sales_flutter',
    });
    if (_sessionId != null && _sessionId!.isNotEmpty) {
      result['session_id'] = _sessionId;
    }
    return MobileAuthSession.fromMap(result);
  }

  Future<MobileAuthTokens> refresh(String refreshToken) async {
    final result = await _postJson(AppConstants.authRefreshEndpoint, {
      'refresh_token': refreshToken,
    });
    return MobileAuthTokens.fromMap(result);
  }

  Future<void> logout(String accessToken) async {
    await _postJson(
      AppConstants.authLogoutEndpoint,
      const <String, dynamic>{},
      accessToken: accessToken,
    );
  }
}

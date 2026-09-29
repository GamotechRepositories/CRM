import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/company_config.dart';
import 'api_cache.dart';

/// Shared HTTP client — base URL switches with the selected company.
class ApiClient {
  ApiClient({required this.company});

  CompanyConfig company;

  String get baseUrl => company.apiBaseUrl.replaceAll(RegExp(r'/+$'), '');

  Uri _uri(String path, [Map<String, String>? query]) {
    final cleaned = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$baseUrl$cleaned').replace(queryParameters: query);
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    final res = await http.post(
      _uri(path),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        ...?headers,
      },
      body: jsonEncode(body ?? {}),
    );
    return _decodeMutation(res);
  }

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String>? query,
    Map<String, String>? headers,
    bool useCache = true,
  }) {
    final uri = _uri(path, query);
    Future<Map<String, dynamic>> fetch() async {
      final res = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          ...?headers,
        },
      );
      return _decode(res);
    }

    if (!useCache || !ApiCache.isCacheable(path)) return fetch();
    return ApiCache.getOrFetch(uri.toString(), fetch);
  }

  Future<Map<String, dynamic>> patchJson(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    final res = await http.patch(
      _uri(path),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        ...?headers,
      },
      body: jsonEncode(body ?? {}),
    );
    return _decodeMutation(res);
  }

  Future<Map<String, dynamic>> putJson(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    final res = await http.put(
      _uri(path),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        ...?headers,
      },
      body: jsonEncode(body ?? {}),
    );
    return _decodeMutation(res);
  }

  Future<Map<String, dynamic>> deleteJson(
    String path, {
    Map<String, String>? headers,
  }) async {
    final res = await http.delete(
      _uri(path),
      headers: {
        'Accept': 'application/json',
        ...?headers,
      },
    );
    return _decodeMutation(res);
  }

  Map<String, dynamic> _decodeMutation(http.Response res) {
    ApiCache.clear();
    return _decode(res);
  }

  Map<String, dynamic> _decode(http.Response res) {

    Map<String, dynamic> data = {};
    if (res.body.isNotEmpty) {
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) {
        data = decoded;
      } else if (decoded is List) {
        data = {'data': decoded};
      }
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final message = data['message']?.toString() ??
          'Request failed (${res.statusCode})';
      throw ApiException(res.statusCode, message, data);
    }
    return data;
  }
}

class ApiException implements Exception {
  ApiException(this.statusCode, this.message, [this.data]);

  final int statusCode;
  final String message;
  final Map<String, dynamic>? data;

  @override
  String toString() => message;
}

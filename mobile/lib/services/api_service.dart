import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/customer.dart';
import '../models/customer_account.dart';
import '../models/invoice.dart';
import '../models/product.dart';

/// A dead or unreachable server must end in an error the app can recover from,
/// never in a request that waits forever.
class _TimeoutClient extends http.BaseClient {
  final Duration timeout;
  final http.Client _inner = http.Client();

  _TimeoutClient(this.timeout);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _inner.send(request).timeout(timeout);

  @override
  void close() => _inner.close();
}

class ApiService {
  final http.Client _http = _TimeoutClient(const Duration(seconds: 45));
  http.Client? _chatClient;
  String? _token;

  void setToken(String? token) => _token = token;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Future<Map<String, dynamic>> _get(String path) async {
    final response = await _http.get(
      Uri.parse('${ApiConfig.baseUrl}$path'),
      headers: _headers,
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    final response = await _http.post(
      Uri.parse('${ApiConfig.baseUrl}$path'),
      headers: _headers,
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> _put(String path, Map<String, dynamic> body) async {
    final response = await _http.put(
      Uri.parse('${ApiConfig.baseUrl}$path'),
      headers: _headers,
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  Future<void> _delete(String path) async {
    final response = await _http.delete(
      Uri.parse('${ApiConfig.baseUrl}$path'),
      headers: _headers,
    );
    if (response.statusCode >= 400) {
      final body = response.body.isNotEmpty ? jsonDecode(response.body) : {};
      throw Exception(body['message'] ?? 'فشل الحذف');
    }
  }

  dynamic _decode(http.Response response) {
    final decoded = response.body.isNotEmpty ? jsonDecode(response.body) : {};
    if (response.statusCode >= 400) {
      final msg = decoded is Map
          ? (decoded['message'] is List
              ? (decoded['message'] as List).join(', ')
              : decoded['message']?.toString())
          : null;
      throw Exception(msg ?? 'حدث خطأ');
    }
    return decoded;
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await _http.post(
      Uri.parse('${ApiConfig.baseUrl}/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    return _decode(response) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> chat(String message, {String? model}) async {
    // Its own client so that closing it (cancelChat) drops just this request,
    // which also stops the model on the server.
    final client = _TimeoutClient(const Duration(seconds: 90));
    _chatClient = client;
    try {
      final response = await client.post(
        Uri.parse('${ApiConfig.baseUrl}/ai/chat'),
        headers: _headers,
        body: jsonEncode({
          'message': message,
          'speak': true,
          if (model != null && model.isNotEmpty) 'model': model,
        }),
      );
      return _decode(response) as Map<String, dynamic>;
    } finally {
      client.close();
      if (identical(_chatClient, client)) _chatClient = null;
    }
  }

  void cancelChat() {
    _chatClient?.close();
    _chatClient = null;
  }

  Future<Map<String, dynamic>> getAiModels() async {
    return await _get('/ai/models') as Map<String, dynamic>;
  }

  Future<List<dynamic>> getChatHistory() async {
    final response = await _http.get(
      Uri.parse('${ApiConfig.baseUrl}/ai/history'),
      headers: _headers,
    );
    if (response.statusCode >= 400) return [];
    return jsonDecode(response.body) as List<dynamic>;
  }

  Future<void> clearChatHistory() async {
    await _delete('/ai/history');
  }

  Future<Map<String, dynamic>> speechToText(File audioFile) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConfig.baseUrl}/voice/speech-to-text'),
    );
    if (_token != null) {
      request.headers['Authorization'] = 'Bearer $_token';
    }
    request.files.add(
      await http.MultipartFile.fromPath('audio', audioFile.path),
    );
    final streamed = await _http.send(request);
    final response = await http.Response.fromStream(streamed);
    return _decode(response) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> enrollVoiceprint(File audioFile) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConfig.baseUrl}/voice/voiceprint'),
    );
    if (_token != null) {
      request.headers['Authorization'] = 'Bearer $_token';
    }
    request.files.add(
      await http.MultipartFile.fromPath('audio', audioFile.path),
    );
    final streamed = await _http.send(request);
    final response = await http.Response.fromStream(streamed);
    return _decode(response) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getVoiceprintStatus() async {
    return await _get('/voice/voiceprint') as Map<String, dynamic>;
  }

  Future<void> deleteVoiceprint() => _delete('/voice/voiceprint');

  Future<List<int>> textToSpeech(String text) async {
    final response = await _http.post(
      Uri.parse('${ApiConfig.baseUrl}/voice/text-to-speech'),
      headers: _headers,
      body: jsonEncode({'text': text}),
    );
    if (response.statusCode >= 400) {
      throw Exception('فشل تحويل النص إلى صوت');
    }
    return response.bodyBytes;
  }

  Future<Map<String, dynamic>> getSummary() async {
    return await _get('/invoices/summary') as Map<String, dynamic>;
  }

  Future<List<Customer>> getCustomers({String? search}) async {
    final q = search != null && search.isNotEmpty
        ? '?search=${Uri.encodeComponent(search)}'
        : '';
    final response = await _http.get(
      Uri.parse('${ApiConfig.baseUrl}/customers$q'),
      headers: _headers,
    );
    final list = _decode(response) as List<dynamic>;
    return list.map((e) => Customer.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Customer> createCustomer(Map<String, dynamic> data) async {
    final json = await _post('/customers', data) as Map<String, dynamic>;
    return Customer.fromJson(json);
  }

  Future<Customer> updateCustomer(String id, Map<String, dynamic> data) async {
    final json = await _put('/customers/$id', data) as Map<String, dynamic>;
    return Customer.fromJson(json);
  }

  Future<void> deleteCustomer(String id) => _delete('/customers/$id');

  Future<CustomerAccount> getCustomerAccount(String id) async {
    final json = await _get('/customers/$id/account') as Map<String, dynamic>;
    return CustomerAccount.fromJson(json);
  }

  Future<List<Product>> getProducts({String? search}) async {
    final q = search != null && search.isNotEmpty
        ? '?search=${Uri.encodeComponent(search)}'
        : '';
    final response = await _http.get(
      Uri.parse('${ApiConfig.baseUrl}/products$q'),
      headers: _headers,
    );
    final list = _decode(response) as List<dynamic>;
    return list.map((e) => Product.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Product> createProduct(Map<String, dynamic> data) async {
    final json = await _post('/products', data) as Map<String, dynamic>;
    return Product.fromJson(json);
  }

  Future<Product> updateProduct(String id, Map<String, dynamic> data) async {
    final json = await _put('/products/$id', data) as Map<String, dynamic>;
    return Product.fromJson(json);
  }

  Future<void> deleteProduct(String id) => _delete('/products/$id');

  Future<List<Invoice>> getInvoices({
    String? customerName,
    String? status,
  }) async {
    final params = <String>[];
    if (customerName != null && customerName.isNotEmpty) {
      params.add('customerName=${Uri.encodeComponent(customerName)}');
    }
    if (status != null && status.isNotEmpty) {
      params.add('status=$status');
    }
    final q = params.isEmpty ? '' : '?${params.join('&')}';
    final response = await _http.get(
      Uri.parse('${ApiConfig.baseUrl}/invoices$q'),
      headers: _headers,
    );
    final list = _decode(response) as List<dynamic>;
    return list.map((e) => Invoice.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Invoice> getInvoice(String id) async {
    final json = await _get('/invoices/$id') as Map<String, dynamic>;
    return Invoice.fromJson(json);
  }

  Future<Invoice> createInvoice(Map<String, dynamic> data) async {
    final json = await _post('/invoices', data) as Map<String, dynamic>;
    return Invoice.fromJson(json);
  }

  Future<Invoice> updateInvoice(String id, Map<String, dynamic> data) async {
    final json = await _put('/invoices/$id', data) as Map<String, dynamic>;
    return Invoice.fromJson(json);
  }

  Future<Map<String, dynamic>> getInsights() async {
    return await _get('/invoices/insights') as Map<String, dynamic>;
  }

  Future<Invoice> updateInvoiceStatus(String id, String status) async {
    final response = await _http.patch(
      Uri.parse('${ApiConfig.baseUrl}/invoices/$id/status'),
      headers: _headers,
      body: jsonEncode({'status': status}),
    );
    return Invoice.fromJson(_decode(response) as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> getReport({
    String? customerName,
    String? status,
  }) async {
    final params = <String>[];
    if (customerName != null && customerName.isNotEmpty) {
      params.add('customerName=${Uri.encodeComponent(customerName)}');
    }
    if (status != null && status.isNotEmpty) {
      params.add('status=$status');
    }
    final q = params.isEmpty ? '' : '?${params.join('&')}';
    return await _get('/invoices/report$q') as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getAuditLogs({int limit = 50}) async {
    final response = await _http.get(
      Uri.parse('${ApiConfig.baseUrl}/audit?limit=$limit'),
      headers: _headers,
    );
    final list = _decode(response) as List<dynamic>;
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> getUsers() async {
    final response = await _http.get(
      Uri.parse('${ApiConfig.baseUrl}/auth/users'),
      headers: _headers,
    );
    final list = _decode(response) as List<dynamic>;
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> createUser({
    required String name,
    required String email,
    required String password,
    String role = 'USER',
  }) async {
    return await _post('/auth/users', {
      'name': name,
      'email': email,
      'password': password,
      'role': role,
    }) as Map<String, dynamic>;
  }
}

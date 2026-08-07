import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/customer.dart';
import '../models/invoice.dart';
import '../models/product.dart';

class ApiService {
  String? _token;

  void setToken(String? token) => _token = token;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Future<Map<String, dynamic>> _get(String path) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}$path'),
      headers: _headers,
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}$path'),
      headers: _headers,
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> _put(String path, Map<String, dynamic> body) async {
    final response = await http.put(
      Uri.parse('${ApiConfig.baseUrl}$path'),
      headers: _headers,
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  Future<void> _delete(String path) async {
    final response = await http.delete(
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
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    return _decode(response) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> chat(String message, {String? model}) async {
    return await _post('/ai/chat', {
      'message': message,
      'speak': true,
      if (model != null && model.isNotEmpty) 'model': model,
    }) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getAiModels() async {
    return await _get('/ai/models') as Map<String, dynamic>;
  }

  Future<List<dynamic>> getChatHistory() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/ai/history'),
      headers: _headers,
    );
    if (response.statusCode >= 400) return [];
    return jsonDecode(response.body) as List<dynamic>;
  }

  Future<String> speechToText(File audioFile) async {
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
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    final body = _decode(response) as Map<String, dynamic>;
    return body['text'] as String? ?? '';
  }

  Future<List<int>> textToSpeech(String text) async {
    final response = await http.post(
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
    final response = await http.get(
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

  Future<List<Product>> getProducts({String? search}) async {
    final q = search != null && search.isNotEmpty
        ? '?search=${Uri.encodeComponent(search)}'
        : '';
    final response = await http.get(
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
    final response = await http.get(
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

  Future<Invoice> updateInvoiceStatus(String id, String status) async {
    final response = await http.patch(
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
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/audit?limit=$limit'),
      headers: _headers,
    );
    final list = _decode(response) as List<dynamic>;
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> getUsers() async {
    final response = await http.get(
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

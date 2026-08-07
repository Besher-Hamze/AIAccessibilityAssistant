import 'package:flutter/foundation.dart';
import '../models/customer.dart';
import '../models/invoice.dart';
import '../models/product.dart';
import '../services/api_service.dart';

class DataProvider extends ChangeNotifier {
  final ApiService api;

  DataProvider(this.api);

  List<Customer> customers = [];
  List<Product> products = [];
  List<Invoice> invoices = [];
  Map<String, dynamic>? summary;

  bool loadingCustomers = false;
  bool loadingProducts = false;
  bool loadingInvoices = false;
  bool loadingSummary = false;
  String? error;

  Future<void> loadAll() async {
    await Future.wait([
      loadSummary(),
      loadCustomers(),
      loadProducts(),
      loadInvoices(),
    ]);
  }

  Future<void> loadSummary() async {
    loadingSummary = true;
    notifyListeners();
    try {
      summary = await api.getSummary();
      error = null;
    } catch (e) {
      error = e.toString().replaceAll('Exception: ', '');
    }
    loadingSummary = false;
    notifyListeners();
  }

  Future<void> loadCustomers({String? search}) async {
    loadingCustomers = true;
    notifyListeners();
    try {
      customers = await api.getCustomers(search: search);
      error = null;
    } catch (e) {
      error = e.toString().replaceAll('Exception: ', '');
    }
    loadingCustomers = false;
    notifyListeners();
  }

  Future<void> loadProducts({String? search}) async {
    loadingProducts = true;
    notifyListeners();
    try {
      products = await api.getProducts(search: search);
      error = null;
    } catch (e) {
      error = e.toString().replaceAll('Exception: ', '');
    }
    loadingProducts = false;
    notifyListeners();
  }

  Future<void> loadInvoices({String? status}) async {
    loadingInvoices = true;
    notifyListeners();
    try {
      invoices = await api.getInvoices(status: status);
      error = null;
    } catch (e) {
      error = e.toString().replaceAll('Exception: ', '');
    }
    loadingInvoices = false;
    notifyListeners();
  }

  Future<Customer> saveCustomer(Map<String, dynamic> data, {String? id}) async {
    final result = id == null
        ? await api.createCustomer(data)
        : await api.updateCustomer(id, data);
    await loadCustomers();
    await loadSummary();
    return result;
  }

  Future<void> removeCustomer(String id) async {
    await api.deleteCustomer(id);
    await loadCustomers();
    await loadSummary();
  }

  Future<Product> saveProduct(Map<String, dynamic> data, {String? id}) async {
    final result = id == null
        ? await api.createProduct(data)
        : await api.updateProduct(id, data);
    await loadProducts();
    await loadSummary();
    return result;
  }

  Future<void> removeProduct(String id) async {
    await api.deleteProduct(id);
    await loadProducts();
    await loadSummary();
  }

  Future<Invoice> createInvoice(Map<String, dynamic> data) async {
    final invoice = await api.createInvoice(data);
    await loadInvoices();
    await loadProducts();
    await loadSummary();
    return invoice;
  }

  Future<void> setInvoiceStatus(String id, String status) async {
    await api.updateInvoiceStatus(id, status);
    await loadInvoices();
    await loadProducts();
    await loadSummary();
  }
}

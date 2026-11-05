import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:ai_accessibility_assistant/models/customer.dart';
import 'package:ai_accessibility_assistant/models/customer_account.dart';
import 'package:ai_accessibility_assistant/models/invoice.dart';
import 'package:ai_accessibility_assistant/models/product.dart';
import 'package:ai_accessibility_assistant/models/user.dart';
import 'package:ai_accessibility_assistant/providers/auth_provider.dart';
import 'package:ai_accessibility_assistant/providers/data_provider.dart';
import 'package:ai_accessibility_assistant/providers/navigation_provider.dart';
import 'package:ai_accessibility_assistant/screens/customer_detail_screen.dart';
import 'package:ai_accessibility_assistant/screens/edit_invoice_screen.dart';
import 'package:ai_accessibility_assistant/services/api_service.dart';
import 'package:ai_accessibility_assistant/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

final _accountJson = <String, dynamic>{
  'customer': {'id': 'c1', 'name': 'خالد الدمشقي', 'phone': '0955445566', 'address': 'اللاذقية'},
  'invoices': [
    {
      'id': 'i2',
      'number': 'INV-00012',
      'customerId': 'c1',
      'customer': {'id': 'c1', 'name': 'خالد الدمشقي'},
      'total': '850000',
      'status': 'PENDING',
      'notes': 'التسليم الأحد',
      'date': '2026-10-20T10:00:00.000Z',
      'items': [
        {
          'id': 'x2',
          'productId': 'p2',
          'quantity': 1,
          'unitPrice': '850000',
          'subtotal': '850000',
          'product': {'id': 'p2', 'name': 'طابعة فواتير'},
        },
      ],
    },
    {
      'id': 'i1',
      'number': 'INV-00003',
      'customerId': 'c1',
      'customer': {'id': 'c1', 'name': 'خالد الدمشقي'},
      'total': '3000000',
      'status': 'PAID',
      'date': '2026-09-01T10:00:00.000Z',
      'items': [
        {
          'id': 'x1',
          'productId': 'p1',
          'quantity': 2,
          'unitPrice': '1500000',
          'subtotal': '3000000',
          'product': {'id': 'p1', 'name': 'برنامج محاسبة'},
        },
      ],
    },
  ],
  'products': [
    {'productId': 'p1', 'name': 'برنامج محاسبة', 'quantity': 2, 'amount': '3000000', 'lastDate': '2026-09-01T10:00:00.000Z'},
    {'productId': 'p2', 'name': 'طابعة فواتير', 'quantity': 1, 'amount': '850000', 'lastDate': '2026-10-20T10:00:00.000Z'},
  ],
  'stats': {
    'invoiceCount': 2,
    'counts': {'PAID': 1, 'PENDING': 1, 'DRAFT': 0, 'CANCELLED': 0},
    'totalAmount': '3850000',
    'paidAmount': '3000000',
    'pendingAmount': '850000',
    'totalUnits': 3,
  },
};

class _FakeApi extends ApiService {
  Map<String, dynamic>? savedChanges;
  String? savedId;
  String? statusSet;
  bool failAccount = false;

  @override
  Future<CustomerAccount> getCustomerAccount(String id) async {
    if (failAccount) throw Exception('انقطع الاتصال');
    return CustomerAccount.fromJson(_accountJson);
  }

  @override
  Future<Invoice> updateInvoice(String id, Map<String, dynamic> data) async {
    savedId = id;
    savedChanges = data;
    return Invoice.fromJson((_accountJson['invoices'] as List).first as Map<String, dynamic>);
  }

  @override
  Future<Invoice> updateInvoiceStatus(String id, String status) async {
    statusSet = status;
    return Invoice.fromJson((_accountJson['invoices'] as List).first as Map<String, dynamic>);
  }

  @override
  Future<List<Invoice>> getInvoices({String? customerName, String? status}) async => [];

  @override
  Future<List<Customer>> getCustomers({String? search}) async => [];

  @override
  Future<List<Product>> getProducts({String? search}) async => [];

  @override
  Future<Map<String, dynamic>> getSummary() async => {};
}

class _FakeAuth extends AuthProvider {
  final bool admin;
  _FakeAuth(this.admin);

  @override
  UserModel? get user => UserModel(
        id: 'u1',
        email: 'a@b.c',
        name: 'مدير',
        role: admin ? 'ADMIN' : 'USER',
      );
}

final _shotKey = GlobalKey();

Widget _app(_FakeApi api, {required bool admin, required Widget home}) {
  final data = DataProvider(api)
    ..products = [
      Product(id: 'p1', name: 'برنامج محاسبة', price: 1500000, stock: 40),
      Product(id: 'p2', name: 'طابعة فواتير', price: 850000, stock: 5),
      Product(id: 'p3', name: 'دفتر حسابات', price: 35000, stock: 100),
    ];
  final nav = NavigationProvider();
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<DataProvider>.value(value: data),
      ChangeNotifierProvider<AuthProvider>.value(value: _FakeAuth(admin)),
      ChangeNotifierProvider<NavigationProvider>.value(value: nav),
    ],
    child: RepaintBoundary(
      key: _shotKey,
      child: MaterialApp(
        navigatorKey: nav.navigatorKey,
        theme: AppTheme.light(largeControls: true),
        builder: (context, child) =>
            Directionality(textDirection: TextDirection.rtl, child: child!),
        home: home,
      ),
    ),
  );
}

/// Set SHOT_DIR to also write what the screen looks like, in the real fonts.
Future<void> _shot(WidgetTester tester, String name) async {
  final dir = Platform.environment['SHOT_DIR'];
  if (dir == null) return;
  await tester.runAsync(() async {
    final boundary = _shotKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1.0);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File('$dir/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
  });
}

Future<void> _loadFonts() async {
  Future<void> load(String family, List<String> paths) async {
    final loader = FontLoader(family);
    for (final path in paths) {
      final file = File(path);
      if (file.existsSync()) {
        loader.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
      }
    }
    await loader.load();
  }

  await load(AppTheme.fontFamily, [
    'assets/fonts/IBMPlexSansArabic-Regular.ttf',
    'assets/fonts/IBMPlexSansArabic-SemiBold.ttf',
    'assets/fonts/IBMPlexSansArabic-Bold.ttf',
  ]);
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null) {
    await load('MaterialIcons', ['$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']);
  }
}

void _phoneSize(WidgetTester tester, {double height = 844}) {
  tester.view.physicalSize = Size(430, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  setUpAll(_loadFonts);

  testWidgets('shows totals, products and each invoice with its date', (tester) async {
    _phoneSize(tester, height: 1500);
    final api = _FakeApi();
    await tester.pumpWidget(_app(api, admin: true, home: const CustomerDetailScreen(customerId: 'c1')));
    await tester.pumpAndSettle();
    await _shot(tester, 'customer_page');

    expect(find.text('الفواتير (2)'), findsOneWidget);
    expect(find.text('المنتجات التي اشتراها'), findsOneWidget);
    expect(find.text('2 قطعة'), findsOneWidget);
    // Totals and the two invoices, each with its own number and date.
    expect(find.text('3,850,000 ل.س'), findsOneWidget);
    expect(find.text('INV-00012'), findsOneWidget);
    expect(find.text('INV-00003'), findsOneWidget);
    expect(find.text('2026/10/20'), findsOneWidget);
    expect(find.text('2026/09/01'), findsOneWidget);
    expect(find.text('برنامج محاسبة × 2'), findsOneWidget);
    expect(find.text('ملاحظة: التسليم الأحد'), findsOneWidget);
    expect(find.text('تعديل'), findsNWidgets(2));
    // Only the pending invoice can still be marked paid.
    expect(find.text('مدفوعة'), findsWidgets);
  });

  testWidgets('filter chips narrow the invoices', (tester) async {
    _phoneSize(tester, height: 1500);
    await tester.pumpWidget(_app(_FakeApi(), admin: true, home: const CustomerDetailScreen(customerId: 'c1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('معلقة 1'));
    await tester.pumpAndSettle();
    expect(find.text('INV-00012'), findsOneWidget);
    expect(find.text('INV-00003'), findsNothing);
  });

  testWidgets('a regular user sees the account but cannot edit', (tester) async {
    _phoneSize(tester, height: 1500);
    await tester.pumpWidget(_app(_FakeApi(), admin: false, home: const CustomerDetailScreen(customerId: 'c1')));
    await tester.pumpAndSettle();
    expect(find.text('INV-00012'), findsOneWidget);
    expect(find.text('تعديل'), findsNothing);
    expect(find.byTooltip('تعديل بيانات العميل'), findsNothing);
  });

  testWidgets('a failed load offers a retry instead of hanging', (tester) async {
    _phoneSize(tester);
    final api = _FakeApi()..failAccount = true;
    await tester.pumpWidget(_app(api, admin: true, home: const CustomerDetailScreen(customerId: 'c1')));
    await tester.pumpAndSettle();
    expect(find.text('انقطع الاتصال'), findsOneWidget);
    api.failAccount = false;
    await tester.tap(find.text('إعادة المحاولة'));
    await tester.pumpAndSettle();
    expect(find.text('INV-00012'), findsOneWidget);
  });

  testWidgets('marking an invoice paid calls the API and reloads', (tester) async {
    _phoneSize(tester, height: 1500);
    final api = _FakeApi();
    await tester.pumpWidget(_app(api, admin: true, home: const CustomerDetailScreen(customerId: 'c1')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'مدفوعة'));
    await tester.pumpAndSettle();
    expect(api.statusSet, 'PAID');
  });

  group('editing an invoice', () {
    Invoice invoice() => Invoice.fromJson((_accountJson['invoices'] as List).last as Map<String, dynamic>);

    testWidgets('quantity, new product, notes and status are saved', (tester) async {
      _phoneSize(tester, height: 1200);
      final api = _FakeApi();
      await tester.pumpWidget(_app(api, admin: true, home: EditInvoiceScreen(invoice: invoice())));
      await tester.pumpAndSettle();
      await _shot(tester, 'edit_invoice');
      expect(find.text('3,000,000 ل.س'), findsOneWidget);

      await tester.tap(find.byTooltip('زيادة'));
      await tester.pump();
      expect(find.text('4,500,000 ل.س'), findsOneWidget);

      await tester.tap(find.text('إضافة منتج'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('دفتر حسابات'));
      await tester.pumpAndSettle();
      expect(find.text('4,535,000 ل.س'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, 'ملاحظات'), 'عدّلها المدير');
      await tester.tap(find.text('حفظ التعديلات'));
      await tester.pumpAndSettle();

      expect(api.savedId, 'i1');
      expect(api.savedChanges!['items'], [
        {'productId': 'p1', 'quantity': 3},
        {'productId': 'p3', 'quantity': 1},
      ]);
      expect(api.savedChanges!['notes'], 'عدّلها المدير');
      expect(api.savedChanges!.containsKey('status'), isFalse);
    });

    testWidgets('quantity cannot pass stock plus what the invoice holds', (tester) async {
      _phoneSize(tester, height: 1200);
      // p1: 40 in stock + 2 on this invoice = at most 42.
      await tester.pumpWidget(_app(_FakeApi(), admin: true, home: EditInvoiceScreen(invoice: invoice())));
      await tester.pumpAndSettle();
      expect(find.textContaining('الحد 42'), findsOneWidget);
    });

    testWidgets('removing every product is refused', (tester) async {
      _phoneSize(tester, height: 1200);
      final api = _FakeApi();
      await tester.pumpWidget(_app(api, admin: true, home: EditInvoiceScreen(invoice: invoice())));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('حذف المنتج'));
      await tester.pump();
      await tester.tap(find.text('حفظ التعديلات'));
      await tester.pump();
      expect(api.savedChanges, isNull);
      expect(find.text('الفاتورة تحتاج منتجاً واحداً على الأقل'), findsOneWidget);
    });
  });
}

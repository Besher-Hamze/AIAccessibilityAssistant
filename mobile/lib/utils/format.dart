import 'package:intl/intl.dart';

class AppFormat {
  static final _money = NumberFormat('#,##0.##', 'en');
  static final _date = DateFormat('yyyy/MM/dd');

  static String money(num value) => '${_money.format(value)} ل.س';

  static String date(DateTime value) => _date.format(value.toLocal());
}

import 'package:intl/intl.dart';

String formatVnd(num value) {
  return '${NumberFormat.decimalPattern('vi_VN').format(value)}₫';
}
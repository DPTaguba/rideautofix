import 'package:cloud_firestore/cloud_firestore.dart';

/// Flat fee added to every home-service booking (service fee + this = total).
const kHomeServiceFee = 150.0;

const kStatuses = [
  'Pending',
  'Confirmed',
  'On the Way',
  'In Service',
  'Completed',
  'Cancelled',
];
const kProgressSteps = [
  'Pending',
  'Confirmed',
  'On the Way',
  'In Service',
  'Completed',
];
const kTimeSlots = [
  '8:00 AM',
  '9:00 AM',
  '10:00 AM',
  '11:00 AM',
  '1:00 PM',
  '2:00 PM',
  '3:00 PM',
  '4:00 PM',
  '5:00 PM',
];
const kVehicleTypes = ['Car', 'SUV', 'Motorcycle', 'Van', 'Truck'];
const kPaymentMethods = ['Cash', 'GCash', 'Card'];

bool isActiveStatus(String s) => s != 'Completed' && s != 'Cancelled';

/// 24h hour for a slot label such as "1:00 PM".
int slotHour(String slot) {
  final parts = slot.split(RegExp(r'[: ]'));
  var h = int.parse(parts[0]);
  final pm = parts[2] == 'PM';
  if (pm && h != 12) h += 12;
  if (!pm && h == 12) h = 0;
  return h;
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];
const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String fmtDate(DateTime d) =>
    '${_days[d.weekday - 1]}, ${_months[d.month - 1]} ${d.day}, ${d.year}';

String money(num v) {
  final fixed = v.toStringAsFixed(v % 1 == 0 ? 0 : 2);
  final parts = fixed.split('.');
  final whole = parts[0].replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  return '₱$whole${parts.length > 1 ? '.${parts[1]}' : ''}';
}

String shortId(String id) =>
    '#${id.substring(0, id.length < 6 ? id.length : 6).toUpperCase()}';

num numOf(dynamic v) => v is num ? v : (num.tryParse('$v') ?? 0);

String txt(Map<String, dynamic> m, String key, [String fallback = '']) {
  final v = m[key];
  return v == null || '$v'.isEmpty ? fallback : '$v';
}

DateTime? tsToDate(dynamic v) => v is Timestamp ? v.toDate() : null;

DateTime sortKey(Map<String, dynamic> m) =>
    tsToDate(m['scheduledAt']) ??
    tsToDate(m['createdAt']) ??
    DateTime.fromMillisecondsSinceEpoch(0);

String vehicleTitle(Map<String, dynamic> m) => [m['brand'], m['model'], m['year']]
    .where((e) => e != null && '$e'.isNotEmpty)
    .join(' ');

/// Serves a smaller, auto-optimised copy of a Cloudinary image so lists stay
/// fast on mobile data. Non-Cloudinary URLs are returned unchanged.
String cldUrl(String url, {int w = 600, int? h}) {
  const marker = '/upload/';
  final i = url.indexOf(marker);
  if (i < 0 || !url.contains('res.cloudinary.com')) return url;
  final crop = h == null ? 'c_limit,w_$w' : 'c_fill,g_auto,w_$w,h_$h';
  return '${url.substring(0, i + marker.length)}$crop,q_auto,f_auto/'
      '${url.substring(i + marker.length)}';
}

// ---- validators -----------------------------------------------------------

final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

String? requiredText(String? v, String label) =>
    (v == null || v.trim().isEmpty) ? 'Enter $label' : null;

String? emailValidator(String? v) {
  if (v == null || v.trim().isEmpty) return 'Enter your email address';
  if (!_emailRe.hasMatch(v.trim())) return 'Enter a valid email, e.g. name@example.com';
  return null;
}

String? phoneValidator(String? v) {
  if (v == null || v.trim().isEmpty) return 'Enter your mobile number';
  final d = v.replaceAll(RegExp(r'[\s-]'), '');
  if (!RegExp(r'^(\+63|0)9\d{9}$').hasMatch(d)) {
    return 'Use a valid mobile number, e.g. 09171234567';
  }
  return null;
}

String? passwordValidator(String? v) {
  if (v == null || v.isEmpty) return 'Enter a password';
  if (v.length < 8) return 'Use at least 8 characters';
  return null;
}
DateTime? parseDate(String dateStr) {
  final parts = dateStr.split('/');
  if (parts.length != 3) return null;
  final day = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final year = int.tryParse(parts[2]);
  if (day == null || month == null || year == null) return null;
  return DateTime(year, month, day);
}

String formatDate(DateTime date) {
  final d = date.day.toString().padLeft(2, '0');
  final m = date.month.toString().padLeft(2, '0');
  return '$d/$m/${date.year}';
}

bool isWithinDays(String dateStr, int days) {
  final date = parseDate(dateStr);
  if (date == null) return false;
  final today = DateTime.now();
  final todayStart = DateTime(today.year, today.month, today.day);
  final futureDate = todayStart.add(Duration(days: days));
  return !date.isBefore(todayStart) && !date.isAfter(futureDate);
}

bool isInRange(String dateStr, String startStr, String endStr) {
  final date = parseDate(dateStr);
  final start = parseDate(startStr);
  final end = parseDate(endStr);
  if (date == null || start == null || end == null) return false;
  return !date.isBefore(start) && !date.isAfter(end);
}

int compareDates(String a, String b) {
  final dateA = parseDate(a);
  final dateB = parseDate(b);
  if (dateA == null || dateB == null) return 0;
  return dateA.compareTo(dateB);
}

String applyDateMask(String text) {
  final digits = text.replaceAll(RegExp(r'\D'), '');
  var masked = '';
  for (var i = 0; i < digits.length && i < 8; i++) {
    if (i == 2 || i == 4) masked += '/';
    masked += digits[i];
  }
  return masked;
}

abstract final class Fmt {
  static String qty(double v) {
    if ((v - v.roundToDouble()).abs() < 0.01) return v.round().toString();
    final s = v.toStringAsFixed(v < 10 ? 2 : 1);
    return s.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  static String money(double v) => '\$${v.toStringAsFixed(2)}';

  static String minutes(int m) => m < 60 ? '$m min' : '${m ~/ 60} h ${m % 60 == 0 ? '' : '${m % 60} min'}'.trim();

  static const _months = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];

  static String date(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

  static String relative(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'ahora';
    if (diff.inHours < 1) return 'hace ${diff.inMinutes} min';
    if (diff.inDays < 1) return 'hace ${diff.inHours} h';
    if (diff.inDays < 7) return 'hace ${diff.inDays} d';
    return date(d);
  }
}

typedef Formatted = ({String value, String unit});

/// All number formatting in one place, so units stay consistent.
class Fmt {
  Fmt._();

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static Formatted distance(double meters, {bool miles = false}) {
    if (miles) {
      final mi = meters / 1609.344;
      return (value: mi.toStringAsFixed(mi < 10 ? 2 : 1), unit: 'mi');
    }
    final km = meters / 1000;
    return (value: km.toStringAsFixed(km < 10 ? 2 : 1), unit: 'km');
  }

  static String duration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  static Formatted pace(double meters, Duration d, {bool miles = false}) {
    final unit = miles ? '/mi' : '/km';
    if (meters < 20 || d.inSeconds == 0) return (value: '--:--', unit: unit);
    final perUnit = d.inSeconds / (meters / (miles ? 1609.344 : 1000));
    if (perUnit > 3599) return (value: '--:--', unit: unit);
    final total = perUnit.round();
    final mm = (total ~/ 60).toString();
    final ss = (total % 60).toString().padLeft(2, '0');
    return (value: '$mm:$ss', unit: unit);
  }

  static Formatted area(double m2) {
    if (m2 < 10000) return (value: m2.round().toString(), unit: 'm²');
    final km2 = m2 / 1e6;
    return (value: km2.toStringAsFixed(km2 < 1 ? 3 : 2), unit: 'km²');
  }

  static String date(DateTime d) =>
      '${d.day} ${_months[d.month - 1]} ${d.year}';

  static String dateTime(DateTime d) {
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '${date(d)}, $h:$m';
  }
}

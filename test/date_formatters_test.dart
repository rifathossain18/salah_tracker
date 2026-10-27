import 'package:flutter_test/flutter_test.dart';
import 'package:salah_tracker/domain/date_formatters.dart';

void main() {
  test('formats English digits and dates without network locale data', () {
    final date = DateTime(2026, 10, 25);

    expect(DateFormatters.digits(205), '205');
    expect(DateFormatters.month(date), 'October 2026');
    expect(DateFormatters.dateMain(date), '25 October');
    expect(DateFormatters.weekday(date), 'Sunday');
  });
}

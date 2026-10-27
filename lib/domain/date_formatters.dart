class DateFormatters {
  static const List<String> monthNames = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static const List<String> weekdayNames = <String>[
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static String digits(int value) => value.toString();

  static String month(DateTime date) =>
      '${monthNames[date.month - 1]} ${digits(date.year)}';

  static String dateMain(DateTime date) =>
      '${digits(date.day)} ${monthNames[date.month - 1]}';

  static String weekday(DateTime date) => weekdayNames[date.weekday - 1];

  static String dateSub(DateTime date) =>
      '${weekday(date)} · ${digits(date.year)}';

  static String fullDate(DateTime date) =>
      '${weekday(date)}, ${digits(date.day)} ${monthNames[date.month - 1]} ${digits(date.year)}';
}

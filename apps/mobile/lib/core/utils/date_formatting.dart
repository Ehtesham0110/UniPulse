const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

const _weekdays = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
];

/// Formats a date as "5 Jul, 2026" without pulling in the `intl` package.
String formatEventDate(DateTime date) {
  return '${date.day} ${_months[date.month - 1]}, ${date.year}';
}

/// Returns the full weekday name, e.g. "Sunday".
String formatWeekday(DateTime date) {
  return _weekdays[date.weekday - 1];
}

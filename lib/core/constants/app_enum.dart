// app_enum.dart
enum IconFill { outlined, filled }
enum CardFilter { all, unread, bookmarked }
enum HeaderMenu { import, login, logout }

extension IconFillValue on IconFill {
  double get value => this == IconFill.filled ? 1 : 0;
}

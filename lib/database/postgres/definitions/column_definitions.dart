import 'dart:ffi';

import 'package:pg_dorm/pg_dorm.dart';

class BaseColumnDefinition<T> {
  String name;
  bool isNull;
  bool isUnique;
  bool isIndex;
  bool isPrimaryKey;
  T? defaultValue;
  BaseColumnDefinition(
      {required this.name,
      this.isNull = false,
      this.isUnique = false,
      this.isIndex = false,
      this.isPrimaryKey = false,
      this.defaultValue});
}

// String/Text
class CharfieldColumnDefinition extends BaseColumnDefinition<String> {
  int maxLength;
  CharfieldColumnDefinition(
      {required super.name,
      required this.maxLength,
      super.isNull = false,
      super.isUnique = false,
      super.isIndex = false,
      super.isPrimaryKey = false,
      super.defaultValue});
}

class TextFieldColumnDefinition extends BaseColumnDefinition<String> {
  TextFieldColumnDefinition({required super.name});
}

// Date/time

class DateColumnDefinition extends BaseColumnDefinition<DateTime> {
  bool useTimezone;
  DateColumnDefinition({required super.name, this.useTimezone = false});
}

class DateTimeColumnDefinition extends BaseColumnDefinition<DateTime> {
  bool useTimezone;
  DateTimeColumnDefinition({required super.name, this.useTimezone = false});
}

class TimeColumnDefinition extends BaseColumnDefinition<Time> {
  TimeColumnDefinition({required super.name});
}

class DateRangeColumnDefinition extends BaseColumnDefinition<DateRange> {
  DateRangeColumnDefinition({required super.name});
}

// Numbers Column definitions

class NumberColumnDefinition extends BaseColumnDefinition<num> {
  NumberColumnDefinition({required super.name});
}

class DecimalColumnDefinition extends BaseColumnDefinition<Float> {
  int precision;
  DecimalColumnDefinition({required super.name, required this.precision});
}

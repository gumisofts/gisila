export 'error_mapper.dart';
export 'postgresql_exceptions.dart';

class DefaultValueException implements Exception {
  String msg;
  DefaultValueException({required this.msg});
}

class QueryException implements Exception {
  String msg;
  QueryException({required this.msg});
}

class ValidationException implements Exception {
  List<String> errors;
  ValidationException({required this.errors});
}

class FieldValidationException implements Exception {
  FieldValidationException({
    required this.error,
    this.msg = 'Invalid field',
  });
  String msg;
  Map<String, dynamic> error;
}

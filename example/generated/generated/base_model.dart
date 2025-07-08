part of '../models.dart';

/// Base model class for all generated models
abstract class BaseModel {
  /// Convert model to map for database operations
  Map<String, dynamic> toMap();
  
  /// Validate model instance
  List<String> validate();
}

/// Validation exception for model validation errors
class ValidationException implements Exception {
  final List<String> errors;
  ValidationException(this.errors);

  @override
  String toString() => 'ValidationException: ${errors.join(", ")}';
}

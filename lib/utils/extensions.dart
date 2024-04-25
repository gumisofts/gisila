import 'package:project_mega/models/models.dart';

extension ApiUser on User? {
  bool get isAuthenticated => this != null;
}

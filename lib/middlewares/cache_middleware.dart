// ignore_for_file: public_member_api_docs

import 'package:dart_frog/dart_frog.dart';

Handler cacheMiddleware(Handler handler) {
  return (context) async {
    final response = await handler(context);

    return response;
  };
}

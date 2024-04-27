import 'package:d_orm/database/database.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';
import 'package:project_mega/models/schema.dart';
import 'package:project_mega/utils/exceptions/api_exceptions.dart';
import 'package:project_mega/utils/forms/form_validators.dart';
import 'package:project_mega/utils/requests.dart';

Future<Response> onRequest(RequestContext context) => safeClosure(
      context,
      endpoint: () => requestMethodRouter(
        context,
        post: (context) async {
          final data = await form(
            context,
            fields: [
              FieldValidator<int>(
                name: 'otp',
                isRequired: true,
                validator: (value) => value > 99999 && value <= 999999
                    ? null
                    : 'otp should be six digit',
              ),
              FieldValidator<String>(
                name: 'otpType',
                isRequired: true,
                validator: (value) => ['email', 'phone'].contains(value)
                    ? null
                    : 'Unknown otpType',
              ),
              FieldValidator<int>(
                name: 'userId',
                isRequired: true,
              ),
            ],
          );

          final sql = Sql.named('''
SELECT "user".*,"password".* from "user" join "password" on "user"."userId"="password"."userId" where "user"."userId"= @userId and "password"."${data['otpType']}Otp"=@otp
    ''');
          data.remove('otpType');
          final res = await Database().execute(sql, parameters: data);

          final users = UserDb.fromResult(res);

          return Response.json(body: users.map((e) => e.toJson()));
        },
      ),
      permission: () {},
    );

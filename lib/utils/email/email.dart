import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:project_mega/models/models.dart';
import 'package:project_mega/utils/email/email_templates.dart';

class SendMail {
  static const _username = 'bita@gumiapps.com';
  static const _password = 'I*JFc+*BE(W7';
  static const _host = 'mail.gumiapps.com';

  static SmtpServer get _server =>
      SmtpServer(_host, password: _password, username: _username);
  static Future<void> sendOtp(String otp, User user) async {
    final content =
        (await EmailOtpTemplate.content).replaceFirst('{{OTP_HERE}}', otp);

    final message = Message()
      ..subject = 'Verify your account'
      ..from = 'bita@gumiapps.com'
      ..recipients.add(user.email)
      ..html = content;
    try {
      await send(message, _server);
    } catch (_) {}
  }
}

Future<bool> sendMail(User user, String msg) async {
  // add mail send feature here
  return true;
}

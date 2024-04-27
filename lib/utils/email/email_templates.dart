import 'dart:io';

class EmailOtpTemplate {
  static Future<String> get content async {
    final temp = File('lib/utils/email/templates/otp_sign_up_mail.html');

    return temp.readAsString();
  }
}

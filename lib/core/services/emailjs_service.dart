import 'dart:convert';
import 'package:http/http.dart' as http;

class EmailJSService {
  static const _apiUrl = 'https://api.emailjs.com/api/v1.0/email/send';

  static Future<bool> send({
    required String publicKey,
    required String serviceId,
    required String templateId,
    required String toEmail,
    required String toName,
    required String subject,
    required String messageHtml,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'service_id': serviceId,
          'template_id': templateId,
          'user_id': publicKey,
          'template_params': {
            'to_name': toName,
            'to_email': toEmail,
            'subject': subject,
            'message': messageHtml,
            'from_name': 'LendWUs',
          },
        }),
      );

      if (response.statusCode == 200) {
        return true;
      }

      print('EmailJS error ${response.statusCode}: ${response.body}');
      return false;
    } catch (e) {
      print('EmailJS send failed: $e');
      return false;
    }
  }

  static Future<bool> testConnection({
    required String publicKey,
    required String serviceId,
    required String templateId,
    required String toEmail,
  }) async {
    return send(
      publicKey: publicKey,
      serviceId: serviceId,
      templateId: templateId,
      toEmail: toEmail,
      toName: 'Test',
      subject: 'LendWUs — Test Email',
      messageHtml: '<p>This is a test email from LendWUs. If you received this, email notifications are working.</p>',
    );
  }
}

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:async';

class AIService {
  final http.Client httpClient;

  AIService({required this.httpClient});

  Future<bool> checkOpenAIAvailability() async {
    return dotenv.env['OPENAI_API_KEY'] != null && dotenv.env['OPENAI_API_KEY']!.isNotEmpty;
  }

  Future<bool> checkAIAvailability() async {
    String url = 'http://127.0.0.1:11434/api/tags';

    try {
      final response = await httpClient
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 2));
      return response.statusCode == 200;
    } on TimeoutException {
      print('AI service timeout: Connection timed out');
      return false;
    } catch (e) {
      print('AI service not available: $e');
      return false;
    }
  }
}
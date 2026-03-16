import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/constants.dart';
import '../models/chat_message.dart';

class ChatService {
  final String baseUrl;
  String? _authToken;

  ChatService({String? baseUrl}) : baseUrl = baseUrl ?? AppConstants.baseUrl;

  void setAuthToken(String token) {
    _authToken = token;
  }

  Map<String, String> _getHeaders() {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    return headers;
  }

  /// Get AI assistant help
  /// [query] - User's question or request
  /// [context] - Current screen/context (e.g., "scan_screen", "results_screen")
  /// [conversationHistory] - Previous messages for context (optional)
  Future<String> getAssistantHelp({
    required String query,
    String context = 'general',
    List<ChatMessage>? conversationHistory,
  }) async {
    try {
      // Prepare conversation history
      final messages = <Map<String, dynamic>>[];
      
      if (conversationHistory != null) {
        for (var msg in conversationHistory.take(5)) {
          // Keep last 5 messages for context
          messages.add({
            'role': msg.isUser ? 'user' : 'assistant',
            'content': msg.text,
          });
        }
      }

      // Add current query
      messages.add({
        'role': 'user',
        'content': query,
      });

      final response = await http
          .post(
            Uri.parse('$baseUrl/api/chat/assist'),
            headers: _getHeaders(),
            body: jsonEncode({
              'query': query,
              'context': context,
              'conversation_history': messages,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['response'] ?? 'I could not generate a response. Please try again.';
      } else {
        throw Exception('Failed to get assistance: ${response.body}');
      }
    } catch (e) {
      throw Exception('Chat error: $e');
    }
  }

  /// Get contextual tips for current screen
  /// [screenName] - Name of current screen
  Future<List<String>> getContextualTips(String screenName) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/chat/tips?screen=$screenName'),
            headers: _getHeaders(),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> tips = data['tips'] ?? [];
        return tips.map((tip) => tip.toString()).toList();
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  /// Get help for a specific feature
  /// [feature] - Feature name (e.g., "scanning", "verification", "results")
  Future<String> getFeatureHelp(String feature) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/chat/help/$feature'),
            headers: _getHeaders(),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['help'] ?? 'No help available for this feature.';
      } else {
        throw Exception('Failed to get help: ${response.body}');
      }
    } catch (e) {
      throw Exception('Help error: $e');
    }
  }
}

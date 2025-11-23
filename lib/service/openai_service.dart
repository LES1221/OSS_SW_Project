import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class OpenAIService {
  OpenAIService._();
  static final _instance = OpenAIService._();
  factory OpenAIService() => _instance;

  // OpenAI API 설정
  static const String _baseUri = "https://api.openai.com/v1";
  late final String _apiKey;
  late final String _assistantId;

  // Thread ID 저장 키
  static const String _threadIdKey = 'openai_thread_id';

  // 초기화
  Future<void> initialize() async {
    _apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
    _assistantId = dotenv.env['OPENAI_ASSISTANT_ID'] ?? '';

    if (_apiKey.isEmpty || _assistantId.isEmpty) {
      throw Exception('API Key or Assistant ID is missing in .env file');
    }

    // Thread ID가 없으면 새로 생성\
    final threadId = await _getStoredThreadId();
    if (threadId == null) {
      await _createAndStoreThread();
    }
  }

  // 공통 헤더
  Map<String, String> get _headers => {
    'Authorization': 'Bearer $_apiKey',
    'Content-Type': 'application/json',
    'OpenAI-Beta': 'assistants=v2',
  };

  // Thread ID 가져오기 (로컬 저장소)
  Future<String?> _getStoredThreadId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_threadIdKey);
  }

  // Thread ID 저장
  Future<void> _saveThreadId(String threadId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_threadIdKey, threadId);
  }

  // 1. Thread 생성
  Future<String> _createThread() async {
    final response = await http.post(
      Uri.parse('$_baseUri/threads'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['id'];
    } else {
      throw Exception('Failed to create thread: ${response.body}');
    }
  }

  // Thraed 생성 및 저장
  Future<void> _createAndStoreThread() async {
    final threadId = await _createThread();
    await _saveThreadId(threadId);
    print('new thread created: $threadId');
  }

  // 2. Message 추가
  Future<void> _addMessage(String threadId, String content) async {
    final response = await http.post(
      Uri.parse('$_baseUri/threads/$threadId/messages'),
      headers: _headers,
      body: json.encode({'role': 'user', 'content': content}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to add message: ${response.body}');
    }
  }

  // 3. Run 생성
  Future<String> _createRun(String threadId) async {
    final response = await http.post(
      Uri.parse("$_baseUri/threads/$threadId/runs"),
      headers: _headers,
      body: json.encode({'assistant_id': _assistantId}),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['id'];
    } else {
      throw Exception('Failed to create run: ${response.body}');
    }
  }

  // 4. Run 상태 확인 (Polling)
  Future<String> _waitForRunCompletion(String threadId, String runId) async {
    while (true) {
      final response = await http.get(
        Uri.parse("$_baseUri/threads/$threadId/runs/$runId"),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final status = data['status'];

        if (status == 'completed') {
          return 'completed';
        } else if (status == 'failed' ||
            status == 'cancelled' ||
            status == 'expired') {
          throw Exception('Run failed with status: $status');
        }

        // 0.5초 대기 후 다시 확인
        await Future.delayed(Duration(milliseconds: 500));
      } else {
        throw Exception('Failed to check run status: ${response.body}');
      }
    }
  }

  // 5. Messages 조회
  Future<String> _getLatestAssistantMessage(String threadId) async {
    final response = await http.get(
      Uri.parse('$_baseUri/threads/$threadId/messages?limit=1&order=desc'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final messages = data['data'] as List;

      if (messages.isNotEmpty) {
        final message = messages[0];
        if (message['role'] == 'assistant') {
          final content = message['content'] as List;
          if (content.isNotEmpty && content[0]['type'] == 'text') {
            return content[0]['text']['value'];
          }
        }
      }
      throw Exception('No assistant message found');
    } else {
      throw Exception('Failed to get messages: ${response.body}');
    }
  }
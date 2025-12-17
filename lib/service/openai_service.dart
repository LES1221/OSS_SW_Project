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
  // Thread의 모든 메시지 가져오기
  Future<List<Map<String, dynamic>>> getThreadMessages() async {
    try {
      final threadId = await _getStoredThreadId();
      if (threadId == null) {
        return [];
      }

      final response = await http.get(
        Uri.parse('$_baseUri/threads/$threadId/messages?order=asc'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final messages = data['data'] as List;

        // 메시지를 파싱하여 반환
        return messages.map<Map<String, dynamic>>((msg) {
          final role = msg['role'] as String;
          final content = msg['content'] as List;
          String text = '';

          if (content.isNotEmpty && content[0]['type'] == 'text') {
            text = content[0]['text']['value'];
          }

          return {
            'text': text,
            'isUser': role == 'user',
            'timestamp': msg['created_at'],
          };
        }).toList();
      } else {
        throw Exception('Failed to get thread messages: ${response.body}');
      }
    } catch (e) {
      print('Error loading thread messages: $e');
      return [];
    }
  }

  // 메인 함수: 메시지 전송 및 응답 받기 (Streaming)
  Stream<String> sendMessageStream(String userMessage) async* {
    try {
      // Thread ID 가져오기
      final threadId = await _getStoredThreadId();
      if (threadId == null) {
        throw Exception('Thread ID not found. Please restart the app.');
      }

      // 1. Message 추가
      await _addMessage(threadId, userMessage);

      // 2. Run 생성 with streaming
      final request = http.Request(
        'POST',
        Uri.parse('$_baseUri/threads/$threadId/runs'),
      );
      request.headers.addAll(_headers);
      request.headers['Accept'] = 'text/event-stream';
      request.body = json.encode({
        'assistant_id': _assistantId,
        'stream': true,
      });

      final client = http.Client();
      final response = await client.send(request);

      if (response.statusCode != 200) {
        throw Exception('Failed to create streaming run: ${response.statusCode}');
      }

      // 3. SSE 스트림 파싱
      String buffer = '';
      await for (var chunk in response.stream.transform(utf8.decoder)) {
        buffer += chunk;

        // 줄바꿈으로 이벤트 분리
        final lines = buffer.split('\n');
        buffer = lines.last; // 마지막 불완전한 줄은 버퍼에 유지

        for (int i = 0; i < lines.length - 1; i++) {
          final line = lines[i].trim();

          if (line.startsWith('data: ')) {
            final data = line.substring(6);

            // [DONE] 체크
            if (data == '[DONE]') {
              client.close();
              return;
            }

            try {
              final jsonData = json.decode(data);

              // thread.message.delta 이벤트에서 텍스트 추출
              if (jsonData['object'] == 'thread.message.delta') {
                final delta = jsonData['delta'];
                if (delta != null && delta['content'] != null) {
                  final contents = delta['content'] as List;
                  for (var content in contents) {
                    if (content['type'] == 'text' && content['text'] != null) {
                      final textDelta = content['text']['value'];
                      if (textDelta != null && textDelta.isNotEmpty) {
                        yield textDelta;
                      }
                    }
                  }
                }
              }
            } catch (e) {
              // JSON 파싱 에러는 무시 (메타데이터 등)
              continue;
            }
          }
        }
      }

      client.close();
    } catch (e) {
      throw Exception('Failed to send message: $e');
    }
  }

  // 기존 메서드 유지 (비-스트리밍)
  Future<String> sendMessage(String userMessage) async {
    try {
      // Thread ID 가져오기
      final threadId = await _getStoredThreadId();
      if (threadId == null) {
        throw Exception('Thread ID not found. Please restart the app.');
      }

      // 1. Message 추가
      await _addMessage(threadId, userMessage);

      // 2. Run 생성
      final runId = await _createRun(threadId);

      // 3. Run 완료 대기
      await _waitForRunCompletion(threadId, runId);

      // 4. AI 응답 가져오기
      final response = await _getLatestAssistantMessage(threadId);

      return response;
    } catch (e) {
      throw Exception('Failed to send message: $e');
    }
  }
}

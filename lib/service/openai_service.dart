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
  
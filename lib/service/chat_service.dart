import 'package:finance_chatbot/model/chat_message.dart';

class ChatService {
  ChatService._();
  static final _instance = ChatService._();
  factory ChatService() => _instance;

  // 메시지 List
  final List<ChatMessage> messages = [];
  final _openAIService = OpenAIService();

  // Thread에서 메시지 로드
  Future<void> loadMessagesFromThread() async {
    try {
      final threadMessages = await _openAIService.getThreadMessages();

      // 기존 메시지 클리어
      messages.clear();

      // Thread 메시지를 ChatMessage로 변환하여 추가
      for (var msg in threadMessages) {
        final message = ChatMessage(
          text: msg['text'],
          isUser: msg['isUser'],
          timestamp: DateTime.fromMillisecondsSinceEpoch(msg['timestamp'] * 1000),
        );
        messages.add(message);
      }
    } catch (e) {
      print('Failed to load messages from thread: $e');
    }
  }

  // 메시지 추가 (사용자 메시지만)
  void addUserMessage(String text) {
    final message = ChatMessage(
      text: text,
      isUser: true,
      timestamp: DateTime.now(),
    );
    messages.add(message);
  }

  // AI 메시지 추가
  void addAIMessage(String text) {
    final message = ChatMessage(
      text: text,
      isUser: false,
      timestamp: DateTime.now(),
    );
    messages.add(message);
  }

  // AI에게 메시지 전송 및 스트리밍 응답 받기
  Stream<String> sendMessageToAIStream(String userMessage) {
    try {
      return _openAIService.sendMessageStream(userMessage);
    } catch (e) {
      throw Exception('AI 응답 실패: $e');
    }
  }

  // 기존 메서드 유지 (비-스트리밍)
  Future<String> sendMessageToAI(String userMessage) async {
    try {
      final response = await _openAIService.sendMessage(userMessage);
      return response;
    } catch (e) {
      throw Exception('AI 응답 실패: $e');
    }
  }

  // 모든 메시지 가져오기
  List<ChatMessage> getMessages() {
    return messages;
  }

  // 메시지 개수
  int get messageCount => messages.length;
}

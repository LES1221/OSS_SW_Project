import 'package:flutter/material.dart';
import 'package:introduction_screen/introduction_screen.dart'; // [OSS 1] 앱 소개 화면 라이브러리
import 'package:dash_chat_2/dash_chat_2.dart'; // [OSS 2] 채팅 UI 라이브러리
import 'package:finance_chatbot/service/chat_service.dart'; // [Custom] OpenAI API 연동 서비스

void main() {
  runApp(const IbkChatbotApp());
}

class IbkChatbotApp extends StatelessWidget {
  const IbkChatbotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IBK 기업은행 AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // IBK 기업은행 시그니처 컬러 (짙은 파란색) 적용
        primaryColor: const Color(0xFF134F9C),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF134F9C)),
        useMaterial3: true,
      ),
      // 앱 실행 시 첫 화면을 '소개 페이지'로 설정
      home: const IntroPage(),
    );
  }
}


// =========================================================
// [OSS 활용 1] Introduction Screen (앱 온보딩 화면)
// 사용자에게 앱의 주요 기능을 슬라이드 형태로 안내
// =========================================================
class IntroPage extends StatelessWidget {
  const IntroPage({super.key});

  @override
  Widget build(BuildContext context) {
    return IntroductionScreen(
      pages: [
        // 슬라이드 1: 앱 정체성 소개
        PageViewModel(
          title: "스마트한 금융 비서",
          body: "IBK 기업은행의 새로운 AI 서비스입니다.\n복잡한 은행 업무를 대화로 해결하세요.",
          image: const Center(
            child: Icon(Icons.account_balance, size: 100, color: Color(0xFF134F9C)),
          ),
          decoration: const PageDecoration(
            titleTextStyle: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ),
        // 슬라이드 2: 기능 안내
        PageViewModel(
          title: "간편한 상담",
          body: "궁금한 점을 채팅으로 물어보세요.",
          image: const Center(
            child: Icon(Icons.chat_bubble_outline, size: 100, color: Colors.blueAccent),
          ),
        ),
        // 3. 맞춤형 추천 (기능 강조)
        PageViewModel(
          title: "나를 위한 맞춤 상품",
          body: "수많은 예금, 적금, 대출 상품 중에서\n고객님께 딱 맞는 최적의 상품을 찾아드려요.",
          image: const Center(
            child: Icon(Icons.analytics_outlined, size: 100, color: Colors.indigo),
          ),
          decoration: const PageDecoration(
            titleTextStyle: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ),

        // 4. 강력한 보안 (신뢰도 강조)
        PageViewModel(
          title: "철저한 보안 시스템",
          body: "고객님의 소중한 금융 정보를\n가장 안전한 보안 기술로 보호합니다.",
          image: const Center(
            child: Icon(Icons.security, size: 100, color: Colors.green),
          ),
          decoration: const PageDecoration(
            titleTextStyle: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ),

        // 5. 시작 유도
        PageViewModel(
          title: "지금 바로 시작하세요",
          body: "궁금한 점을 채팅창에 입력만 하세요.\nIBK AI가 친절하게 도와드립니다.",
          image: const Center(
            child: Icon(Icons.rocket_launch, size: 100, color: Colors.orange),
          ),
          decoration: const PageDecoration(
            titleTextStyle: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ),
      ],

      showSkipButton: true,
      skip: const Text("건너뛰기", style: TextStyle(fontWeight: FontWeight.w600)),
      next: const Icon(Icons.arrow_forward),
      done: const Text("시작하기", style: TextStyle(fontWeight: FontWeight.w700)),

      // [시작하기] 버튼 클릭 시 채팅 화면으로 이동 (화면 교체)
      onDone: () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ChatPage()),
        );
      },
    );
  }
}


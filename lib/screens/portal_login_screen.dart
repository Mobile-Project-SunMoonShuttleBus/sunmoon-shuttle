import 'package:flutter/material.dart';
import 'package:sunmoon_shuttle/features/portal/screens/portal_timetable_webview.dart';

/// 학기 시간표 화면 혹은 포털 연동용 진입 화면
/// - 버튼 눌러서 WebView(PortalTimetableWebViewScreen)로 이동
/// - 로그인 성공 시 WebView 에서 Navigator.pop(true) 를 보내고
///   여기서 받아서 "포털 로그인 성공" 메시지 + 시간표 API 호출
class PortalLoginScreen extends StatefulWidget {
  const PortalLoginScreen({super.key});

  @override
  State<PortalLoginScreen> createState() => _PortalLoginScreenState();
}

class _PortalLoginScreenState extends State<PortalLoginScreen> {
  bool _isLoadingTimetable = false;
  Map<String, dynamic>? _timetable; // TODO: 실제 API 응답 타입에 맞게 변경

  Future<void> _openPortalWebView() async {
    // WebView 화면으로 이동, 로그인 성공 시 true 반환 기대
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const PortalTimetableWebViewScreen(),
      ),
    );

    if (result == true) {
      // 포털 로그인 성공
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('포털 로그인 성공! 시간표를 불러옵니다.')),
      );

      // 여기서 시간표 크롤링 API 호출
      await _fetchTimetableFromServer();
    } else {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('포털 로그인에 실패했거나 취소되었습니다.')),
      );
    }
  }

  Future<void> _fetchTimetableFromServer() async {
    setState(() {
      _isLoadingTimetable = true;
    });

    try {
      // TODO: 실제 API 호출로 교체
      // 여기서는 네가 예시로 준 JSON 구조를 흉내낸 더미 데이터 사용
      await Future.delayed(const Duration(seconds: 1));

      setState(() {
        _timetable = {
          "success": true,
          "count": 17,
          "crawlingStatus": "completed",
          "statusMessage": "시간표를 불러오는 중입니다. 잠시만 기다려주세요.",
          "lastCrawledAt": "2025-11-23T09:30:00.000Z",
          "timetable": {
            "월": [
              {
                "subjectName": "모바일프로그래밍 11반",
                "startTime": "9:30",
                "endTime": "10:20",
                "location": "인문 410",
                "professor": "이정빈"
              },
              {
                "subjectName": "모바일프로그래밍 11반",
                "startTime": "10:30",
                "endTime": "11:20",
                "location": "인문 410",
                "professor": "이정빈"
              }
            ],
            "화": [
              {
                "subjectName": "웹프레임워크(백엔드) 11반",
                "startTime": "12:30",
                "endTime": "13:20",
                "location": "인문 410",
                "professor": "이정빈"
              }
            ]
          }
        };
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingTimetable = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final timetable = _timetable?['timetable'] as Map<String, dynamic>?;

    return Scaffold(
      appBar: AppBar(
        title: const Text('학기 시간표'),
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _openPortalWebView,
            child: const Text('포털에서 학기 시간표 가져오기'),
          ),
          const SizedBox(height: 16),
          if (_isLoadingTimetable)
            const CircularProgressIndicator()
          else if (timetable == null)
            const Text('아직 불러온 시간표가 없습니다.')
          else
            Expanded(
              child: ListView(
                children: [
                  for (final day in ['월', '화', '수', '목', '금'])
                    if (timetable[day] != null)
                      _buildDayCard(day, timetable[day] as List),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDayCard(String day, List list) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            title: Text(
              day,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          for (final item in list)
            ListTile(
              title: Text(item['subjectName'] as String),
              subtitle: Text(
                '${item['startTime']} ~ ${item['endTime']} | '
                '${item['location']} | ${item['professor']}',
              ),
            ),
        ],
      ),
    );
  }
}

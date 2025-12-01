import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../api/timetable_api.dart';
import '../models/timetable_models.dart';
import '../repositories/auth_repository.dart';
import 'portal_timetable_webview.dart';

/// 학기 시간표 화면 (1번 코드 원본 UI/기능)
/// - 서버에 저장된 시간표가 있으면 보여줌 (색상 입혀서)
/// - 없으면 '포털 연동' 버튼 표시
class PortalLoginScreen extends StatefulWidget {
  const PortalLoginScreen({super.key});

  @override
  State<PortalLoginScreen> createState() => _PortalLoginScreenState();
}

class _PortalLoginScreenState extends State<PortalLoginScreen> {
  bool _isLoadingTimetable = false;
  TimetableResponse? _timetableData;

  // 시간표 색상 팔레트 (파스텔톤)
  final List<Color> _subjectColors = [
    const Color(0xFFCCE5FF), const Color(0xFFE7F3FF), const Color(0xFFE0F7FA),
    const Color(0xFFF1F8E9), const Color(0xFFFFF3E0), const Color(0xFFFFEBEE),
    const Color(0xFFEDE7F6),
  ];
  final Map<String, Color> _subjectColorMap = {};

  // 시간표 그리드 설정 (9시 ~ 19시)
  static const List<String> _orderedDays = ['월', '화', '수', '목', '금'];
  static const double _columnWidth = 65.0; // 칸 너비 조정
  static const double _cellHeight = 60.0;
  static const int _startHour = 9;
  static const int _endHour = 19; 

  @override
  void initState() {
    super.initState();
    // 화면 진입 시 서버에서 시간표 데이터 조회
    _fetchTimetableFromServer();
  }

  // 서버 API 호출
  Future<void> _fetchTimetableFromServer({bool waitForCrawling = false}) async {
    setState(() => _isLoadingTimetable = true);

    try {
      var response = await TimetableApi.I.getTimetable();

      // 크롤링 대기 로직 (1번 코드 기능)
      if (waitForCrawling && response.crawlingStatus != 'completed') {
        final completed = await _waitForCrawlingComplete(response);
        if (completed != null) response = completed;
      }

      _assignColors(response); // 과목 색상 할당
      
      if (mounted) {
        setState(() {
          _timetableData = response;
          _isLoadingTimetable = false;
        });
      }
    } catch (e) {
      if (mounted) {
        // 에러 시 스낵바 표시하지 않고 로딩만 해제 (조용히 실패)
        setState(() => _isLoadingTimetable = false);
      }
    }
  }

  // 크롤링 완료 대기 (폴링)
  Future<TimetableResponse?> _waitForCrawlingComplete(TimetableResponse initial) async {
    var latest = initial;
    final maxWait = const Duration(seconds: 35);
    final pollInterval = const Duration(seconds: 3);
    final startedAt = DateTime.now();

    while (DateTime.now().difference(startedAt) < maxWait) {
      if (latest.crawlingStatus == 'completed' && latest.timetable.isNotEmpty) {
        return latest;
      }
      await Future.delayed(pollInterval);
      try {
        latest = await TimetableApi.I.getTimetable();
      } catch (_) {}
    }
    return latest;
  }

  // 과목별 색상 지정
  void _assignColors(TimetableResponse response) {
    _subjectColorMap.clear();
    final uniqueSubjects = <String>{};

    response.timetable.forEach((day, subjects) {
      for (final subject in subjects) {
        uniqueSubjects.add(subject.subjectName);
      }
    });

    var index = 0;
    for (final subjectName in uniqueSubjects) {
      _subjectColorMap[subjectName] = _subjectColors[index % _subjectColors.length];
      index++;
    }
  }

  // 웹뷰 열기 및 로그인 처리
  Future<void> _openPortalWebView() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const PortalTimetableWebViewScreen()),
    );

    if (result == true) {
      await _handlePortalLoginSuccess();
    }
  }

  // 로그인 성공 후 계정 저장 팝업
  Future<void> _handlePortalLoginSuccess() async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('포털 로그인 성공! 계정 정보를 저장해주세요.'), duration: Duration(seconds: 2)));

    final saved = await _showPortalAccountSaveDialog();
    if (saved != true) return;

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('서버에 저장되었습니다. 시간표를 가져옵니다.'), duration: Duration(seconds: 2)));

    await _fetchTimetableFromServer(waitForCrawling: true);
  }

  // 계정 저장 다이얼로그
  Future<bool?> _showPortalAccountSaveDialog() async {
    final idController = TextEditingController();
    final pwController = TextEditingController();
    bool isSubmitting = false;

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            Future<void> submit() async {
              final schoolId = idController.text.trim();
              final password = pwController.text;

              if (schoolId.isEmpty || password.isEmpty) return;

              setStateDialog(() => isSubmitting = true);

              try {
                await AuthRepository.I.saveSchoolAccount(schoolId: schoolId, schoolPassword: password);
                if (mounted) Navigator.of(dialogContext).pop(true);
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('저장 실패: $e'), backgroundColor: Colors.red));
                setStateDialog(() => isSubmitting = false);
              }
            }

            return AlertDialog(
              title: const Text('포털 계정 저장'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('학번과 비밀번호를 입력하면\n자동으로 시간표를 가져옵니다.', style: TextStyle(fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 16),
                  TextField(controller: idController, decoration: const InputDecoration(labelText: '학번/ID', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person))),
                  const SizedBox(height: 12),
                  TextField(controller: pwController, obscureText: true, decoration: const InputDecoration(labelText: '비밀번호', border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock))),
                ],
              ),
              actions: [
                TextButton(onPressed: isSubmitting ? null : () => Navigator.of(dialogContext).pop(false), child: const Text('취소')),
                ElevatedButton(onPressed: isSubmitting ? null : submit, child: isSubmitting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('저장')),
              ],
            );
          },
        );
      },
    );
  }

  // --- UI 빌드 (시간표 그리드) ---

  double _topOffset(TimetableSubject subject) {
    final startHour = subject.startDateTime.hour;
    final startMinute = subject.startDateTime.minute;
    final relativeHour = (startHour + (startMinute / 60)) - _startHour;
    return relativeHour * _cellHeight;
  }

  double _blockHeight(TimetableSubject subject) {
    final duration = subject.durationInHours;
    return (duration <= 0 ? 1 : duration) * _cellHeight;
  }

  @override
  Widget build(BuildContext context) {
    final hasData = _timetableData != null && _timetableData!.timetable.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('학기 시간표'), centerTitle: true, elevation: 0, backgroundColor: Colors.white, foregroundColor: Colors.black),
      body: Column(
        children: [
          // 상단 컨트롤 영역
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.grey[50],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_timetableData?.lastCrawledAt != null)
                  Text('업데이트: ${_timetableData!.lastCrawledAt!.month}/${_timetableData!.lastCrawledAt!.day}', style: const TextStyle(fontSize: 12, color: Colors.grey))
                else
                  const Text('데이터 없음', style: TextStyle(fontSize: 12, color: Colors.grey)),
                
                ElevatedButton.icon(
                  onPressed: _openPortalWebView,
                  icon: const Icon(Icons.sync, size: 16),
                  label: const Text('포털 연동'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          
          // 메인 콘텐츠
          if (_isLoadingTimetable)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (!hasData)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.calendar_today_outlined, size: 60, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    const Text("연동된 시간표가 없습니다.\n'포털 연동' 버튼을 눌러주세요.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            )
          else
            Expanded(child: _buildTimetableGrid()),
        ],
      ),
    );
  }

  Widget _buildTimetableGrid() {
    final totalHeight = (_endHour - _startHour) * _cellHeight;

    return SingleChildScrollView(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. 시간 축 (왼쪽 고정)
          SizedBox(
            width: 40,
            child: Column(
              children: [
                const SizedBox(height: 40), // 요일 헤더 높이
                ...List.generate(_endHour - _startHour, (index) => SizedBox(
                  height: _cellHeight,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Text('${_startHour + index}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ),
                )),
              ],
            ),
          ),
          
          // 2. 시간표 본문 (가로 스크롤 가능)
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: _orderedDays.length * _columnWidth + 10, // 전체 너비
                child: Row(
                  children: _orderedDays.map((day) => _buildDayColumn(day, _timetableData!.timetable[day] ?? [], totalHeight)).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayColumn(String day, List<TimetableSubject> subjects, double totalHeight) {
    return Container(
      width: _columnWidth,
      margin: const EdgeInsets.only(right: 2),
      child: Column(
        children: [
          // 요일 헤더
          Container(
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(4)),
            child: Text(day, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
          ),
          const SizedBox(height: 4),
          
          // 강의 블록 영역
          Container(
            height: totalHeight,
            decoration: const BoxDecoration(
              border: Border(left: BorderSide(color: Colors.black12, width: 0.5)),
            ),
            child: Stack(
              children: [
                // 가로선 (시간 구분선)
                ...List.generate(_endHour - _startHour, (i) => Positioned(
                  top: i * _cellHeight, 
                  left: 0, right: 0, 
                  child: Container(height: 1, color: Colors.grey[100])
                )),
                
                // 실제 강의 박스
                for (final subject in subjects)
                  Positioned(
                    top: _topOffset(subject),
                    left: 1, right: 1,
                    height: _blockHeight(subject) - 2,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: _subjectColorMap[subject.subjectName] ?? Colors.blue[100],
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.black.withOpacity(0.05)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(subject.subjectName, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                          if (subject.location.isNotEmpty)
                            Text(subject.location, style: const TextStyle(fontSize: 9, color: Colors.black54), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
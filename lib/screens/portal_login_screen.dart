import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:dio/dio.dart';
import 'package:sunmoon_shuttle/api/timetable_api.dart';
import 'package:sunmoon_shuttle/features/portal/screens/portal_timetable_webview.dart';
import 'package:sunmoon_shuttle/models/timetable_models.dart';
import '../features/auth/repositories/auth_repository.dart';

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
  TimetableResponse? _timetableData;

  final List<Color> _subjectColors = [
    const Color(0xFFCCE5FF),
    const Color(0xFFE7F3FF),
    const Color(0xFFE0F7FA),
    const Color(0xFFF1F8E9),
    const Color(0xFFFFF3E0),
    const Color(0xFFFFEBEE),
    const Color(0xFFEDE7F6),
  ];
  final Map<String, Color> _subjectColorMap = {};

  static const List<String> _orderedDays = ['월', '화', '수', '목', '금'];
  static const double _columnWidth = 140;
  static const double _cellHeight = 60;
  static const int _startHour = 9;
  static const int _endHour = 19; // 9~18시까지 표시

  Future<void> _openPortalWebView() async {
    // 먼저 ID/PW를 입력받음
    final accountInfo = await _showPortalAccountInputDialog();
    
    if (accountInfo == null) {
      // 사용자가 취소한 경우
      return;
    }

    // WebView 화면으로 이동하면서 ID/PW 전달, 로그인 성공 시 true 반환 기대
    final result = await Navigator.push<Map<String, dynamic>?>(
      context,
      MaterialPageRoute(
        builder: (_) => PortalTimetableWebViewScreen(
          schoolId: accountInfo['schoolId'] as String,
          schoolPassword: accountInfo['schoolPassword'] as String,
        ),
      ),
    );

    if (result != null && result['success'] == true) {
      // 로그인 성공 시 입력받은 정보를 서버에 저장
      await _handlePortalLoginSuccess(
        schoolId: accountInfo['schoolId'] as String,
        schoolPassword: accountInfo['schoolPassword'] as String,
      );
    } else {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('포털 로그인에 실패했거나 취소되었습니다.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handlePortalLoginSuccess({
    required String schoolId,
    required String schoolPassword,
  }) async {
    if (!mounted) return;

    // 로딩 표시
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // 입력받은 정보를 서버에 저장
      await AuthRepository.I.saveSchoolAccount(
        schoolId: schoolId,
        schoolPassword: schoolPassword,
      );

      if (kDebugMode) {
        print('✅ 포털 계정 저장 성공');
      }

      if (!mounted) return;
      Navigator.of(context).pop(); // 로딩 다이얼로그 닫기

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('계정 정보가 서버에 저장되었습니다. 자동 크롤링이 실행됩니다. (약 10~30초)'),
          duration: Duration(seconds: 4),
          backgroundColor: Colors.green,
        ),
      );

      await _fetchTimetableFromServer(waitForCrawling: true);
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // 로딩 다이얼로그 닫기

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('계정 정보 저장 실패: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _fetchTimetableFromServer({bool waitForCrawling = false}) async {
    setState(() {
      _isLoadingTimetable = true;
    });

    try {
      var response = await TimetableApi.I.getTimetable();

      if (kDebugMode) {
        print('📋 초기 시간표 조회: status=${response.crawlingStatus}, count=${response.count}');
      }

      // 크롤링 대기가 필요하고 아직 완료되지 않은 경우
      // 하지만 데이터가 이미 있으면 (count > 0) 바로 표시
      if (waitForCrawling && response.crawlingStatus != 'completed') {
        // 데이터가 이미 있으면 바로 표시
        if (response.count > 0) {
          if (kDebugMode) {
            print('✅ 데이터가 이미 있음 (count: ${response.count}). 바로 표시합니다.');
          }
        } else {
          // 데이터가 없으면 크롤링 완료 대기
          if (kDebugMode) {
            print('⏳ 크롤링 완료 대기 시작...');
          }
          final completed = await _waitForCrawlingComplete(response);
          if (completed != null) {
            response = completed;
            if (kDebugMode) {
              print('✅ 크롤링 완료 후 최신 데이터: count=${response.count}');
            }
          } else {
            // 대기 시간 초과 시 최신 데이터 다시 가져오기
            response = await TimetableApi.I.getTimetable();
            if (kDebugMode) {
              print('📋 대기 후 최신 데이터: status=${response.crawlingStatus}, count=${response.count}');
            }
          }
        }
      }

      _assignColors(response);
      if (mounted) {
        setState(() {
          _timetableData = response;
          _isLoadingTimetable = false;
        });
        
        if (kDebugMode) {
          print('✅ 시간표 UI 업데이트 완료: ${response.count}개 과목');
        }
      }
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingTimetable = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('시간표를 불러오지 못했습니다: ${e.message}'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingTimetable = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('시간표를 불러오지 못했습니다: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<TimetableResponse?> _waitForCrawlingComplete(
    TimetableResponse initial,
  ) async {
    var latest = initial;
    final maxWait = Duration(seconds: 90); // 40초 → 90초로 증가 (크롤링이 느릴 수 있음)
    final pollInterval = Duration(seconds: 3);
    final startedAt = DateTime.now();

    if (kDebugMode) {
      print('⏳ 크롤링 완료 대기 시작... (최대 ${maxWait.inSeconds}초)');
    }

    while (DateTime.now().difference(startedAt) < maxWait) {
      await Future.delayed(pollInterval);
      
      try {
        latest = await TimetableApi.I.getTimetable();
        
        if (kDebugMode) {
          print('📊 크롤링 상태 확인: ${latest.crawlingStatus}, count: ${latest.count}');
        }
        
        // 크롤링이 완료되었거나 데이터가 있으면 반환
        if (latest.crawlingStatus == 'completed' || latest.count > 0) {
          if (kDebugMode) {
            print('✅ 크롤링 완료 또는 데이터 있음: status=${latest.crawlingStatus}, count=${latest.count}개 과목');
          }
          return latest;
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ 크롤링 상태 확인 중 에러: $e');
        }
        // 에러가 발생해도 계속 시도
      }
    }
    
    if (kDebugMode) {
      print('⚠️ 크롤링 대기 시간 초과 (${maxWait.inSeconds}초)');
      print('최종 상태: ${latest.crawlingStatus}, count: ${latest.count}');
    }
    
    // 시간 초과되어도 최신 데이터 반환
    return latest;
  }

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
      _subjectColorMap[subjectName] =
          _subjectColors[index % _subjectColors.length];
      index++;
    }
  }

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

  List<int> get _timeSlots =>
      List.generate(_endHour - _startHour, (index) => _startHour + index);

  @override
  Widget build(BuildContext context) {
    // 데이터가 있고 count > 0이면 표시 (crawling 상태여도 데이터가 있으면 표시)
    final hasData = _timetableData != null && 
                    _timetableData!.count > 0 && 
                    _timetableData!.timetable.isNotEmpty;

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
          if (_timetableData?.lastCrawledAt != null) ...[
            const SizedBox(height: 8),
            Text(
              '마지막 업데이트: '
              '${_timetableData!.lastCrawledAt!.toLocal()}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
          const SizedBox(height: 16),
          if (_isLoadingTimetable)
            const CircularProgressIndicator()
          else if (!hasData)
            const Expanded(
              child: Center(
                child: Text('아직 불러온 시간표가 없습니다.'),
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
      scrollDirection: Axis.horizontal,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 60,
                  child: Column(
                    children: [
                      const SizedBox(height: 48),
                      ..._timeSlots.map(
                        (hour) => SizedBox(
                          height: _cellHeight,
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: Text('$hour:00',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                ..._orderedDays.map(
                  (day) => _buildDayColumn(
                    day,
                    _timetableData!.timetable[day] ?? [],
                    totalHeight,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayColumn(
    String day,
    List<TimetableSubject> subjects,
    double totalHeight,
  ) {
    return Container(
      width: _columnWidth,
      margin: const EdgeInsets.only(right: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFEBF3FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                day,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1D3A6B),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: totalHeight,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  // 시간대 구분선 - CustomPaint로 정확한 높이 계산
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _TimeSlotPainter(
                        cellHeight: _cellHeight,
                        numSlots: _endHour - _startHour,
                      ),
                    ),
                  ),
                  // 과목 블록들
                  for (final subject in subjects)
                    Positioned(
                      top: _topOffset(subject),
                      left: 4,
                      right: 4,
                      height: (_blockHeight(subject) - 4).clamp(0.0, totalHeight - _topOffset(subject) - 4),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: _subjectColorMap[subject.subjectName] ??
                              Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.black.withOpacity(0.05),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                subject.subjectName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${subject.startTime} ~ ${subject.endTime}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              '${subject.location} · ${subject.professor}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.black54,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 먼저 ID/PW를 입력받는 다이얼로그
  Future<Map<String, String>?> _showPortalAccountInputDialog() async {
    final idController = TextEditingController();
    final pwController = TextEditingController();

    return showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('포털 로그인'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '포털 계정 정보를 입력해주세요. 로그인 후 서버에 저장됩니다.',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: idController,
                  keyboardType: TextInputType.text,
                  decoration: const InputDecoration(
                    labelText: '학번 또는 포털 ID',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: pwController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: '포털 비밀번호',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(null),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () {
                final schoolId = idController.text.trim();
                final password = pwController.text;

                if (schoolId.isEmpty || password.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('학번과 비밀번호를 모두 입력해주세요.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                Navigator.of(dialogContext).pop({
                  'schoolId': schoolId,
                  'schoolPassword': password,
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1890FF),
                foregroundColor: Colors.white,
              ),
              child: const Text('로그인'),
            ),
          ],
        );
      },
    );
  }
}

/// 시간대 구분선을 그리는 CustomPainter
class _TimeSlotPainter extends CustomPainter {
  final double cellHeight;
  final int numSlots;

  _TimeSlotPainter({
    required this.cellHeight,
    required this.numSlots,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade200
      ..strokeWidth = 1.0;

    // 각 시간대마다 하단에 선 그리기 (마지막은 제외)
    for (int i = 0; i < numSlots - 1; i++) {
      final y = (i + 1) * cellHeight;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

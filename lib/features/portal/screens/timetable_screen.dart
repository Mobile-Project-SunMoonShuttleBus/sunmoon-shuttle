/// 시간표 화면
/// API에서 시간표 데이터를 가져와 그리드 형태로 표시
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:provider/provider.dart';
import '../../../api/timetable_api.dart';
import '../../../models/timetable_models.dart';
import '../../../features/settings/providers/settings_provider.dart';
import '../../../core/localization/app_localizations.dart';
import 'package:dio/dio.dart';
import '../../../../screens/portal_login_screen.dart';

class TimetableScreen extends StatefulWidget {
  final bool showLoginSuccess;
  
  const TimetableScreen({super.key, this.showLoginSuccess = false});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  TimetableResponse? _timetableData;
  bool _isLoading = true;
  String? _errorMessage;
  final List<Color> _subjectColors = [
    Colors.blue.shade300,
    Colors.green.shade300,
    Colors.orange.shade300,
    Colors.purple.shade300,
    Colors.pink.shade300,
    Colors.teal.shade300,
    Colors.amber.shade300,
    Colors.indigo.shade300,
    Colors.red.shade300,
    Colors.cyan.shade300,
  ];
  final Map<String, Color> _subjectColorMap = {};

  @override
  void initState() {
    super.initState();
    _loadTimetable();
    
    // 로그인 성공 메시지 표시
    if (widget.showLoginSuccess) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('포털 로그인에 성공했습니다.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
      });
    }
  }

  Future<void> _loadTimetable() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await TimetableApi.I.getTimetable();
      
      // 크롤링이 진행 중이면 완료될 때까지 대기
      if (response.crawlingStatus == 'crawling') {
        // 크롤링 완료까지 폴링 (최대 30초)
        await _waitForCrawlingComplete();
        // 다시 시간표 로드
        final updatedResponse = await TimetableApi.I.getTimetable();
        _assignColors(updatedResponse);
        setState(() {
          _timetableData = updatedResponse;
          _isLoading = false;
        });
      } else {
        // 크롤링 완료 또는 이미 완료된 상태
        _assignColors(response);
        setState(() {
          _timetableData = response;
          _isLoading = false;
        });
      }

    } on DioException catch (e) {
      if (kDebugMode) {
        print('❌ 시간표 로드 실패: $e');
        print('응답 상태 코드: ${e.response?.statusCode}');
        print('응답 데이터: ${e.response?.data}');
      }
      
      // 404 또는 포털 계정 정보가 없는 경우 로그인 화면으로 이동
      final statusCode = e.response?.statusCode;
      if (statusCode == 404 || statusCode == 400 || statusCode == 401) {
        if (mounted) {
          // 포털 로그인 화면으로 이동
          final result = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const PortalLoginScreen(),
            ),
          );
          
          // 로그인 성공 후 시간표 다시 로드
          if (result == true && mounted) {
            _loadTimetable();
          } else if (mounted) {
            // 로그인 실패 또는 취소 시 이전 화면으로 돌아가기
            Navigator.of(context).pop();
          }
        }
        return;
      }
      
      setState(() {
        _errorMessage = e.response?.data?['message']?.toString() ?? 
                       '시간표를 불러올 수 없습니다. 포털 계정 정보를 확인해주세요.';
        _isLoading = false;
      });
    } catch (e) {
      if (kDebugMode) {
        print('❌ 시간표 로드 실패: $e');
      }
      
      // 포털 계정 정보가 없는 것으로 간주하고 로그인 화면으로 이동
      if (mounted) {
        final result = await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const PortalLoginScreen(),
          ),
        );
        
        // 로그인 성공 후 시간표 다시 로드
        if (result == true && mounted) {
          _loadTimetable();
        } else if (mounted) {
          // 로그인 실패 또는 취소 시 이전 화면으로 돌아가기
          Navigator.of(context).pop();
        }
      }
    }
  }

  /// 크롤링 완료까지 대기
  Future<void> _waitForCrawlingComplete() async {
    const maxWaitTime = Duration(seconds: 30);
    const pollInterval = Duration(seconds: 3);
    final startTime = DateTime.now();
    
    while (DateTime.now().difference(startTime) < maxWaitTime) {
      await Future.delayed(pollInterval);
      
      try {
        final response = await TimetableApi.I.getTimetable();
        if (response.crawlingStatus == 'completed') {
          return;
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ 크롤링 상태 확인 중 에러: $e');
        }
      }
    }
    
    if (kDebugMode) {
      print('⚠️ 크롤링 대기 시간 초과 (30초)');
    }
  }

  /// 과목별 색상 할당
  void _assignColors(TimetableResponse response) {
    _subjectColorMap.clear();
    final subjects = <String>{};
    
    response.timetable.forEach((day, daySubjects) {
      for (var subject in daySubjects) {
        subjects.add(subject.subjectName);
      }
    });

    int colorIndex = 0;
    for (var subjectName in subjects) {
      if (!_subjectColorMap.containsKey(subjectName)) {
        _subjectColorMap[subjectName] = _subjectColors[colorIndex % _subjectColors.length];
        colorIndex++;
      }
    }
  }

  /// 시간대 목록 (9시 ~ 18시)
  List<int> get _timeSlots => List.generate(10, (index) => 9 + index); // 9~18시

  /// 요일 목록
  List<String> get _days => ['월', '화', '수', '목', '금'];

  /// 특정 요일, 시간대의 과목 찾기
  List<TimetableSubject> _getSubjectsAt(String day, int hour) {
    if (_timetableData == null) return [];
    
    final daySubjects = _timetableData!.timetable[day] ?? [];
    return daySubjects.where((subject) {
      final startHour = subject.startDateTime.hour;
      final startMinute = subject.startDateTime.minute;
      final endHour = subject.endDateTime.hour;
      final endMinute = subject.endDateTime.minute;
      
      // 시간대 시작 시점 (hour:00)
      final slotStart = DateTime(2024, 1, 1, hour, 0);
      // 시간대 종료 시점 (hour+1:00)
      final slotEnd = DateTime(2024, 1, 1, hour + 1, 0);
      // 과목 시작 시점
      final subjectStart = DateTime(2024, 1, 1, startHour, startMinute);
      // 과목 종료 시점
      final subjectEnd = DateTime(2024, 1, 1, endHour, endMinute);
      
      // 시간대와 과목이 겹치는지 확인
      return subjectStart.isBefore(slotEnd) && subjectEnd.isAfter(slotStart);
    }).toList();
  }

  /// 특정 요일의 모든 과목 가져오기
  List<TimetableSubject> _getAllSubjectsForDay(String day) {
    if (_timetableData == null) return [];
    return _timetableData!.timetable[day] ?? [];
  }

  /// 과목이 특정 시간대 셀에서 시작하는지 확인
  bool _isSubjectStartingAt(TimetableSubject subject, int hour) {
    final startHour = subject.startDateTime.hour;
    final startMinute = subject.startDateTime.minute;
    
    // 시간대 시작 시점 (hour:00)
    final slotStart = DateTime(2024, 1, 1, hour, 0);
    // 과목 시작 시점
    final subjectStart = DateTime(2024, 1, 1, startHour, startMinute);
    
    // 과목이 이 시간대에 시작하는지 확인 (5분 오차 허용)
    return subjectStart.difference(slotStart).inMinutes.abs() < 5 ||
           (subjectStart.isAfter(slotStart) && subjectStart.isBefore(slotStart.add(const Duration(hours: 1))));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('시간표'),
        backgroundColor: const Color(0xFF1890FF),
        foregroundColor: Colors.white,
        actions: [
          // 포털 계정 연동 버튼
          IconButton(
            icon: const Icon(Icons.link),
            onPressed: () async {
              // 포털 로그인 화면으로 이동
              final result = await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const PortalLoginScreen(),
                ),
              );
              
              // 로그인 성공 후 시간표 다시 로드
              if (result == true && mounted) {
                _loadTimetable();
              }
            },
            tooltip: '포털 연동',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTimetable,
            tooltip: '새로고침',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                '시간표를 불러올 수 없습니다',
                style: TextStyle(fontSize: 18, color: Colors.grey[700]),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '포털 계정 정보가 필요합니다.\n포털 로그인을 통해 계정 정보를 저장해주세요.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () async {
                  // 포털 로그인 화면으로 이동
                  final result = await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const PortalLoginScreen(),
                    ),
                  );
                  
                  // 로그인 성공 후 시간표 다시 로드
                  if (result == true && mounted) {
                    _loadTimetable();
                  }
                },
                icon: const Icon(Icons.login),
                label: const Text('포털 로그인'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1890FF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _loadTimetable,
                icon: const Icon(Icons.refresh),
                label: const Text('다시 시도'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_timetableData == null || _timetableData!.timetable.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.calendar_today, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                '시간표 데이터가 없습니다',
                style: TextStyle(fontSize: 18, color: Colors.grey[700]),
              ),
              const SizedBox(height: 8),
              if (_timetableData?.crawlingStatus == 'crawling')
                Text(
                  _timetableData?.statusMessage ?? '시간표를 불러오는 중입니다.',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
              if (_timetableData?.crawlingStatus != 'crawling') ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.green.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '포털 계정 정보가 저장되지 않았습니다.\n계정 정보를 저장하면 시간표가 자동으로 크롤링됩니다.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.green.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () async {
                  // 포털 로그인 화면으로 이동
                  final result = await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const PortalLoginScreen(),
                    ),
                  );
                  
                  // 로그인 성공 후 시간표 다시 로드
                  if (result == true && mounted) {
                    _loadTimetable();
                  }
                },
                icon: const Icon(Icons.login, size: 24),
                label: const Text(
                  '포털 로그인',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1890FF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _loadTimetable,
                icon: const Icon(Icons.refresh),
                label: const Text('새로고침'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: _buildTimetableGrid(),
      ),
    );
  }

  Widget _buildTimetableGrid() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 크롤링 상태 표시
          if (_timetableData?.crawlingStatus != null)
            _buildCrawlingStatus(),
          // 시간표 데이터가 비어있을 때 포털 로그인 안내
          if (_timetableData != null && _timetableData!.timetable.isEmpty && _timetableData!.crawlingStatus != 'crawling') ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '포털 계정 정보가 저장되지 않았습니다.\n계정 정보를 저장하면 시간표가 자동으로 크롤링됩니다.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        // 포털 로그인 화면으로 이동
                        final result = await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const PortalLoginScreen(),
                          ),
                        );
                        
                        // 로그인 성공 후 시간표 다시 로드
                        if (result == true && mounted) {
                          _loadTimetable();
                        }
                      },
                      icon: const Icon(Icons.login, size: 20),
                      label: const Text(
                        '포털 로그인',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1890FF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          // 시간표 그리드
          Expanded(child: _buildGrid()),
        ],
      ),
    );
  }

  Widget _buildCrawlingStatus() {
    final status = _timetableData!.crawlingStatus;
    final isCrawling = status == 'crawling';
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isCrawling ? Colors.blue.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCrawling ? Colors.blue.shade200 : Colors.green.shade200,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isCrawling)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(Icons.check_circle, size: 16, color: Colors.green.shade700),
          const SizedBox(width: 8),
          Text(
            _timetableData!.statusMessage,
            style: TextStyle(
              fontSize: 12,
              color: isCrawling ? Colors.blue.shade900 : Colors.green.shade900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    return Table(
      border: TableBorder.all(color: Colors.grey.shade300, width: 1),
      columnWidths: {
        0: const FixedColumnWidth(60), // 시간 열
        for (int i = 1; i <= _days.length; i++)
          i: const FlexColumnWidth(1), // 요일 열
      },
      children: [
        // 헤더 행
        _buildHeaderRow(),
        // 시간대별 행
        for (int hour in _timeSlots) _buildTimeRow(hour),
      ],
    );
  }

  TableRow _buildHeaderRow() {
    return TableRow(
      decoration: BoxDecoration(color: Colors.grey.shade200),
      children: [
        const Padding(
          padding: EdgeInsets.all(8.0),
          child: Center(child: Text('시간', style: TextStyle(fontWeight: FontWeight.bold))),
        ),
        for (String day in _days)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Center(
              child: Text(day, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
      ],
    );
  }

  TableRow _buildTimeRow(int hour) {
    return TableRow(
      children: [
        // 시간 셀
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            border: Border(right: BorderSide(color: Colors.grey.shade300)),
          ),
          child: Center(
            child: Text(
              '$hour:00',
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
          ),
        ),
        // 요일별 셀
        for (String day in _days) _buildDayCell(day, hour),
      ],
    );
  }

  Widget _buildDayCell(String day, int hour) {
    final subjects = _getSubjectsAt(day, hour);
    
    // 이 시간대에 시작하는 과목 찾기
    final startingSubjects = subjects.where((s) => _isSubjectStartingAt(s, hour)).toList();
    
    if (startingSubjects.isEmpty && subjects.isEmpty) {
      return Container(
        height: 60,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
        ),
      );
    }

    // 시작하는 과목이 있으면 첫 번째 과목 표시, 없으면 첫 번째 과목 표시 (이미 시작된 과목)
    final subject = startingSubjects.isNotEmpty ? startingSubjects.first : subjects.first;
    final color = _subjectColorMap[subject.subjectName] ?? Colors.grey.shade300;
    
    // 과목의 지속 시간 계산 (시간 단위)
    final duration = subject.durationInHours;
    final cellHeight = (60 * duration).clamp(60.0, 300.0); // 최소 60, 최대 300

    return Container(
      height: 60, // 기본 높이 (실제로는 rowspan이 필요하지만 Table에서는 제한적)
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            subject.subjectName,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            '${subject.startTime} - ${subject.endTime}',
            style: TextStyle(fontSize: 8, color: Colors.grey[700]),
          ),
          const SizedBox(height: 1),
          Text(
            subject.professor,
            style: TextStyle(fontSize: 9, color: Colors.grey[700]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            subject.location,
            style: TextStyle(fontSize: 9, color: Colors.grey[700]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}


import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import '../api/timetable_api.dart';
import '../models/timetable_models.dart';
import '../repositories/auth_repository.dart';
import '../providers/settings_provider.dart';
import '../core/localization/app_localizations.dart';
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
  // 요일은 로컬라이제이션을 위해 함수로 처리
  List<String> _getOrderedDays(bool isKorean) {
    return isKorean ? ['월', '화', '수', '목', '금'] : ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
  }
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
      if (kDebugMode) {
        print('📋 시간표 조회 시작...');
      }

      var response = await TimetableApi.I.getTimetable();

      if (kDebugMode) {
        print('📋 시간표 응답 받음:');
        print('  - success: ${response.success}');
        print('  - count: ${response.count}');
        print('  - crawlingStatus: ${response.crawlingStatus}');
        print('  - timetable keys: ${response.timetable.keys.toList()}');
      }

      // 크롤링 대기가 필요하고 아직 완료되지 않은 경우
      // 하지만 데이터가 이미 있으면 (count > 0) 바로 표시
      if (waitForCrawling && response.crawlingStatus != 'completed') {
        // 월~금 중 하나라도 데이터가 있으면 바로 표시
        final hasExistingData = _orderedDays.any((day) => 
          response.timetable[day] != null && response.timetable[day]!.isNotEmpty
        );
        
        if (hasExistingData || response.count > 0) {
          if (kDebugMode) {
            print('📋 데이터가 이미 있음 (count: ${response.count}), 바로 표시');
          }
        } else {
          // 데이터가 없으면 크롤링 완료 대기
          if (kDebugMode) {
            print('📋 크롤링 완료 대기 중...');
          }
          
          // 사용자에게 크롤링 중임을 알림
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('시간표를 가져오는 중입니다. 잠시만 기다려주세요...'),
                duration: Duration(seconds: 5),
                backgroundColor: Colors.blue,
              ),
            );
          }
          
          final completed = await _waitForCrawlingComplete(response);
          if (completed != null) {
            response = completed;
            
            // 크롤링 완료 후 데이터 확인
            final hasDataAfterWait = _orderedDays.any((day) => 
              response.timetable[day] != null && response.timetable[day]!.isNotEmpty
            );
            
            if (kDebugMode) {
              print('📋 크롤링 완료, 데이터 받음 (count: ${response.count}, hasData: $hasDataAfterWait)');
            }
            
            if (!hasDataAfterWait && response.count == 0) {
              // 크롤링이 완료되었지만 데이터가 없는 경우
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('시간표 데이터를 가져오지 못했습니다. 잠시 후 다시 시도해주세요.'),
                    duration: Duration(seconds: 4),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            }
          } else {
            // 대기 시간 초과 시 최신 데이터 다시 가져오기
            if (kDebugMode) {
              print('📋 크롤링 대기 시간 초과, 최신 데이터 다시 조회');
            }
            response = await TimetableApi.I.getTimetable();
            
            // 여전히 데이터가 없으면 알림
            final stillNoData = !_orderedDays.any((day) => 
              response.timetable[day] != null && response.timetable[day]!.isNotEmpty
            ) && response.count == 0;
            
            if (stillNoData && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('시간표를 가져오는데 시간이 오래 걸리고 있습니다. 잠시 후 새로고침을 해주세요.'),
                  duration: Duration(seconds: 5),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          }
        }
      }

      _assignColors(response); // 과목 색상 할당
      
      if (mounted) {
        setState(() {
          _timetableData = response;
          _isLoadingTimetable = false;
        });

        // 크롤링 상태에 따른 사용자 알림
        if (response.crawlingStatus == 'crawling' && response.count == 0) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('시간표를 가져오는 중입니다. 잠시만 기다려주세요...'),
                duration: Duration(seconds: 3),
                backgroundColor: Colors.blue,
              ),
            );
          }
        } else if (response.count == 0 && response.crawlingStatus == 'completed') {
          if (kDebugMode) {
            print('⚠️ 시간표 데이터가 없습니다. 포털 연동이 필요합니다.');
          }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('시간표 데이터가 없습니다. 포털 연동을 해주세요.'),
                duration: Duration(seconds: 3),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      }
    } on DioException catch (e) {
      if (kDebugMode) {
        print('❌ 시간표 조회 DioException: ${e.message}');
        if (e.response != null) {
          print('  - 상태 코드: ${e.response?.statusCode}');
          print('  - 응답 데이터: ${e.response?.data}');
        }
      }

      if (mounted) {
        setState(() => _isLoadingTimetable = false);
        
        String errorMessage = '시간표를 불러오는데 실패했습니다.';
        if (e.response?.statusCode == 401) {
          errorMessage = '로그인이 필요합니다.';
        } else if (e.response?.statusCode == 404) {
          errorMessage = '시간표 데이터가 없습니다. 포털 연동을 해주세요.';
        } else if (e.type == DioExceptionType.connectionTimeout ||
                   e.type == DioExceptionType.receiveTimeout) {
          errorMessage = '서버 연결 시간이 초과되었습니다.';
        } else if (e.response?.data != null) {
          final errorData = e.response!.data;
          if (errorData is Map && errorData.containsKey('message')) {
            errorMessage = errorData['message'].toString();
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ 시간표 조회 예외: $e');
        print('스택 트레이스: $stackTrace');
      }

      if (mounted) {
        setState(() => _isLoadingTimetable = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('시간표를 불러오는데 실패했습니다: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // 크롤링 완료 대기 (폴링)
  Future<TimetableResponse?> _waitForCrawlingComplete(TimetableResponse initial) async {
    var latest = initial;
    final maxWait = const Duration(seconds: 90); // 크롤링 시간을 90초로 증가
    final pollInterval = const Duration(seconds: 3);
    final startedAt = DateTime.now();
    int pollCount = 0;

    while (DateTime.now().difference(startedAt) < maxWait) {
      // 크롤링 완료 확인: completed 상태이고 실제 데이터가 있는지 확인
      if (latest.crawlingStatus == 'completed') {
        // 데이터가 실제로 있는지 확인 (월~금 중 하나라도 과목이 있으면 완료)
        final hasData = _orderedDays.any((day) => 
          latest.timetable[day] != null && latest.timetable[day]!.isNotEmpty
        );
        
        if (hasData || latest.count > 0) {
          if (kDebugMode) {
            print('📋 크롤링 완료 확인 (${pollCount}번째 폴링, count: ${latest.count})');
          }
          return latest;
        }
      }
      
      await Future.delayed(pollInterval);
      pollCount++;
      
      try {
        latest = await TimetableApi.I.getTimetable();
        
        if (kDebugMode && pollCount % 5 == 0) {
          print('📋 크롤링 상태 확인 (${pollCount}번째): ${latest.crawlingStatus}, count: ${latest.count}');
        }
        
        // 크롤링이 완료되었고 데이터가 있으면 반환
        if (latest.crawlingStatus == 'completed') {
          final hasData = _orderedDays.any((day) => 
            latest.timetable[day] != null && latest.timetable[day]!.isNotEmpty
          );
          
          if (hasData || latest.count > 0) {
            if (kDebugMode) {
              print('📋 크롤링 완료 및 데이터 확인됨 (count: ${latest.count})');
            }
            return latest;
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ 크롤링 상태 확인 중 에러 (계속 시도): $e');
        }
        // 에러가 발생해도 계속 시도
      }
    }
    
    if (kDebugMode) {
      print('⚠️ 크롤링 대기 시간 초과 (${maxWait.inSeconds}초)');
      print('  - 최종 상태: ${latest.crawlingStatus}');
      print('  - 최종 count: ${latest.count}');
    }
    return latest;
  }

  // 과목별 색상 지정 (월~금만 처리)
  void _assignColors(TimetableResponse response) {
    _subjectColorMap.clear();
    final uniqueSubjects = <String>{};

    // 월~금만 처리 (토, 일 제외)
    for (final day in _orderedDays) {
      final subjects = response.timetable[day] ?? [];
      for (final subject in subjects) {
        uniqueSubjects.add(subject.subjectName);
      }
    }

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
    // 데이터가 있고 실제로 과목이 있는지 확인 (월~금만 체크)
    bool hasData = false;
    if (_timetableData != null) {
      // 월~금 중 하나라도 과목이 있으면 데이터가 있는 것으로 간주
      hasData = _orderedDays.any((day) => 
        _timetableData!.timetable[day] != null && 
        _timetableData!.timetable[day]!.isNotEmpty
      ) || _timetableData!.count > 0;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('학기 시간표'), 
        centerTitle: true, 
        elevation: 0, 
        backgroundColor: Colors.white, 
        foregroundColor: Colors.black,
        actions: [
          // 새로고침 버튼 추가
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _fetchTimetableFromServer();
            },
            tooltip: '새로고침',
          ),
        ],
      ),
      body: Column(
        children: [
          // 상단 컨트롤 영역
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.grey[50],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_timetableData != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_timetableData!.lastCrawledAt != null)
                        Text(
                          '업데이트: ${_timetableData!.lastCrawledAt!.month}/${_timetableData!.lastCrawledAt!.day}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        )
                      else if (_timetableData!.crawlingStatus == 'crawling')
                        const Text(
                          '크롤링 중...',
                          style: TextStyle(fontSize: 12, color: Colors.blue),
                        )
                      else
                        const Text('데이터 없음', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      if (_timetableData!.crawlingStatus == 'crawling')
                        const Text(
                          '시간표를 가져오는 중입니다',
                          style: TextStyle(fontSize: 10, color: Colors.blue),
                        )
                      else if (_timetableData!.count > 0)
                        Text(
                          '과목 ${_timetableData!.count}개',
                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                    ],
                  )
                else
                  const Text('로딩 중...', style: TextStyle(fontSize: 12, color: Colors.grey)),
                
                ElevatedButton.icon(
                  onPressed: _isLoadingTimetable ? null : _openPortalWebView,
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
                    Icon(
                      _timetableData?.crawlingStatus == 'crawling' 
                        ? Icons.hourglass_empty 
                        : Icons.calendar_today_outlined, 
                      size: 60, 
                      color: _timetableData?.crawlingStatus == 'crawling' 
                        ? Colors.blue[300] 
                        : Colors.grey[300]
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _timetableData?.crawlingStatus == 'crawling'
                        ? "시간표를 가져오는 중입니다.\n잠시만 기다려주세요..."
                        : "연동된 시간표가 없습니다.\n'포털 연동' 버튼을 눌러주세요.",
                      textAlign: TextAlign.center, 
                      style: TextStyle(
                        color: _timetableData?.crawlingStatus == 'crawling' 
                          ? Colors.blue[700] 
                          : Colors.grey
                      )
                    ),
                    if (_timetableData?.crawlingStatus == 'crawling')
                      const Padding(
                        padding: EdgeInsets.only(top: 16),
                        child: SizedBox(
                          width: 30,
                          height: 30,
                          child: CircularProgressIndicator(strokeWidth: 3),
                        ),
                      ),
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
                    height: _blockHeight(subject) - 1, // 여유 공간 확보
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2), // 패딩 조정
                      decoration: BoxDecoration(
                        color: _subjectColorMap[subject.subjectName] ?? Colors.blue[100],
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.black.withOpacity(0.05)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min, // 최소 크기만 사용
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            subject.subjectName, 
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, height: 1.1), 
                            maxLines: 2, 
                            overflow: TextOverflow.ellipsis, 
                            textAlign: TextAlign.center,
                          ),
                          if (subject.location.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 1),
                              child: Text(
                                subject.location, 
                                style: const TextStyle(fontSize: 8, color: Colors.black54, height: 1.0), 
                                maxLines: 1, 
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                            ),
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
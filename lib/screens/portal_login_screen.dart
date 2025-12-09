import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import '../api/timetable_api.dart';
import '../models/timetable_models.dart';
import '../repositories/auth_repository.dart';
import '../providers/settings_provider.dart';
import '../core/localization/app_localizations.dart';

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
  // 서버 데이터는 한국어 요일 키를 사용하므로 한국어 유지
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
      if (kDebugMode) {
        print('📋 시간표 조회 시작...');
      }

      var response = await TimetableApi.I.getTimetable();

      if (kDebugMode) {
        // 월~금만 필터링 (토, 일 제외)
        final weekdayKeys = response.timetable.keys
            .where((day) => _orderedDays.contains(day))
            .toList();
        final weekdayCount = _orderedDays.fold<int>(
            0, (sum, day) => sum + (response.timetable[day]?.length ?? 0));
        
        print('📋 시간표 응답 받음:');
        print('  - success: ${response.success}');
        print('  - count: ${response.count} (전체) / $weekdayCount (월~금)');
        print('  - crawlingStatus: ${response.crawlingStatus}');
        print('  - timetable keys: $weekdayKeys (월~금만)');
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
            final settings = Provider.of<SettingsProvider>(context, listen: false);
            final l10n = AppLocalizations(settings.isKorean);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.fetchingTimetable),
                duration: const Duration(seconds: 5),
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
                final settings = Provider.of<SettingsProvider>(context, listen: false);
                final l10n = AppLocalizations(settings.isKorean);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.timetableFetchFailed),
                    duration: const Duration(seconds: 4),
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
              final settings = Provider.of<SettingsProvider>(context, listen: false);
              final l10n = AppLocalizations(settings.isKorean);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l10n.timetableFetchTimeout),
                  duration: const Duration(seconds: 5),
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
        if (mounted) {
          final settings = Provider.of<SettingsProvider>(context, listen: false);
          final l10n = AppLocalizations(settings.isKorean);
          
          if (response.crawlingStatus == 'crawling' && response.count == 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.fetchingTimetable),
                duration: const Duration(seconds: 3),
                backgroundColor: Colors.blue,
              ),
            );
          } else if (response.count == 0 && response.crawlingStatus == 'completed') {
            if (kDebugMode) {
              print('⚠️ 시간표 데이터가 없습니다. 포털 연동이 필요합니다.');
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.noTimetableData),
                duration: const Duration(seconds: 3),
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
        
        final settings = Provider.of<SettingsProvider>(context, listen: false);
        final l10n = AppLocalizations(settings.isKorean);
        
        String errorMessage = l10n.timetableLoadFailed;
        if (e.response?.statusCode == 401) {
          errorMessage = l10n.loginFailed;
        } else if (e.response?.statusCode == 404) {
          errorMessage = l10n.noTimetableData;
        } else if (e.type == DioExceptionType.connectionTimeout ||
                   e.type == DioExceptionType.receiveTimeout) {
          errorMessage = l10n.timetableFetchTimeout;
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
        final settings = Provider.of<SettingsProvider>(context, listen: false);
        final l10n = AppLocalizations(settings.isKorean);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.timetableLoadFailed}: ${e.toString()}'),
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

  // 포털 계정 저장 처리 (WebView 없이 바로 API 호출)
  Future<void> _openPortalWebView() async {
    // 아이디/패스워드 입력받기
    final credentials = await _showPortalLoginDialog();
    if (credentials == null) return; // 사용자가 취소한 경우

    final schoolId = credentials['schoolId'] as String;
    final schoolPassword = credentials['schoolPassword'] as String;

    // 입력받은 정보로 바로 API 호출하여 DB 저장
    await _handlePortalLoginSuccess(
      schoolId: schoolId,
      schoolPassword: schoolPassword,
    );
  }

  // 포털 계정 입력 다이얼로그 (아이디/패스워드 입력)
  Future<Map<String, String>?> _showPortalLoginDialog() async {
    final idController = TextEditingController();
    final pwController = TextEditingController();
    bool isSubmitting = false;

    return showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Consumer<SettingsProvider>(
          builder: (context, settings, _) {
            final l10n = AppLocalizations(settings.isKorean);
            
            return StatefulBuilder(
              builder: (context, setStateDialog) {
                Future<void> submit() async {
                  final schoolId = idController.text.trim();
                  final password = pwController.text;

                  if (schoolId.isEmpty || password.isEmpty) return;

                  setStateDialog(() => isSubmitting = true);

                  // 입력받은 정보를 반환
                  if (mounted) {
                    Navigator.of(dialogContext).pop({
                      'schoolId': schoolId,
                      'schoolPassword': password,
                    });
                  }
                }

                return AlertDialog(
                  title: Text(l10n.portalLinkTitle),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.portalAccountSaveDescription,
                        style: const TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: idController,
                        decoration: InputDecoration(
                          labelText: l10n.portalId,
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.person),
                        ),
                        autofocus: true,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: pwController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: l10n.password,
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.lock),
                        ),
                        onSubmitted: (_) => submit(),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: isSubmitting ? null : () => Navigator.of(dialogContext).pop(null),
                      child: Text(l10n.cancel),
                    ),
                    ElevatedButton(
                      onPressed: isSubmitting ? null : submit,
                      child: isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(l10n.save),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  // 포털 계정 저장 처리 (API 호출)
  Future<void> _handlePortalLoginSuccess({
    required String schoolId,
    required String schoolPassword,
  }) async {
    if (!mounted) return;
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final l10n = AppLocalizations(settings.isKorean);

    // 로딩 표시
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '계정 정보를 저장하는 중입니다...',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 5),
        backgroundColor: Colors.blue,
      ),
    );

    // API로 바로 DB에 저장
    try {
      final response = await AuthRepository.I.saveSchoolAccount(
        schoolId: schoolId,
        schoolPassword: schoolPassword,
      );

      if (!mounted) return;

      // 저장 성공 메시지
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            response['message']?.toString() ?? l10n.accountSavedFetching,
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );

      // 크롤링이 백그라운드에서 진행 중이므로 시간표 조회
      await _fetchTimetableFromServer(waitForCrawling: true);
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      
      String errorMessage = l10n.saveFailed;
      if (e is DioException && e.response != null) {
        final errorData = e.response?.data;
        if (errorData is Map && errorData.containsKey('message')) {
          errorMessage = errorData['message'].toString();
        } else if (e.response?.statusCode == 401) {
          errorMessage = '인증에 실패했습니다. 다시 로그인해주세요.';
        } else if (e.response?.statusCode == 500) {
          errorMessage = '서버 오류가 발생했습니다. 잠시 후 다시 시도해주세요.';
        }
      } else {
        errorMessage = '${l10n.saveFailed}: ${e.toString()}';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
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
    // SettingsProvider를 watch하여 언어 변경 감지
    return Consumer<SettingsProvider>(
      builder: (context, settings, _) {
        final l10n = AppLocalizations(settings.isKorean);
        
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
            title: Text(l10n.timetableTitle), 
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
                tooltip: l10n.refresh,
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
                          '${l10n.updating}: ${_timetableData!.lastCrawledAt!.month}/${_timetableData!.lastCrawledAt!.day}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        )
                      else if (_timetableData!.crawlingStatus == 'crawling' && !hasData)
                        Text(
                          l10n.crawling,
                          style: const TextStyle(fontSize: 12, color: Colors.blue),
                        )
                      else
                        Text(l10n.noData, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      // 시간표가 정상적으로 표시되면 크롤링 메시지 숨김
                      if (_timetableData!.crawlingStatus == 'crawling' && !hasData)
                        Text(
                          l10n.fetchingTimetableMessage,
                          style: const TextStyle(fontSize: 10, color: Colors.blue),
                        )
                      else if (_timetableData!.count > 0)
                        Text(
                          '${l10n.subjectsCount} ${_timetableData!.count}',
                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                    ],
                  )
                else
                  Text(l10n.loading, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                
                ElevatedButton.icon(
                  onPressed: _isLoadingTimetable ? null : _openPortalWebView,
                  icon: const Icon(Icons.sync, size: 16),
                  label: Text(l10n.portalLink),
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
                        ? l10n.fetchingTimetable
                        : l10n.noTimetableMessage,
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
            Expanded(child: _buildTimetableGrid(l10n)),
        ],
      ),
    );
      },
    );
  }

  Widget _buildTimetableGrid(AppLocalizations l10n) {
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
import 'package:flutter/material.dart';
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
    // WebView 화면으로 이동, 로그인 성공 시 true 반환 기대
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const PortalTimetableWebViewScreen(),
      ),
    );

    if (result == true) {
      await _handlePortalLoginSuccess();
    } else {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('포털 로그인에 실패했거나 취소되었습니다.')),
      );
    }
  }

  Future<void> _handlePortalLoginSuccess() async {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('포털 로그인 성공! 계정 정보를 저장해주세요.'),
        duration: Duration(seconds: 3),
      ),
    );

    final saved = await _showPortalAccountSaveDialog();

    if (saved != true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('계정 정보 저장이 취소되었습니다. 나중에 다시 시도해주세요.'),
        ),
      );
      return;
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('계정 정보가 서버에 저장되었습니다. 자동 크롤링이 실행됩니다. (약 10~30초)'),
        duration: Duration(seconds: 4),
      ),
    );

    await _fetchTimetableFromServer(waitForCrawling: true);
  }

  Future<void> _fetchTimetableFromServer({bool waitForCrawling = false}) async {
    setState(() {
      _isLoadingTimetable = true;
    });

    try {
      var response = await TimetableApi.I.getTimetable();

      if (waitForCrawling && response.crawlingStatus != 'completed') {
        final completed = await _waitForCrawlingComplete(response);
        if (completed != null) {
          response = completed;
        }
      }

      _assignColors(response);
      if (mounted) {
        setState(() {
          _timetableData = response;
        });
      }
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('시간표를 불러오지 못했습니다: ${e.message}'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('시간표를 불러오지 못했습니다: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingTimetable = false;
        });
      }
    }
  }

  Future<TimetableResponse?> _waitForCrawlingComplete(
    TimetableResponse initial,
  ) async {
    var latest = initial;
    final maxWait = Duration(seconds: 35);
    final pollInterval = Duration(seconds: 3);
    final startedAt = DateTime.now();

    while (DateTime.now().difference(startedAt) < maxWait) {
      if (latest.crawlingStatus == 'completed' &&
          latest.timetable.isNotEmpty) {
        return latest;
      }
      await Future.delayed(pollInterval);
      latest = await TimetableApi.I.getTimetable();
    }
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
    final hasData =
        _timetableData != null && _timetableData!.timetable.isNotEmpty;

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
            child: Stack(
              children: [
                Positioned.fill(
                  child: Column(
                    children: List.generate(
                      _endHour - _startHour,
                      (index) => Container(
                        height: _cellHeight,
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.grey.shade200,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                for (final subject in subjects)
                  Positioned(
                    top: _topOffset(subject),
                    left: 4,
                    right: 4,
                    height: _blockHeight(subject) - 4,
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            subject.subjectName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
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
        ],
      ),
    );
  }

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

              if (schoolId.isEmpty || password.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('학번과 비밀번호를 모두 입력해주세요.'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              setStateDialog(() {
                isSubmitting = true;
              });

              try {
                await AuthRepository.I.saveSchoolAccount(
                  schoolId: schoolId,
                  schoolPassword: password,
                );
                if (mounted) {
                  Navigator.of(dialogContext).pop(true);
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('계정 정보 저장 실패: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
                setStateDialog(() {
                  isSubmitting = false;
                });
              }
            }

            return AlertDialog(
              title: const Text('포털 계정 저장'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '포털 계정을 입력하면 서버 DB에 안전하게 저장되고 10~30초 내 자동으로 시간표가 크롤링됩니다.',
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
                  onPressed: isSubmitting
                      ? null
                      : () => Navigator.of(dialogContext).pop(false),
                  child: const Text('취소'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting ? null : submit,
                  child: isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('저장'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import '../../api/notice_api.dart';
import '../../models/shuttle_notice_models.dart';
import 'shuttle_notice_detail_screen.dart';

class ShuttleNoticeListScreen extends StatefulWidget {
  const ShuttleNoticeListScreen({Key? key}) : super(key: key);

  @override
  State<ShuttleNoticeListScreen> createState() =>
      _ShuttleNoticeListScreenState();
}

class _ShuttleNoticeListScreenState extends State<ShuttleNoticeListScreen> {
  late final NoticeApi _api;
  late Future<List<ShuttleNoticeSummary>> _future;
  bool _isReloading = false;
  bool _isSyncing = false;
  int _refreshKey = 0; // FutureBuilder 강제 재빌드용

  @override
  void initState() {
    super.initState();
    _api = NoticeApi.I;
    _future = _api.fetchShuttleNotices();
  }

  Future<void> _reload() async {
    if (_isReloading) return;

    setState(() {
      _isReloading = true;
      // FutureBuilder가 새로운 future를 감지하도록 강제로 재설정
      _future = _api.fetchShuttleNotices();
      _refreshKey++; // FutureBuilder 강제 재빌드
    });

    try {
      final notices = await _future;
      if (kDebugMode) {
        print('✅ 새로고침 완료: ${notices.length}개 공지');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 셔틀 공지 리스트 새로고침 실패: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isReloading = false;
        });
      }
    }
  }

  Future<void> _syncNotices() async {
    if (_isSyncing) return;

    setState(() {
      _isSyncing = true;
    });

    try {
      final response = await _api.syncShuttleNotices();
      if (mounted) {
        // 동기화 응답에서 상세 정보 추출
        String message = '셔틀 공지 동기화가 완료되었습니다.';
        int llmFailuresCount = 0;
        
        if (response is Map<String, dynamic>) {
          final processed = response['processed'] ?? 0;
          final shuttleRelated = response['shuttleRelated'] ?? 0;
          final errors = response['errors'] ?? 0;
          llmFailuresCount = response['llmFailures'] ?? 0;
          
          // 상세 정보가 있으면 메시지에 포함
          if (processed > 0 || shuttleRelated > 0 || errors > 0 || llmFailuresCount > 0) {
            message = '동기화 완료: 처리 ${processed}개, 셔틀 관련 ${shuttleRelated}개';
            if (errors > 0) {
              message += ', 오류 ${errors}개';
            }
            if (llmFailuresCount > 0) {
              message += '\n⚠️ LLM 연결 실패 ${llmFailuresCount}건 (Ollama 서버 확인 필요)';
            }
            if (shuttleRelated == 0 && processed > 0) {
              message += '\n💡 셔틀 관련 공지가 없거나 LLM이 모두 NO로 판별했습니다.';
            }
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: Duration(seconds: llmFailuresCount > 0 ? 5 : 3),
            backgroundColor: llmFailuresCount > 0 ? Colors.orange : Colors.green,
          ),
        );
        // 동기화 완료 후 잠시 대기 후 리스트 새로고침 (서버에서 데이터 준비 시간 고려)
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          // FutureBuilder가 새로운 future를 감지하도록 강제로 재설정
          setState(() {
            _future = _api.fetchShuttleNotices();
          });
        }
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = '동기화 실패';
        String errorDetail = e.toString();
        
        // 백엔드 타임아웃 에러인 경우 명확한 메시지 표시
        if (errorDetail.contains('동기화 작업 시간 초과') || 
            errorDetail.contains('시간 초과')) {
          errorMessage = '서버에서 동기화 작업이 시간 초과되었습니다.\n백엔드 문제로 보입니다. 잠시 후 다시 시도해주세요.';
        } else if (errorDetail.contains('동기화 진행 중')) {
          errorMessage = '이미 동기화가 진행 중입니다.\n잠시 후 다시 시도해주세요.';
        } else {
          errorMessage = '동기화 실패: $errorDetail';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            duration: const Duration(seconds: 5),
            backgroundColor: Colors.red,
          ),
        );
      }
      if (kDebugMode) {
        print('❌ 셔틀 공지 동기화 실패: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('셔틀 공지'),
        actions: [
          if (_isSyncing)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.sync),
              tooltip: '동기화',
              onPressed: _syncNotices,
            ),
          if (_isReloading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: '새로고침',
              onPressed: _reload,
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<List<ShuttleNoticeSummary>>(
          future: _future,
          key: ValueKey(_refreshKey), // future가 변경될 때마다 FutureBuilder 재빌드
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              if (kDebugMode) {
                print('🔴 셔틀 공지 리스트 에러: ${snapshot.error}');
                print('🔴 스택 트레이스: ${snapshot.stackTrace}');
              }
              return ListView(
                children: [
                  const SizedBox(height: 80),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 48),
                          const SizedBox(height: 16),
                          Text(
                            '공지 조회 중 오류가 발생했습니다.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }

            final notices = snapshot.data ?? [];

            if (notices.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 80),
                  Center(
                    child: Column(
                      children: [
                        const Icon(Icons.announcement_outlined, size: 48, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text(
                          '셔틀 관련 공지가 없습니다.',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _isSyncing ? null : _syncNotices,
                          icon: _isSyncing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.sync),
                          label: Text(_isSyncing ? '동기화 중...' : '동기화'),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: _isReloading ? null : _reload,
                          icon: _isReloading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.refresh),
                          label: Text(_isReloading ? '새로고침 중...' : '새로고침'),
                        ),
                        const SizedBox(height: 8),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 32.0),
                          child: Text(
                            '동기화 버튼으로 서버에서 최신 공지를 가져옵니다.\n새로고침 버튼으로 리스트를 갱신합니다.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            return ListView.separated(
              itemCount: notices.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final notice = notices[index];
                return ListTile(
                  title: Text(
                    notice.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(notice.formattedDate),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ShuttleNoticeDetailScreen(
                          noticeId: notice.id,
                          initialTitle: notice.title,
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}


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
      _future = _api.fetchShuttleNotices();
    });

    try {
      await _future;
      if (kDebugMode) {
        print('✅ 셔틀 공지 리스트 새로고침 완료');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('셔틀 공지'),
        actions: [
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

            if (kDebugMode) {
              print('🔵 셔틀 공지 리스트: ${notices.length}개');
            }

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
                            '백엔드에서 매일 자동으로 동기화됩니다.\n새로고침 버튼으로 최신 공지를 확인하세요.',
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


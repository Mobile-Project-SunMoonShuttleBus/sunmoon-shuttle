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
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _api = NoticeApi.I;
    _future = _api.fetchShuttleNotices();
  }

  Future<void> _reload() async {
    setState(() {
      _future = _api.fetchShuttleNotices();
    });
    await _future;
  }

  Future<void> _syncNotices() async {
    if (_isSyncing) return;

    setState(() {
      _isSyncing = true;
    });

    try {
      if (kDebugMode) {
        print('🔵 셔틀 공지 동기화 시작');
      }

      final result = await _api.syncShuttleNotices();
      
      if (kDebugMode) {
        print('✅ 셔틀 공지 동기화 완료: $result');
      }

      if (!mounted) return;

      // 동기화 성공 메시지 표시
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? '셔틀 공지 동기화가 완료되었습니다.'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );

      // 목록 새로고침
      await _reload();
    } catch (e) {
      if (kDebugMode) {
        print('❌ 셔틀 공지 동기화 실패: $e');
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('동기화 실패: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
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
              tooltip: '공지 동기화',
              onPressed: _syncNotices,
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
                          onPressed: _isSyncing ? null : _syncNotices,
                          icon: _isSyncing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.sync),
                          label: Text(_isSyncing ? '동기화 중...' : '공지 동기화'),
                        ),
                        const SizedBox(height: 8),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 32.0),
                          child: Text(
                            '포털에서 최신 공지를 가져와\n셔틀 관련 공지만 표시합니다.',
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


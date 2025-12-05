import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../api/notice_api.dart';
import '../../models/shuttle_notice_models.dart';

/// 셔틀버스 공지사항 화면
/// 서버에서 공지사항을 가져와 리스트로 표시하고, 외부 링크로 이동
class BusNoticesScreen extends StatefulWidget {
  const BusNoticesScreen({super.key});

  @override
  State<BusNoticesScreen> createState() => _BusNoticesScreenState();
}

class _BusNoticesScreenState extends State<BusNoticesScreen> {
  final NoticeApi _api = NoticeApi.I;
  List<ShuttleNoticeSummary> _notices = [];
  bool _loading = true;
  bool _syncing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchNotices();
  }

  /// 공지사항 목록 조회 (GET)
  Future<void> _fetchNotices() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      final notices = await _api.fetchShuttleNotices();
      
      setState(() {
        _notices = notices;
        _error = null;
      });
    } catch (err) {
      setState(() {
        _error = '공지사항을 불러올 수 없습니다.';
      });
      if (mounted) {
        debugPrint('공지사항 조회 실패: $err');
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  /// 최신 데이터 동기화 (POST)
  Future<void> _handleSync() async {
    if (_syncing) return;

    try {
      setState(() {
        _syncing = true;
      });

      // 동기화 요청 (백엔드가 크롤링 수행)
      await _api.syncShuttleNotices();

      if (mounted) {
        // 성공 시 목록 갱신
        await _fetchNotices();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('공지사항이 최신화되었습니다.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('동기화에 실패했습니다: $err'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      debugPrint('동기화 실패: $err');
    } finally {
      if (mounted) {
        setState(() {
          _syncing = false;
        });
      }
    }
  }

  /// 날짜 포맷 (YYYY.MM.DD)
  String _formatDate(DateTime date) {
    final year = date.year;
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year.$month.$day';
  }

  /// 외부 링크 열기
  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('링크를 열 수 없습니다.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            // 상단 헤더
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '📢 셔틀버스 공지',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  // 새로고침 버튼
                  IconButton(
                    onPressed: _syncing ? null : _handleSync,
                    icon: _syncing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                            ),
                          )
                        : const Icon(
                            Icons.refresh,
                            size: 20,
                            color: Colors.grey,
                          ),
                    tooltip: '새로고침',
                  ),
                ],
              ),
            ),

            // 공지사항 목록
            Expanded(
              child: _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    // 로딩 중
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                '데이터를 불러오는 중입니다...',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 에러 발생
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.red,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // 데이터 없음
    if (_notices.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text(
            '등록된 공지사항이 없습니다.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ),
      );
    }

    // 리스트 아이템
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _notices.length,
      itemBuilder: (context, index) {
        final notice = _notices[index];
        return _buildNoticeItem(notice);
      },
    );
  }

  Widget _buildNoticeItem(ShuttleNoticeSummary notice) {
    // URL이 없으면 상세 정보를 가져와서 URL을 얻음
    final url = notice.url;
    
    if (url == null || url.isEmpty) {
      // URL이 없으면 상세 정보를 가져옴
      return FutureBuilder<ShuttleNoticeDetail>(
        future: _api.fetchShuttleNoticeDetail(notice.id),
        builder: (context, snapshot) {
          final detailUrl = snapshot.data?.url ?? '';
          return _buildNoticeCard(notice, detailUrl);
        },
      );
    }
    
    return _buildNoticeCard(notice, url);
  }

  Widget _buildNoticeCard(ShuttleNoticeSummary notice, String url) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[100]!),
      ),
      child: InkWell(
        onTap: url.isNotEmpty
            ? () => _openUrl(url)
            : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      notice.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.open_in_new,
                    size: 14,
                    color: Colors.grey,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today,
                    size: 12,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(notice.postedAt),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}


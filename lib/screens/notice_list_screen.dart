import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import './../providers/settings_provider.dart';
import './../core/localization/app_localizations.dart';
import '../repositories/notice_repository.dart';
import '../models/notice_model.dart';
import 'notice_detail_screen.dart';

/// 공지사항 목록 화면 (모달)
/// 셔틀 관련 공지사항을 목록으로 표시
class NoticeListScreen extends StatefulWidget {
  const NoticeListScreen({super.key});

  @override
  State<NoticeListScreen> createState() => _NoticeListScreenState();
}

class _NoticeListScreenState extends State<NoticeListScreen> {
  final NoticeRepository _repository = NoticeRepository.I;
  List<NoticeModel> _notices = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadNotices();
  }

  /// 공지사항 목록 로드
  Future<void> _loadNotices() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _repository.getNotices();
      
      // start_at/end_at 기반 진행중 우선 정렬 + 기간 필터
      final now = DateTime.now();
      final sortedNotices = response.data.where((notice) {
        // 현재 시간이 end_at 이후인 공지는 제외 (과거 공지 과다 노출 방지)
        return notice.endAt.isAfter(now);
      }).toList()
        ..sort((a, b) {
          // 진행 중인 공지 우선 정렬
          final aIsActive = a.isActive;
          final bIsActive = b.isActive;
          
          if (aIsActive && !bIsActive) return -1;
          if (!aIsActive && bIsActive) return 1;
          
          // 둘 다 진행 중이거나 둘 다 진행 중이 아닌 경우, start_at 기준 내림차순
          return b.startAt.compareTo(a.startAt);
        });

      if (mounted) {
        setState(() {
          _notices = sortedNotices;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, _) {
        final l10n = AppLocalizations(settingsProvider.isKorean);
        
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.7,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 헤더
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.noticeListTitle,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // 내용
                Expanded(
                  child: _buildContent(l10n),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent(AppLocalizations l10n) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadNotices,
              child: Text(l10n.retry),
            ),
          ],
        ),
      );
    }

    if (_notices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.notifications_none,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.noNotices,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadNotices,
      child: ListView.builder(
        itemCount: _notices.length,
        itemBuilder: (context, index) {
          final notice = _notices[index];
          return _buildNoticeItem(notice, l10n);
        },
      ),
    );
  }

  Widget _buildNoticeItem(NoticeModel notice, AppLocalizations l10n) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          // 공지사항 클릭 시 상세 화면으로 이동
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => NoticeDetailScreen(noticeId: notice.id),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // 레벨 배지
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: notice.levelColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    notice.levelText,
                    style: TextStyle(
                      color: notice.levelColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (notice.isActive) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '진행중',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            
            // 제목
            Text(
              notice.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            
            // 기간
            Row(
              children: [
                const Icon(Icons.access_time, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  '${_formatDateTime(notice.startAt)} ~ ${_formatDateTime(notice.endAt)}',
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

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}


import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../api/notice_api.dart';
import '../../models/shuttle_notice_models.dart';

class ShuttleNoticeDetailScreen extends StatefulWidget {
  final String noticeId;
  final String? initialTitle; // 리스트에서 넘어온 title (로딩 전 헤더용)

  const ShuttleNoticeDetailScreen({
    Key? key,
    required this.noticeId,
    this.initialTitle,
  }) : super(key: key);

  @override
  State<ShuttleNoticeDetailScreen> createState() =>
      _ShuttleNoticeDetailScreenState();
}

class _ShuttleNoticeDetailScreenState
    extends State<ShuttleNoticeDetailScreen> {
  late final NoticeApi _api;
  late Future<ShuttleNoticeDetail> _future;

  @override
  void initState() {
    super.initState();
    _api = NoticeApi.I;
    _future = _api.fetchShuttleNoticeDetail(widget.noticeId);
  }

  Future<void> _reload() async {
    setState(() {
      _future = _api.fetchShuttleNoticeDetail(widget.noticeId);
    });
    await _future;
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('원문을 열 수 없습니다.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final initialTitle = widget.initialTitle ?? '공지 상세';

    return Scaffold(
      appBar: AppBar(
        title: Text(initialTitle),
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<ShuttleNoticeDetail>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return ListView(
                children: const [
                  SizedBox(height: 80),
                  Center(child: CircularProgressIndicator()),
                ],
              );
            }

            if (snapshot.hasError) {
              return ListView(
                children: [
                  const SizedBox(height: 80),
                  Center(
                    child: Text(
                      '공지 상세 조회 중 오류가 발생했습니다.\n${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              );
            }

            final notice = snapshot.data!;
            final theme = Theme.of(context);

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  notice.title,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  notice.formattedDate,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: Colors.grey[600]),
                ),
                const SizedBox(height: 16),
                // 요약 영역
                if (notice.hasSummary) ...[
                  Row(
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'AI 요약',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: theme.colorScheme.primary.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      notice.summary,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ] else ...[
                  // 요약이 없을 때 (서버에서 생성 중일 수 있음)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 20,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'AI 요약이 아직 생성되지 않았습니다.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                // 원문 내용
                Text(
                  '상세 내용',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  notice.content,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                // 원문 보기 버튼
                Align(
                  alignment: Alignment.centerLeft,
                  child: ElevatedButton.icon(
                    onPressed: () => _openUrl(notice.url),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('포털 원문 보기'),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}


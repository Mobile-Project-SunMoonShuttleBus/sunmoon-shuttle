import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as html_dom;
import 'package:provider/provider.dart';
import './../providers/settings_provider.dart';
import './../core/localization/app_localizations.dart';
import '../repositories/notice_repository.dart';
import '../models/notice_model.dart';

/// 공지사항 상세 화면
/// 공지 본문(마크다운) 렌더링 및 XSS 방지
class NoticeDetailScreen extends StatefulWidget {
  final String noticeId;

  const NoticeDetailScreen({
    super.key,
    required this.noticeId,
  });

  @override
  State<NoticeDetailScreen> createState() => _NoticeDetailScreenState();
}

class _NoticeDetailScreenState extends State<NoticeDetailScreen> {
  final NoticeRepository _repository = NoticeRepository.I;
  NoticeModel? _notice;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadNoticeDetail();
  }

  /// 공지사항 상세 로드
  Future<void> _loadNoticeDetail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final notice = await _repository.getNoticeDetail(noticeId: widget.noticeId);
      
      if (mounted) {
        setState(() {
          _notice = notice;
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

  /// 마크다운 본문을 안전하게 sanitize
  /// XSS 방지를 위한 허용 태그 화이트리스트
  String _sanitizeMarkdown(String? markdown) {
    if (markdown == null || markdown.isEmpty) {
      return '';
    }

    // 마크다운에서 HTML이 포함된 경우 sanitize
    // 허용 태그: p, br, strong, em, ul, ol, li, h1-h6, a, code, pre, blockquote
    final allowedTags = [
      'p', 'br', 'strong', 'em', 'b', 'i', 'u',
      'ul', 'ol', 'li',
      'h1', 'h2', 'h3', 'h4', 'h5', 'h6',
      'a', 'code', 'pre', 'blockquote',
      'hr', 'table', 'thead', 'tbody', 'tr', 'th', 'td',
    ];

    try {
      // HTML 파싱
      final document = html_parser.parse(markdown);
      
      // 모든 요소를 순회하며 허용되지 않은 태그 제거
      _sanitizeNode(document, allowedTags);
      
      // a 태그의 href 속성만 허용 (javascript: 등 위험한 프로토콜 제거)
      final links = document.querySelectorAll('a');
      for (var link in links) {
        final href = link.attributes['href'];
        if (href != null) {
          // javascript:, data: 등 위험한 프로토콜 제거
          if (href.startsWith('javascript:') || 
              href.startsWith('data:') ||
              href.startsWith('vbscript:')) {
            link.attributes.remove('href');
          }
        }
      }
      
      return document.body?.innerHtml ?? markdown;
    } catch (e) {
      // 파싱 실패 시 원본 반환 (마크다운만 있는 경우)
      return markdown;
    }
  }

  /// 노드 sanitize (재귀적)
  void _sanitizeNode(html_dom.Node node, List<String> allowedTags) {
    if (node is html_dom.Element) {
      // 허용되지 않은 태그인 경우 제거
      if (!allowedTags.contains(node.localName?.toLowerCase())) {
        // 자식 노드들을 부모로 이동
        final parent = node.parent;
        if (parent != null) {
          final children = node.nodes.toList();
          for (var child in children) {
            parent.insertBefore(child, node);
          }
          node.remove();
          return;
        }
      }
      
      // 스크립트 관련 속성 제거
      node.attributes.removeWhere((key, value) {
        final keyStr = key.toString().toLowerCase();
        return keyStr.startsWith('on') || // onclick, onload 등
               keyStr == 'style'; // 인라인 스타일 제거
      });
    }
    
    // 자식 노드들도 재귀적으로 sanitize
    final children = node.nodes.toList();
    for (var child in children) {
      _sanitizeNode(child, allowedTags);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, _) {
        final l10n = AppLocalizations(settingsProvider.isKorean);
        
        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.noticeDetailTitle),
            backgroundColor: const Color(0xFF1890FF),
            foregroundColor: Colors.white,
          ),
          body: _buildContent(l10n),
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
              onPressed: _loadNoticeDetail,
              child: Text(l10n.retry),
            ),
          ],
        ),
      );
    }

    if (_notice == null) {
      return Center(
        child: Text(
          l10n.noticeNotFound,
          style: const TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    final notice = _notice!;
    final sanitizedBody = _sanitizeMarkdown(notice.body);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 레벨 배지
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: notice.levelColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  notice.levelText,
                  style: TextStyle(
                    color: notice.levelColor,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (notice.isActive) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    '진행중',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          
          // 제목
          Text(
            notice.title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // 기간
          Row(
            children: [
              const Icon(Icons.access_time, size: 18, color: Colors.grey),
              const SizedBox(width: 8),
              Text(
                '${_formatDateTime(notice.startAt)} ~ ${_formatDateTime(notice.endAt)}',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // 구분선
          const Divider(),
          const SizedBox(height: 24),
          
          // 본문 (마크다운 렌더링)
          if (sanitizedBody.isNotEmpty)
            MarkdownBody(
              data: sanitizedBody,
              styleSheet: MarkdownStyleSheet(
                p: const TextStyle(fontSize: 16, height: 1.6),
                h1: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                h2: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                h3: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                strong: const TextStyle(fontWeight: FontWeight.bold),
                em: const TextStyle(fontStyle: FontStyle.italic),
                code: const TextStyle(
                  backgroundColor: Color(0xFFF5F5F5),
                  fontFamily: 'monospace',
                ),
                codeblockDecoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(4),
                ),
                blockquote: const TextStyle(
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
                blockquoteDecoration: BoxDecoration(
                  color: Colors.grey[100],
                  border: Border(
                    left: BorderSide(color: Colors.grey[400]!, width: 4),
                  ),
                ),
              ),
            )
          else
            Text(
              l10n.noContent,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}


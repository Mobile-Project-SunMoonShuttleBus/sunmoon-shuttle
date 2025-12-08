import 'package:flutter/material.dart';

class BusStopsScreen extends StatefulWidget {
  const BusStopsScreen({super.key});

  @override
  State<BusStopsScreen> createState() => _BusStopsScreenState();
}

class _BusStopsScreenState extends State<BusStopsScreen> {
  // 현재 선택된 탭 인덱스 (기본값: 천안아산역)
  int _selectedTabIndex = 0;

  final List<String> _tabNames = [
    '천안아산역', // 0
    '아산역',     // 1
    '천안역',     // 2
    '천안터미널', // 3
    '온양터미널', // 4
    '온양온천역', // 5
  ];

  // [Helper] 파일명 리스트를 생성하는 헬퍼 함수 (.jpg 확장자 사용)
  List<String> _generateImageList(String prefix, int count) {
    // 0부터 count-1 까지 순차적인 파일명을 가진 리스트 생성
    return List.generate(count, (i) => 'assets/stops/${prefix}_$i.jpg');
  }

  // ⭐️ [최종 업데이트] _stopImages 맵 정의 (late final로 선언)
  // 각 정류장별 최종 이미지 개수에 맞춰 리스트를 생성합니다.
  late final Map<int, List<String>> _stopImages = {
    0: _generateImageList('ca', 5),          // 천안아산역 (총 5개)
    1: _generateImageList('asan', 7),        // 아산역 (총 7개)
    2: _generateImageList('cheonan', 7),     // 천안역 (총 7개)
    3: _generateImageList('term_c', 9),      // 천안터미널 (총 9개)
    4: _generateImageList('term_o', 7),      // 온양터미널 (총 7개)
    5: _generateImageList('onyang', 10),     // 온양온천역 (총 10개)
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. 상단 헤더 영역
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderImage(),
                  const SizedBox(height: 16),
                  const Text(
                    '정류장 위치 안내',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF202020),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '사진을 보고 셔틀버스 타는 곳을 찾아보세요.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),

            // 2. 탭 버튼 그리드 (6개)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: _buildTabGrid(),
            ),
            
            const SizedBox(height: 16),
            const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),

            // 3. 이미지 리스트 영역 (스크롤 가능)
            Expanded(
              child: _buildImageContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderImage() {
    return Image.asset(
      'assets/icons/map_header.png',
      width: 40,
      height: 40,
      errorBuilder: (context, error, stackTrace) {
        return const Icon(Icons.location_on, size: 40, color: Color(0xFF1890FF));
      },
    );
  }

  Widget _buildTabGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, // 한 줄에 3개씩
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 2.2, // 버튼 납작하게
      ),
      itemCount: _tabNames.length,
      itemBuilder: (context, index) {
        return _buildTabButton(index);
      },
    );
  }

  Widget _buildTabButton(int index) {
    bool isSelected = _selectedTabIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTabIndex = index;
        });
      },
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1890FF) : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? Border.all(color: const Color(0xFF1890FF), width: 1)
              : Border.all(color: Colors.transparent),
        ),
        child: Text(
          _tabNames[index],
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : Colors.grey[700],
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildImageContent() {
    final images = _stopImages[_selectedTabIndex] ?? [];

    if (images.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.image_not_supported_outlined, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              '${_tabNames[_selectedTabIndex]} 안내 이미지가 없습니다.',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: images.length,
      itemBuilder: (context, index) {
        // 인트로 이미지와 STEP 가이드를 구분
        final isIntroImage = index == 0;
        final stepNumber = isIntroImage ? '도착지' : 'STEP $index';

        return Container(
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 단계 표시 (Step 0: 도착지, Step 1, Step 2...)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: isIntroImage ? const Color(0xFFE3F2FD) : const Color(0xFFF9F9F9),
                width: double.infinity,
                child: Text(
                  isIntroImage ? '${_tabNames[_selectedTabIndex]} 승차장' : stepNumber,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isIntroImage ? const Color(0xFF1565C0) : const Color(0xFF1890FF),
                  ),
                ),
              ),
              // 이미지
              Image.asset(
                images[index],
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 200,
                    color: Colors.grey[200],
                    alignment: Alignment.center,
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.broken_image, color: Colors.grey),
                        SizedBox(height: 8),
                        Text('이미지를 불러올 수 없습니다.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
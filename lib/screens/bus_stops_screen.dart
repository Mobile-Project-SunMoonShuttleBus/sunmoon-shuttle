import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:collection/collection.dart';
import '../api/dio_client.dart'; // 1번 코드의 DioClient

class BusStopsScreen extends StatefulWidget {
  @override
  _BusStopsScreenState createState() => _BusStopsScreenState();
}

class _BusStopsScreenState extends State<BusStopsScreen> {
  // --- 지도 관련 변수 ---
  NaverMapController? _mapController;
  final Set<NMarker> _markers = {};

  int _selectedTabIndex = 0;
  final List<String> _tabNames = [
    '아산(KTX)역',
    '천안역',
    '천안 터미널',
    '온양 터미널/역'
  ];
  
  final Map<int, String> _tabApiNames = {
    0: '천안 아산역',
    1: '천안역',
    2: '천안 터미널',
    3: '온양온천역'
  };

  bool _isLoading = true;
  String _errorMessage = "";
  List<Map<String, dynamic>> _allStopsData = [];

  // 초기 위치 (아산캠퍼스)
  static const NCameraPosition _initialCameraPosition = NCameraPosition(
    target: NLatLng(36.790013, 127.002474),
    zoom: 13.0,
  );

  @override
  void initState() {
    super.initState();
    _fetchBusStops();
  }

  // [핵심 변경] DioClient 사용
  Future<void> _fetchBusStops() async {
    setState(() {
      _isLoading = true;
      _errorMessage = "";
    });

    try {
      // 1. DioClient로 API 호출 (토큰/헤더 자동 처리)
      final response = await DioClient.instance.get(
        '/api/shuttle/stops',
        queryParameters: {'dayType': '일요일'},
      );

      if (!mounted) return;

      // 2. 데이터 파싱 (Dio는 자동으로 JSON을 Map/List로 변환해줌)
      final data = response.data;
      List<dynamic> stops = data['stops'] ?? [];

      List<Map<String, dynamic>> newStopsData = [];
      Set<NMarker> newMarkers = {};

      for (var stop in stops) {
        String name = stop['name'];
        var coords = stop['coordinates'];

        if (coords != null &&
            coords['latitude'] != null &&
            coords['longitude'] != null) {
          // num 타입으로 안전하게 변환 후 double로 캐스팅
          double lat = (coords['latitude'] as num).toDouble();
          double lng = (coords['longitude'] as num).toDouble();

          newMarkers.add(
            NMarker(
              id: name,
              position: NLatLng(lat, lng),
              caption: NOverlayCaption(text: name),
            ),
          );

          newStopsData.add({"name": name, "lat": lat, "lng": lng});
        }
      }

      setState(() {
        _markers.clear();
        _markers.addAll(newMarkers);
        _allStopsData = newStopsData;
        _isLoading = false;
      });

      // 3. 지도에 마커 추가 (컨트롤러가 준비된 경우)
      if (_mapController != null) {
        await _mapController!.clearOverlays(type: NOverlayType.marker);
        await _mapController!.addOverlayAll(_markers);
      }

    } catch (e) {
      // 에러 발생 시 처리
      if (!mounted) return;
      setState(() {
        _errorMessage = "데이터를 불러오지 못했습니다.";
        _isLoading = false;
      });
      print("정류장 로딩 실패: $e");
    }
  }

  // 탭 클릭 시 해당 정류장으로 카메라 이동
  Future<void> _moveToSelectedStop(int index) async {
    String apiName = _tabApiNames[index]!;

    var stopData = _allStopsData.firstWhereOrNull(
      (s) => s['name'] == apiName,
    );

    if (stopData != null && _mapController != null) {
      final NCameraUpdate cameraUpdate = NCameraUpdate.scrollAndZoomTo(
        target: NLatLng(stopData['lat'], stopData['lng']),
        zoom: 16.0,
      );
      await _mapController!.updateCamera(cameraUpdate);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderImage(),
              SizedBox(height: 16),
              Text(
                '정류장 위치',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF202020),
                ),
              ),
              SizedBox(height: 24),
              _buildTabGrid(),
              SizedBox(height: 24),
              _buildMapContent(),
            ],
          ),
        ),
      ),
    );
  }

  // 헤더 이미지 (에러 방지 처리 포함)
  Widget _buildHeaderImage() {
    return Image.asset(
      'assets/icons/map_header.png',
      width: 48,
      height: 48,
      errorBuilder: (context, error, stackTrace) {
        return Icon(Icons.map, size: 48, color: Colors.blue);
      },
    );
  }

  Widget _buildTabGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 2.5,
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
        _moveToSelectedStop(index);
      },
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: Colors.blue[800]!, width: 2)
              : null,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.1),
                    blurRadius: 5,
                    spreadRadius: 1,
                  )
                ]
              : null,
        ),
        child: Text(
          _tabNames[index],
          style: TextStyle(
            fontSize: 16,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.blue[800] : Colors.grey[700],
          ),
        ),
      ),
    );
  }

  Widget _buildMapContent() {
    return Container(
      height: 400,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            NaverMap(
              options: const NaverMapViewOptions(
                initialCameraPosition: _initialCameraPosition,
                indoorEnable: true,
                locationButtonEnable: true,
                mapType: NMapType.basic,
              ),
              onMapReady: (controller) {
                _mapController = controller;
                print("NaverMap (정류장) 준비 완료");

                // 지도가 준비되면 마커 추가
                if (_markers.isNotEmpty) {
                  _mapController!.addOverlayAll(_markers);
                }
              },
            ),
            // 로딩 중 표시
            if (_isLoading)
              Container(
                color: Colors.white.withOpacity(0.7),
                child: Center(child: CircularProgressIndicator()),
              ),
            // 에러 메시지 표시
            if (_errorMessage.isNotEmpty)
              Center(
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: 20),
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _errorMessage,
                    style: TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
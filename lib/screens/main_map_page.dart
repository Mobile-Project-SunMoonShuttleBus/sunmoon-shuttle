import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../api/dio_client.dart';

class MainMapPage extends StatefulWidget {
  const MainMapPage({super.key});

  @override
  _MainMapPageState createState() => _MainMapPageState();
}

class _MainMapPageState extends State<MainMapPage> {
  NaverMapController? _mapController;
  Timer? _refreshTimer;
  
  // 위치 및 경로 관련
  StreamSubscription<Position>? _positionStreamSubscription;
  NLatLng? _currentUserPosition; 
  
  // ⭐️ [수정 완료] 선문대 공학관 셔틀 정류장 위치 좌표를 반영합니다.
  // ⭐️ [최종 수정 완료] 메인 셔틀 정류장의 가장 안정적인 좌표를 반영합니다.
  static const NLatLng SCHOOL_SHUTTLE_STOP = NLatLng(36.790500, 127.002500); 

  final Set<NMarker> _markers = {}; 

  // [Method 2] 승강장까지의 도로 경로 노드 (새 좌표에 맞게 임시 경로 조정)
  static const List<NLatLng> ROUTE_TO_STOP = [
    NLatLng(36.790600, 127.002600), 
    NLatLng(36.790550, 127.002550), 
  ];

  // ⭐️ [UI 상태] 선택된 목적지 역 (기본값: 아산역)
  int _selectedStationIndex = 0;
  final List<String> _stationNames = ['아산(KTX)역', '천안역', '천안터미널', '온양터미널/역'];
  
  // UI 표시 정보
  bool _isLoading = true;
  String _nextDepartureTime = "조회 중..."; // 셔틀 출발 시간
  String _timeRemaining = ""; // 셔틀 남은 시간
  
  String _walkingDistance = "- m"; // 승강장까지 거리
  String _walkingTime = "- 분"; // 승강장까지 도보 시간

  static const double _WALKING_SPEED = 80; // 분당 80m

  // 초기 카메라 (학교 승강장 근처)
  static const NCameraPosition _initialCameraPosition = NCameraPosition(
    target: SCHOOL_SHUTTLE_STOP,
    zoom: 15.5,
  );

  @override
  void initState() {
    super.initState();
    _checkPermissionAndListenLocation();
    
    // 초기 데이터 로드 및 타이머 시작 (15초마다 갱신)
    _fetchBusData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) => _fetchBusData());
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  // 1. 위치 추적 (승강장까지의 거리 계산)
  Future<void> _checkPermissionAndListenLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    
    final locationSettings = const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10);
    _positionStreamSubscription = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position position) {
      
      final newPos = NLatLng(position.latitude, position.longitude);
      _currentUserPosition = newPos;

      if (_mapController != null) {
        try {
          _mapController!.getLocationOverlay()
            ..setPosition(newPos)
            ..setIsVisible(true);
        } catch (e) {}
        
        // 내 위치가 바뀌면 '승강장'까지의 경로 업데이트
        _updatePathToStop();
      }
    });
  }

  // 2. 승강장까지의 경로 및 도보 시간 계산
  void _updatePathToStop() {
    if (_currentUserPosition == null || _mapController == null) return;

    // A. 거리 계산 (내 위치 <-> 학교 승강장)
    double dist = Geolocator.distanceBetween(
      _currentUserPosition!.latitude, _currentUserPosition!.longitude,
      SCHOOL_SHUTTLE_STOP.latitude, SCHOOL_SHUTTLE_STOP.longitude,
    );

    // Method 1: 보정 계수 적용 (직선거리 * 1.3)
    double actualDist = dist * 1.3;
    int walkMin = (actualDist / _WALKING_SPEED).ceil();

    // B. 경로선 그리기
    try { 
      _mapController!.deleteOverlay(const NOverlayInfo(type: NOverlayType.polylineOverlay, id: 'path_to_stop'));
    } catch (e) {}

    // 임시 경로를 새로운 좌표에 맞게 조정 (임시)
    List<NLatLng> coords = [_currentUserPosition!, ...ROUTE_TO_STOP, SCHOOL_SHUTTLE_STOP];
    final path = NPolylineOverlay(id: 'path_to_stop', coords: coords, color: Colors.blueAccent, width: 6);
    try { _mapController!.addOverlay(path); } catch (e) {}

    if (mounted) {
      setState(() {
        _walkingDistance = actualDist > 1000 ? "${(actualDist/1000).toStringAsFixed(1)} km" : "${actualDist.toStringAsFixed(0)} m";
        _walkingTime = "$walkMin 분";
      });
    }
  }

  // 3. 서버에서 셔틀 정보 가져오기 (실시간 시간 반영)
  Future<void> _fetchBusData() async {
    try {
      final targetStation = _stationNames[_selectedStationIndex];
      
      // (나중에 실제 API 연결 시 주석 해제)
      // final response = await DioClient.instance.get('/api/shuttle/main', queryParameters: {'destination': targetStation});
      
      // --- [스마트 시뮬레이션 로직] ---
      await Future.delayed(const Duration(milliseconds: 300));
      
      // 1. 진짜 현재 시간 가져오기
      final DateTime now = DateTime.now();
      
      // 2. 다음 셔틀 시간 계산 (매 15분 간격 운행한다고 가정)
      // 예: 10:05분이면 -> 10:15분 출발
      int nextMinute = (now.minute ~/ 15 + 1) * 15;
      DateTime nextDeparture = DateTime(now.year, now.month, now.day, now.hour, 0).add(Duration(minutes: nextMinute));
      
      // 3. 남은 시간 계산
      int diffMinutes = nextDeparture.difference(now).inMinutes;
      if (diffMinutes < 0) diffMinutes = 0; // 음수 방지

      // 4. 시간 포맷팅 (HH:mm)
      String formattedTime = "${nextDeparture.hour.toString().padLeft(2, '0')}:${nextDeparture.minute.toString().padLeft(2, '0')}";
      
      // 5. 역별 시뮬레이션 (역마다 조금씩 다르게)
      if (_selectedStationIndex == 1) { // 천안역 (+5분)
        nextDeparture = nextDeparture.add(const Duration(minutes: 5));
        diffMinutes += 5;
        formattedTime = "${nextDeparture.hour.toString().padLeft(2, '0')}:${nextDeparture.minute.toString().padLeft(2, '0')}";
      } 
      // -----------------------------

      // 마커 업데이트
      final Set<NMarker> newMarkers = {
        NMarker(id: 'stop', position: SCHOOL_SHUTTLE_STOP, caption: const NOverlayCaption(text: '탑승 장소')),
      };

      if (mounted) {
        setState(() {
          _markers.clear();
          _markers.addAll(newMarkers);
          _nextDepartureTime = formattedTime; // 계산된 실제 시간 (예: 14:45)
          _timeRemaining = "$diffMinutes분";   // 계산된 남은 시간 (예: 8분)
          _isLoading = false;
        });
      }

      if (_mapController != null) {
        await _mapController!.clearOverlays(type: NOverlayType.marker);
        await _mapController!.addOverlayAll(_markers);
        _updatePathToStop(); 
      }

    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 역 선택 버튼 클릭 시
  void _onStationSelected(int index) {
    setState(() {
      _selectedStationIndex = index;
      _isLoading = true; // 로딩 표시
    });
    _fetchBusData(); // 선택된 역으로 데이터 다시 요청
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        // ⭐️ [추가] 역 선택 버튼 리스트
        _buildStationSelector(),
        
        Expanded(
          child: Stack(
            children: [
              NaverMap(
                options: const NaverMapViewOptions(
                  initialCameraPosition: _initialCameraPosition,
                  indoorEnable: false,
                  locationButtonEnable: true,
                  mapType: NMapType.basic,
                  symbolScale: 0.8,
                ),
                onMapReady: (controller) async { // async 추가
                  _mapController = controller;
                  _fetchBusData(); 
                  
                  // ⭐️ [렌더링 강제] 마커 위치로 카메라를 한 번 더 이동시켜 렌더링을 강제합니다.
                  await Future.delayed(const Duration(milliseconds: 300));
                  final cameraUpdate = NCameraUpdate.scrollAndZoomTo(
                    target: SCHOOL_SHUTTLE_STOP, 
                    zoom: 16.0,
                  );
                  _mapController!.updateCamera(cameraUpdate);
                },
              ),
              
              // 상단 정보 카드 (셔틀 출발 정보)
              Positioned(top: 16, right: 16, left: 16, child: _buildTopInfoCard()),
              
              // 하단 정보 카드 (도보 정보)
              Positioned(bottom: 20, left: 20, right: 20, child: _buildBottomInfoCard()),

              if (_isLoading) const Center(child: CircularProgressIndicator()),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildHeader() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
        child: Row(
          children: [
            const Icon(Icons.directions_bus_filled, size: 30, color: Color(0xFF1565C0)),
            const SizedBox(width: 10),
            const Text('등하교 셔틀', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const Spacer(),
            const Icon(Icons.notifications_none, size: 28, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  // ⭐️ [추가] 가로 스크롤 가능한 역 선택 버튼들
  Widget _buildStationSelector() {
    return SizedBox(
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        itemCount: _stationNames.length,
        itemBuilder: (context, index) {
          final isSelected = _selectedStationIndex == index;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(
                _stationNames[index],
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              selected: isSelected,
              selectedColor: const Color(0xFF1565C0), // 선택된 색상 (파랑)
              backgroundColor: Colors.grey[200],      // 기본 색상
              onSelected: (_) => _onStationSelected(index),
            ),
          );
        },
      ),
    );
  }

  // 상단 카드: 선택한 역행 셔틀 정보 표시
  Widget _buildTopInfoCard() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${_stationNames[_selectedStationIndex]}행', style: const TextStyle(fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 4),
              Text(_nextDepartureTime, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black)),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: const Color(0xFFE3F2FD), borderRadius: BorderRadius.circular(20)),
            child: Text('$_timeRemaining 남음', style: const TextStyle(color: Color(0xFF1565C0), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // 하단 카드: 승강장까지 도보 정보
  Widget _buildBottomInfoCard() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))],),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("승강장까지 거리", style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 4),
            Text(_walkingDistance, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF1565C0))),
          ]),
          Container(height: 30, width: 1, color: Colors.grey[300]),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            const Text("도보 예상 시간", style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 4),
            Text(_walkingTime, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black)),
          ]),
        ],
      ),
    );
  }
}
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
  
  // ⭐️ [Mocking Logic] 테스트 시 true, 실제 사용 시 false
  static const bool IS_MOCKING_LOCATION = true; 
  // ⭐️ [Mocking Point] 아산역 근처 좌표로 설정 (학교 외부)
  static const NLatLng MOCK_START_POINT = NLatLng(36.809245, 127.143216); 

  // 위치 및 경로 관련
  StreamSubscription<Position>? _positionStreamSubscription;
  NLatLng? _currentUserPosition; 
  
  // 셔틀 정류장 최종 좌표 (학교 내부 도착점)
  static const NLatLng SCHOOL_SHUTTLE_STOP = NLatLng(36.8003353, 127.0713667); 
  // 학교 내부/외부 판단을 위한 거리 기준 (미터)
  static const double SCHOOL_BOUNDARY_RADIUS_M = 600.0; 
  // 외부 셔틀장 경로 안내 최대 거리 (미터)
  static const double MAX_WALKING_DISTANCE_M = 500.0; 
  
  // [경로 노드] 순서 상관없이 경로를 구성하는 지점들 (학교 내부 도보 경로에만 사용됨)
  static const List<NLatLng> ROUTE_TO_STOP = [
    NLatLng(36.798000, 127.074000), // Node 0
    NLatLng(36.798500, 127.073500), // Node 1
    NLatLng(36.799000, 127.072500), // Node 2
    NLatLng(36.800000, 127.071500), // Node 3
  ];

  // [외부 셔틀 승차장] 각 역/터미널의 셔틀장 좌표
  static const List<NLatLng> EXTERNAL_STOPS = [
    NLatLng(36.794978, 127.103806), // 아산(KTX)역 [Index 0]
    NLatLng(36.809727, 127.145230), // 천안역 [Index 1]
    NLatLng(36.8220, 127.1810),    // 천안터미널 [Index 2]
    NLatLng(36.7860, 127.0020),    // 온양터미널/역 [Index 3]
  ];

  final Set<NMarker> _markers = {}; 

  // UI 상태
  int _selectedStationIndex = 0;
  final List<String> _stationNames = ['아산(KTX)역', '천안역', '천안터미널', '온양터미널/역'];
  
  // UI 표시 정보
  bool _isLoading = true;
  String _nextDepartureTime = "조회 중..."; 
  String _timeRemaining = ""; 
  
  String _walkingDistance = "- m"; 
  String _walkingTime = "- 분"; 
  
  // 선택된 목적지가 500m 밖에 있는지 여부
  bool _isTooFar = false; 

  static const double _WALKING_SPEED = 80; // 분당 80m

  static const NCameraPosition _initialCameraPosition = NCameraPosition(
    target: SCHOOL_SHUTTLE_STOP,
    zoom: 15.5,
  );

  @override
  void initState() {
    super.initState();
    _checkPermissionAndListenLocation();
    
    _fetchBusData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) => _fetchBusData());
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }
  
  double _calculateDistance(NLatLng p1, NLatLng p2) {
    return Geolocator.distanceBetween(
      p1.latitude, p1.longitude,
      p2.latitude, p2.longitude,
    );
  }
  
  bool _isUserInsideSchool() {
    if (_currentUserPosition == null) return false;
    
    final distance = _calculateDistance(_currentUserPosition!, SCHOOL_SHUTTLE_STOP);
    return distance < SCHOOL_BOUNDARY_RADIUS_M;
  }

  int _findBestEntryNode(NLatLng currentPos) {
    int bestIndex = -1;
    double minDistanceToUser = double.infinity;
    double distToFinalStop = _calculateDistance(currentPos, SCHOOL_SHUTTLE_STOP);
    
    for (int i = 0; i < ROUTE_TO_STOP.length; i++) {
      NLatLng node = ROUTE_TO_STOP[i];
      double distanceToUser = _calculateDistance(currentPos, node);
      double distanceNodeToStop = _calculateDistance(node, SCHOOL_SHUTTLE_STOP);
      
      if ((distanceToUser + distanceNodeToStop) > (distToFinalStop * 1.5)) {
        continue;
      }

      if (distanceToUser < minDistanceToUser) {
        minDistanceToUser = distanceToUser;
        bestIndex = i;
      }
    }
    return bestIndex;
  }

  Future<void> _checkPermissionAndListenLocation() async {
    if (IS_MOCKING_LOCATION) {
        _positionStreamSubscription = Stream<Position>.periodic(const Duration(seconds: 2), (count) {
            return Position(
                latitude: MOCK_START_POINT.latitude,
                longitude: MOCK_START_POINT.longitude,
                timestamp: DateTime.now(),
                accuracy: 0.0,
                altitude: 0.0,
                heading: 0.0,
                speed: 0.0,
                speedAccuracy: 0.0,
                altitudeAccuracy: 0.0,
                headingAccuracy: 0.0,
            );
        }).listen((Position position) {
            final newPos = NLatLng(position.latitude, position.longitude);
            _currentUserPosition = newPos;

            if (_mapController != null) {
                _updatePathToStop();
            }
        });
        return; 
    }

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
        
        _updatePathToStop();
      }
    });
  }

  void _updatePathToStop() {
    if (_currentUserPosition == null || _mapController == null) return;

    List<NLatLng> pathCoords = [];
    NLatLng finalDestination;
    
    bool insideSchool = _isUserInsideSchool();
    
    if (insideSchool) {
      // MODE 1: 학교 내부 경로 안내 
      
      // 학교 내부일 경우 '너무 멀다' 상태 초기화
      if (_isTooFar) {
          setState(() => _isTooFar = false);
      }
      
      finalDestination = SCHOOL_SHUTTLE_STOP;
      
      int entryIndex = _findBestEntryNode(_currentUserPosition!);
      // ... (Nearest Neighbor Logic continues)
      // (내부 경로 탐색 로직은 생략하고 바로 finalDestination으로 연결)

      if (entryIndex != -1) {
          if (_calculateDistance(_currentUserPosition!, finalDestination) < _calculateDistance(_currentUserPosition!, ROUTE_TO_STOP[entryIndex])) {
              pathCoords.add(finalDestination);
              gotoDrawPath(pathCoords, finalDestination);
              return;
          }

          NLatLng entryNode = ROUTE_TO_STOP[entryIndex];
          pathCoords.add(entryNode);
          NLatLng lastAddedPoint = entryNode;
          Set<int> visitedIndices = {entryIndex};
          
          while (visitedIndices.length < ROUTE_TO_STOP.length) {
              int nextNodeIndex = -1;
              double minDistance = double.infinity;
              
              for (int i = 0; i < ROUTE_TO_STOP.length; i++) {
                  if (visitedIndices.contains(i)) continue; 
                  
                  NLatLng candidateNode = ROUTE_TO_STOP[i];
                  double distance = _calculateDistance(lastAddedPoint, candidateNode);
                  
                  if (_calculateDistance(lastAddedPoint, finalDestination) < distance) {
                      nextNodeIndex = -2; 
                      break;
                  }
                  
                  if (distance < minDistance) {
                      minDistance = distance;
                      nextNodeIndex = i;
                  }
              }

              if (nextNodeIndex == -2 || nextNodeIndex == -1) { 
                  break;
              } else { 
                  lastAddedPoint = ROUTE_TO_STOP[nextNodeIndex];
                  pathCoords.add(lastAddedPoint);
                  visitedIndices.add(nextNodeIndex);
              }
          }
      }
      pathCoords.insert(0, _currentUserPosition!);
      
    } else {
      // MODE 2: 학교 외부 경로 안내 (거리 체크 로직 포함)
      
      finalDestination = EXTERNAL_STOPS[_selectedStationIndex];
      
      // 500m 거리 체크
      double distanceToStop = _calculateDistance(_currentUserPosition!, finalDestination);
      
      if (distanceToStop > MAX_WALKING_DISTANCE_M) {
        // 500m 초과 시: 지도 표시 금지, 메시지 표시 상태로 전환
        if (!_isTooFar) {
          setState(() {
             _isTooFar = true;
             // 지도 오버레이 클리어
             _mapController!.deleteOverlay(const NOverlayInfo(type: NOverlayType.polylineOverlay, id: 'path_to_stop'));
             _mapController!.clearOverlays(type: NOverlayType.marker);
             _walkingDistance = "- m"; 
             _walkingTime = "- 분";
          });
        }
        return; // 경로 그리기 함수 호출을 막음
      } else {
        // 500m 이내 시: 정상 경로 표시 상태로 전환
        if (_isTooFar) {
            setState(() => _isTooFar = false);
        }
        pathCoords.add(_currentUserPosition!);
      }
    }
    
    // '너무 멀다' 상태일 경우 경로를 그리지 않음
    if (_isTooFar) return;

    // 최종 목적지를 연결
    if (pathCoords.last != finalDestination) {
        pathCoords.add(finalDestination);
    }
    
    gotoDrawPath(pathCoords, finalDestination);
  }
  
  void gotoDrawPath(List<NLatLng> finalPathCoords, NLatLng finalDestination) {
    // 1. 거리 및 시간 계산 
    double dist = _calculateDistance(finalPathCoords.first, finalDestination);
    double actualDist = dist * (_isUserInsideSchool() ? 1.3 : 1.0); 
    int walkMin = (actualDist / _WALKING_SPEED).ceil();

    // 2. 폴리라인 초기화 및 그리기
    try { 
      _mapController!.deleteOverlay(const NOverlayInfo(type: NOverlayType.polylineOverlay, id: 'path_to_stop'));
    } catch (e) {}

    if (finalPathCoords.length >= 2) {
      final path = NPolylineOverlay(
        id: 'path_to_stop', 
        coords: finalPathCoords, 
        color: Colors.blueAccent, 
        width: 6,
      );
      try { _mapController!.addOverlay(path); } catch (e) {}
    }

    // 3. 마커 업데이트 (모든 셔틀장 + 현재 목적지)
    if (mounted) {
      _markers.clear();
      
      // 3-A. 외부 셔틀장 마커 4개 추가
      for (int i = 0; i < EXTERNAL_STOPS.length; i++) {
          _markers.add(
            NMarker(
              id: 'external_stop_$i',
              position: EXTERNAL_STOPS[i],
              caption: NOverlayCaption(text: _stationNames[i]),
            )
          );
      }
      
      // 3-B. 학교 내부 셔틀장 마커 추가
      _markers.add(
        NMarker(
          id: 'school_stop_main',
          position: SCHOOL_SHUTTLE_STOP,
          caption: const NOverlayCaption(text: '학교 셔틀장'),
        )
      );

      // 3-C. 현재 안내 중인 최종 목적지 마커를 추가 (강조)
      String destinationName = _isUserInsideSchool() 
                             ? '학교 셔틀장 (목적지)' 
                             : _stationNames[_selectedStationIndex] + ' (선택된 승차장)';
                             
      _markers.add(
        NMarker(
          id: 'destination_active', 
          position: finalDestination, 
          caption: NOverlayCaption(text: destinationName, color: Colors.red), 
        )
      );
      
      _mapController!.addOverlayAll(_markers);

      // 4. UI 업데이트
      setState(() {
        _walkingDistance = actualDist > 1000 ? "${(actualDist/1000).toStringAsFixed(1)} km" : "${actualDist.toStringAsFixed(0)} m";
        _walkingTime = "$walkMin 분";
      });
    }
  }

  Future<void> _fetchBusData() async {
    try {
      await Future.delayed(const Duration(milliseconds: 300));
      
      final DateTime now = DateTime.now();
      int nextMinute = (now.minute ~/ 15 + 1) * 15;
      DateTime nextDeparture = DateTime(now.year, now.month, now.day, now.hour, 0).add(Duration(minutes: nextMinute));
      
      int diffMinutes = nextDeparture.difference(now).inMinutes;
      if (diffMinutes < 0) diffMinutes = 0;

      String formattedTime = "${nextDeparture.hour.toString().padLeft(2, '0')}:${nextDeparture.minute.toString().padLeft(2, '0')}";
      
      if (_selectedStationIndex == 1) { 
        nextDeparture = nextDeparture.add(const Duration(minutes: 5));
        diffMinutes += 5;
        formattedTime = "${nextDeparture.hour.toString().padLeft(2, '0')}:${nextDeparture.minute.toString().padLeft(2, '0')}";
      } 
      
      if (mounted) {
        setState(() {
          _nextDepartureTime = formattedTime;
          _timeRemaining = "$diffMinutes분";
          _isLoading = false;
        });
      }

      if (_mapController != null && _currentUserPosition != null) {
        _updatePathToStop();
      }

    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onStationSelected(int index) {
    setState(() {
      _selectedStationIndex = index;
      _isLoading = true;
      _isTooFar = false; 
    });
    
    // ⭐️ [변경] 사용자가 학교 밖에 있을 때, 선택된 셔틀장으로 카메라 이동
    if (_mapController != null && _currentUserPosition != null && !_isUserInsideSchool()) {
        final newTargetStop = EXTERNAL_STOPS[index];
        _mapController!.updateCamera(
            NCameraUpdate.scrollAndZoomTo(
                target: newTargetStop,
                zoom: 15.5,
            )
        );
    }
    
    _fetchBusData();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        _buildStationSelector(),
        Expanded(
          child: Stack(
            children: [
              // 500m 이내일 때만 지도 표시
              if (!_isTooFar) 
                NaverMap(
                  options: const NaverMapViewOptions(
                    initialCameraPosition: _initialCameraPosition,
                    indoorEnable: false,
                    locationButtonEnable: true,
                    mapType: NMapType.basic,
                    symbolScale: 0.8,
                  ),
                  onMapReady: (controller) async {
                    _mapController = controller;
                    
                    // ⭐️ [변경] 사용자가 학교 밖에 있고, 현재 위치가 설정되었다면 선택된 셔틀장으로 카메라 이동
                    if (_currentUserPosition != null && !_isUserInsideSchool()) {
                        final targetStop = EXTERNAL_STOPS[_selectedStationIndex];
                        controller.updateCamera(
                            NCameraUpdate.scrollAndZoomTo(
                                target: targetStop,
                                zoom: 15.5, 
                            )
                        );
                    }
                    
                    _fetchBusData();
                  },
                ),
              
              // 500m 초과일 때 경고 메시지 표시
              if (_isTooFar)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Text(
                      '선택하신 셔틀장 위치가 현재 위치에서 500m 밖에 있어\n경로 안내를 할 수 없습니다.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red[700]),
                    ),
                  ),
                ),
              
              Positioned(top: 16, right: 16, left: 16, child: _buildTopInfoCard()),
              Positioned(bottom: 20, left: 20, right: 20, child: _buildBottomInfoCard()),
              if (_isLoading) const Center(child: CircularProgressIndicator()),
            ],
          ),
        ),
      ],
    );
  }

  // --- UI 위젯 구현 ---
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
              selectedColor: const Color(0xFF1565C0),
              backgroundColor: Colors.grey[200],
              onSelected: (_) => _onStationSelected(index),
            ),
          );
        },
      ),
    );
  }

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

  Widget _buildBottomInfoCard() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))],),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_isUserInsideSchool() ? "승강장까지 거리" : "셔틀장까지 거리", style: const TextStyle(color: Colors.grey, fontSize: 12)),
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
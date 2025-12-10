import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart'; // DioException 처리를 위해 Dio import
import '../api/dio_client.dart'; 
import 'notice_list_screen.dart'; // 공지사항 화면 import

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
  
  // 셔틀 정류장 최종 좌표 (학교 내부 도착점)
  static const NLatLng SCHOOL_SHUTTLE_STOP = NLatLng(36.8003353, 127.0713667); 
  // 학교 내부/외부 판단을 위한 거리 기준 (미터)
  static const double SCHOOL_BOUNDARY_RADIUS_M = 600.0; 
  // 외부 셔틀장 경로 안내 최대 거리 (미터)
  static const double MAX_WALKING_DISTANCE_M = 500.0; 
  
  // [경로 노드] 순서: 정문 쪽 -> 셔틀장 쪽으로 이어지는 순서라고 가정
  static const List<NLatLng> ROUTE_TO_STOP = [
    NLatLng(36.798057, 127.071833), // Node 0
    NLatLng(36.799466, 127.071824), // Node 1
    NLatLng(36.799462, 127.073516), // Node 2
    NLatLng(36.798036, 127.073529), // Node 3
    NLatLng(36.799452, 127.073529), // Node 4
    NLatLng(36.798028, 127.076416), // Node 5
    NLatLng(36.799444, 127.076362), // Node 6
    NLatLng(36.799470, 127.077909), // Node 7
    NLatLng(36.798047, 127.077981), // Node 8
  ];

  // [외부 셔틀 승차장] 각 역/터미널의 셔틀장 좌표
  static const List<NLatLng> EXTERNAL_STOPS = [
    NLatLng(36.794978, 127.103806), // 아산(KTX)역 [Index 0]
    NLatLng(36.809727, 127.145230), // 천안역 [Index 1]
    NLatLng(36.819289, 127.154419), // 천안터미널 [Index 2]
    NLatLng(36.7860, 127.0020),     // 온양터미널/역 [Index 3]
  ];

  final Set<NMarker> _markers = {}; 

  // UI 상태
  int _selectedStationIndex = 0;
  final List<String> _stationNames = ['아산(KTX)역', '천안역', '천안터미널', '온양터미널/역'];
  
  // ⭐️ API 호출 시 사용할 정확한 이름 매핑
  final Map<int, String> _stationApiNames = {
    0: '천안 아산역', // API name for 아산(KTX)역
    1: '천안역',
    2: '천안 터미널',
    3: '온양역/아산터미널' 
  };
  
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
    
    // 1. 위치 권한 확인 및 실제 위치 리스닝 시작
    _checkPermissionAndListenLocation();
    
    // 2. 초기 데이터 조회 (기본 선택된 역 기준)
    _fetchBusData();
    
    // 3. 주기적 데이터 갱신 (15초마다)
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
      
      // 사용자로부터 너무 멀리 떨어져 있거나 뒤쪽 노드인 경우 제외 (휴리스틱)
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

  // ⭐️ [수정] 실제 위치 서비스 활성화 및 권한 확인 후 스트림 리스닝
  Future<void> _checkPermissionAndListenLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // 1. 위치 서비스 활성화 여부 확인
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // 위치 서비스가 꺼져 있으면 사용자에게 요청하거나 기본 처리
      return;
    }

    // 2. 위치 권한 확인 및 요청
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // 권한 거부됨
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      // 권한 영구 거부됨
      return;
    }
    
    // 3. 실제 위치 스트림 구독 (정확도 High, 10m 이동 시 업데이트)
    final locationSettings = const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10);
    _positionStreamSubscription = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position position) {
      
      final newPos = NLatLng(position.latitude, position.longitude);
      
      // 첫 위치 수신 시 가장 가까운 역 자동 선택 로직 (선택 사항)
      if (_currentUserPosition == null) {
          _selectNearestStation(newPos);
      }

      _currentUserPosition = newPos;

      if (_mapController != null) {
        try {
          // 지도에 현재 위치 오버레이 표시
          _mapController!.getLocationOverlay()
            ..setPosition(newPos)
            ..setIsVisible(true);
            
          // 위치가 갱신될 때마다 경로 업데이트
          _updatePathToStop();
          
          // (선택) 위치가 변경되면 버스 데이터도 갱신할지 여부 결정
          // _fetchBusData(); 
        } catch (e) {
            // 지도 컨트롤러 에러 무시
        }
      }
    });
  }
  
  // ⭐️ [추가] 현재 위치 기반 가장 가까운 역 자동 선택
  void _selectNearestStation(NLatLng pos) {
      double minDistance = double.infinity;
      int bestIndex = 0;
      
      // 학교 내부가 아닐 때만 외부 역 중 가장 가까운 곳을 찾음
      if (_calculateDistance(pos, SCHOOL_SHUTTLE_STOP) >= SCHOOL_BOUNDARY_RADIUS_M) {
          for (int i = 0; i < EXTERNAL_STOPS.length; i++) {
              final dist = _calculateDistance(pos, EXTERNAL_STOPS[i]);
              if (dist < minDistance) {
                  minDistance = dist;
                  bestIndex = i;
              }
          }
          // UI 갱신 없이 내부 상태만 변경하거나, setState로 갱신
          if (mounted) {
              setState(() {
                  _selectedStationIndex = bestIndex;
              });
              _fetchBusData(); // 선택된 역에 맞는 데이터 다시 가져오기
          }
      }
  }

  // 🚀 [경로 로직] 학교 내부 경로 최적화
  void _updatePathToStop() {
    if (_currentUserPosition == null || _mapController == null) return;

    List<NLatLng> pathCoords = [];
    NLatLng finalDestination;
    
    bool insideSchool = _isUserInsideSchool();
    
    if (insideSchool) {
      // MODE 1: 학교 내부 경로 안내 
      
      if (_isTooFar) {
          setState(() => _isTooFar = false);
      }
      
      finalDestination = SCHOOL_SHUTTLE_STOP;
      
      // 1. 가장 가까운 진입 노드 찾기
      int entryIndex = _findBestEntryNode(_currentUserPosition!);
      
      if (entryIndex != -1) {
          // 예외 처리: 현재 위치에서 목적지까지가 진입 노드보다 더 가까우면 바로 연결
          if (_calculateDistance(_currentUserPosition!, finalDestination) < 
              _calculateDistance(_currentUserPosition!, ROUTE_TO_STOP[entryIndex])) {
              
              pathCoords.add(_currentUserPosition!);
              pathCoords.add(finalDestination);
              gotoDrawPath(pathCoords, finalDestination);
              return;
          }

          // 2. 경로 생성 시작
          pathCoords.add(_currentUserPosition!);
          pathCoords.add(ROUTE_TO_STOP[entryIndex]); // A노드 (진입)
          
          NLatLng lastAddedNode = ROUTE_TO_STOP[entryIndex];

          // 3. 다음 노드들 탐색 (Greedy Path Finding)
          for (int i = entryIndex + 1; i < ROUTE_TO_STOP.length; i++) {
              NLatLng nextNode = ROUTE_TO_STOP[i];
              
              double distToDest = _calculateDistance(lastAddedNode, finalDestination);
              double distToNextNode = _calculateDistance(lastAddedNode, nextNode);
              
              // 다음 노드보다 목적지가 더 가까우면 노드 연결 중단하고 바로 목적지로
              if (distToDest < distToNextNode) {
                  break; 
              }
              
              pathCoords.add(nextNode);
              lastAddedNode = nextNode;
          }
      } else {
          pathCoords.add(_currentUserPosition!);
      }
      
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
    if (pathCoords.isEmpty || pathCoords.last != finalDestination) {
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

  // ⭐️ [API 통합] 다음 출발 시간을 API에서 조회하고 가장 가까운 시간을 찾는 함수
  Future<void> _fetchBusData() async {
    // 로딩 상태는 처음에만 표시하거나 생략하여 깜빡임 방지 가능
    // setState(() { ... }); 

    try {
      final String stationNameKey = _stationNames[_selectedStationIndex];
      final String stationApiName = _stationApiNames[_selectedStationIndex]!; // ⭐️ API 이름 사용
      
      final String departureStation;
      final String arrivalStation;

      if (_isUserInsideSchool()) {
        // 학교 내부: 캠퍼스 출발 시간 (Campus -> Station)
        departureStation = '아산캠퍼스';
        arrivalStation = stationApiName; // ⭐️ API 이름 사용
      } else {
        // 학교 외부: 선택된 역 출발 시간 (Station -> Campus)
        departureStation = stationApiName; // ⭐️ API 이름 사용
        arrivalStation = '아산캠퍼스';
      }

      // API Call: Fetch ALL schedules for the day
      final response = await DioClient.instance.get(
        '/api/shuttle/schedules',
        queryParameters: {
          'dayType': '평일',
          'departure': departureStation,
          'arrival': arrivalStation,
          'limit': '0', // 전체 스케줄 요청
        },
      );

      String nextDepTime = "운행 종료";
      int diffMinutes = 0;
      bool foundNextDeparture = false;
      
      if (response.data != null && response.data['data'] != null && response.data['data'].isNotEmpty) {
        List<dynamic> schedules = response.data['data'];
        DateTime now = DateTime.now();

        for (var schedule in schedules) {
            String depTimeStr = schedule['departureTime'] ?? "운행 종료";

            if (depTimeStr != "운행 종료" && depTimeStr != "시간표 없음") {
                try {
                    final parts = depTimeStr.split(':');
                    final hour = int.parse(parts[0]);
                    final minute = int.parse(parts[1]);
                    
                    // Create a DateTime object for this specific departure time today
                    DateTime departureTime = DateTime(now.year, now.month, now.day, hour, minute);

                    // Check if this time is in the future (plus a 1-minute buffer)
                    if (departureTime.isAfter(now.subtract(const Duration(minutes: 1)))) {
                        nextDepTime = depTimeStr;
                        diffMinutes = departureTime.difference(now).inMinutes.ceil();
                        foundNextDeparture = true;
                        break; // Found the next one, stop iterating
                    }
                } catch (e) {
                    continue; 
                }
            }
        }
        
        if (!foundNextDeparture) {
            nextDepTime = "운행 종료";
        }

      } else if (response.data != null && response.data['data'].isEmpty) {
         nextDepTime = "운행 없음";
      }


      if (mounted) {
        setState(() {
          _nextDepartureTime = nextDepTime;
          _timeRemaining = (diffMinutes > 0) ? "$diffMinutes분" : "";
          _isLoading = false;
        });
      }

      if (_mapController != null && _currentUserPosition != null) {
        _updatePathToStop();
      }

    } catch (e) {
      if (mounted) {
         String errorMsg = "조회 실패";
         if (e is DioException) {
            errorMsg = "API 오류: ${e.response?.statusCode ?? '연결 실패'}";
         }
         setState(() {
            _nextDepartureTime = errorMsg;
            _timeRemaining = "";
            _isLoading = false;
         });
      }
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
    // ⭐️ UI 문구 결정 로직
    final String selectedStationName = _stationNames[_selectedStationIndex];
    // 학교 외부에 있으면 '아산캠퍼스행', 내부에 있으면 선택한 역 행
    final String directionText = _isUserInsideSchool() ? 
                                  '${selectedStationName}행' : 
                                  '아산캠퍼스행';
                                  
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
                    
                    // ⭐️ MapReady 시 카메라를 현재 위치 또는 선택된 역으로 이동
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
              
              Positioned(top: 16, right: 16, left: 16, child: _buildTopInfoCard(directionText)),
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
            InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const NoticeListScreen(),
                  ),
                );
              },
              child: const Icon(Icons.notifications_none, size: 28, color: Colors.grey),
            ),
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

  Widget _buildTopInfoCard(String directionText) {
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
              Text(directionText, style: const TextStyle(fontSize: 14, color: Colors.grey)),
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
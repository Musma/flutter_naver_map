import "dart:async";
import "dart:js_interop";
import "dart:ui_web" as ui_web;

import "package:flutter/widgets.dart";
import "package:web/web.dart" as web;

import "naver_maps_js_interop.dart";

/// 웹에서 네이버 지도를 표시하기 위한 View 위젯입니다.
class WebNaverMapView extends StatefulWidget {
  final Map<String, dynamic> creationParams;
  final void Function(int id, JSNaverMap jsMap) onMapCreated;

  const WebNaverMapView({
    super.key,
    required this.creationParams,
    required this.onMapCreated,
  });

  @override
  State<WebNaverMapView> createState() => _WebNaverMapViewState();
}

class _WebNaverMapViewState extends State<WebNaverMapView> {
  static int _nextViewId = 9000;
  late final int _viewId;
  late final String _viewType;
  JSNaverMap? _jsMap;
  bool _mapInitialized = false;
  bool _mapInitializationScheduled = false;

  web.HTMLDivElement? _mapDiv;

  @override
  void initState() {
    super.initState();
    _viewId = _nextViewId++;
    _viewType = "flutter_naver_map_web_$_viewId";

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final div = web.document.createElement("div") as web.HTMLDivElement;
      div.id = "naver_map_$_viewId";
      div.style.width = "100%";
      div.style.height = "100%";
      _mapDiv = div;
      _tryInitializeAfterBuild();
      return div;
    });
  }

  /// div가 DOM에 부착되고 나서 지도를 초기화합니다.
  /// HtmlElementView가 빌드되어 실제 DOM에 삽입된 후 호출됩니다.
  void _tryInitializeAfterBuild() {
    if (_mapInitialized || _mapDiv == null || _mapInitializationScheduled) return;

    _mapInitializationScheduled = true;

    void tryInit([int retries = 0]) {
      if (!mounted || _mapInitialized) return;
      final div = _mapDiv!;

      if (div.offsetWidth > 0 && div.offsetHeight > 0) {
        _initializeMap(div);
      } else if (retries < 50) {
        Future.delayed(const Duration(milliseconds: 100), () => tryInit(retries + 1));
      } else {
        // 최대 재시도 초과 — 크기 0이어도 초기화 시도
        debugPrint("[flutter_naver_map] div size is still 0 after retries, attempting init anyway");
        _initializeMap(div);
      }
    }

    // 첫 프레임 이후 시도
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapInitializationScheduled = false;
      if (!mounted || _mapInitialized || _mapDiv == null) {
        return;
      }
      tryInit();
    });
  }

  void _initializeMap(web.HTMLDivElement div) {
    if (_mapInitialized) return;
    _mapInitialized = true;

    try {
      final params = widget.creationParams;

      // 초기 카메라 위치 추출
      final initialCameraPosition = params["initialCameraPosition"];
      JSLatLng? center;
      double zoom = 11;

      if (initialCameraPosition is Map) {
        final target = initialCameraPosition["target"];
        if (target is Map) {
          final lat = (target["lat"] as num?)?.toDouble() ?? 37.5666102;
          final lng = (target["lng"] as num?)?.toDouble() ?? 126.9783881;
          center = createLatLng(lat, lng);
        }
        zoom = (initialCameraPosition["zoom"] as num?)?.toDouble() ?? 11;
      }

      center ??= createLatLng(37.5666102, 126.9783881);

      // 맵 옵션 구성
      final mapOptions = JSMapOptions(
        center: center,
        zoom: zoom.toJS,
        draggable: (params["scrollGesturesEnable"] as bool? ?? true).toJS,
        scrollWheel: (params["zoomGesturesEnable"] as bool? ?? true).toJS,
        pinchZoom: (params["zoomGesturesEnable"] as bool? ?? true).toJS,
        rotateEnabled: (params["rotateGesturesEnable"] as bool? ?? true).toJS,
        tiltEnabled: (params["tiltGesturesEnable"] as bool? ?? true).toJS,
        disableDoubleClickZoom: (!(params["zoomGesturesEnable"] as bool? ?? true)).toJS,
        logoControl: true.toJS,
        mapDataControl: true.toJS,
        scaleControl: false.toJS,
        zoomControl: false.toJS,
      );

      final jsMap = JSNaverMap(div, mapOptions);

      // 맵 타입 설정
      final mapTypeRaw = params["mapType"];
      if (mapTypeRaw is int) {
        final mapTypeId = _mapTypeIntToString(mapTypeRaw);
        if (mapTypeId != null) {
          jsMap.setMapTypeId(mapTypeId.toJS);
        }
      }
      _jsMap = jsMap;

      debugPrint("[flutter_naver_map] Web map initialized successfully (viewId: $_viewId)");
      widget.onMapCreated(_viewId, jsMap);
    } catch (e, st) {
      debugPrint("[flutter_naver_map] Failed to initialize web map: $e\n$st");
    }
  }

  String? _mapTypeIntToString(int mapType) {
    switch (mapType) {
      case 0:
        return "NORMAL";
      case 1:
        return "SATELLITE";
      case 2:
        return "TERRAIN";
      case 3:
        return "NORMAL"; // navi → NORMAL fallback
      case 4:
        return "HYBRID";
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    // 빌드 후 초기화를 트리거합니다.
    _tryInitializeAfterBuild();
    return HtmlElementView(viewType: _viewType);
  }

  @override
  void dispose() {
    _jsMap?.destroy();
    super.dispose();
  }
}

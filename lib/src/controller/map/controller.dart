part of "../../../flutter_naver_map.dart";

abstract class NaverMapController implements _NaverMapControlSender {
  static NaverMapController _createController(MethodChannel controllerChannel,
      {required int viewId, required NCameraPosition initialCameraPosition}) {
    final overlayController = _NOverlayControllerImpl(viewId: viewId);
    return _NaverMapControllerImpl(controllerChannel, overlayController, initialCameraPosition);
  }

  static NaverMapController _createWebController({
    required int viewId,
    required dynamic jsMap,
    required NCameraPosition initialCameraPosition,
    required void Function(NPoint point, NLatLng latLng) onMapTapped,
    required void Function(NCameraUpdateReason reason, bool animated, NCameraPosition position) onCameraChange,
    required void Function(NCameraPosition position) onCameraIdle,
  }) {
    return _NaverMapControllerWebImpl(
      viewId: viewId,
      jsMap: jsMap,
      initialCameraPosition: initialCameraPosition,
      onMapTapped: onMapTapped,
      onCameraChange: onCameraChange,
      onCameraIdle: onCameraIdle,
    );
  }

  void dispose();

  /// 이 프로퍼티는 지금 카메라가 보여주고 있는 위치를 나타냅니다.
  ///
  /// This property allows you to retrieve the position of the camera currently displayed on the map.
  ///
  /// It is currently in the **experimental stage**.
  ///
  /// For exact results, please use the [getCameraPosition] method.
  @experimental
  NCameraPosition get nowCameraPosition;

  Stream<OnCameraChangedParams> get nowCameraPositionStream;

  Stream<NLocationTrackingMode> get _locationTrackingModeStream;

  void _updateNowCameraPositionData(NCameraPosition position, NCameraUpdateReason? reason, bool isIdle);
}

class _NaverMapControllerImpl with NChannelWrapper implements NaverMapController {
  @override
  final MethodChannel channel;

  final _NOverlayController overlayController;

  @override
  NCameraPosition get nowCameraPosition => _nowCameraPositionStreamController.currentData.position;

  @override
  Stream<OnCameraChangedParams> get nowCameraPositionStream => _nowCameraPositionStreamController.stream;

  final NValueHoldHotStreamController<OnCameraChangedParams> _nowCameraPositionStreamController;

  _NaverMapControllerImpl(this.channel, this.overlayController, NCameraPosition initialCameraPosition)
      : _nowCameraPositionStreamController = NValueHoldHotStreamController(OnCameraChangedParams(
          position: initialCameraPosition,
          reason: NCameraUpdateReason.developer,
          isIdle: true,
        ));

  @override
  Future<bool> updateCamera(NCameraUpdate cameraUpdate) async {
    final rawIsCanceled = await invokeMethod("updateCamera", cameraUpdate);
    return rawIsCanceled as bool;
  }

  @override
  Future<void> cancelTransitions({NCameraUpdateReason reason = NCameraUpdateReason.developer}) async {
    await invokeMethod("cancelTransitions", reason);
  }

  @override
  Future<NCameraPosition> getCameraPosition() async {
    final rawCameraPosition = await invokeMethod("getCameraPosition");
    return NCameraPosition._fromMessageable(rawCameraPosition);
  }

  @override
  Future<NLatLngBounds> getContentBounds({bool withPadding = false}) async {
    final messageable = NMessageable.forOnce(withPadding);
    final rawLatLngBounds = await invokeMethod("getContentBounds", messageable);
    return NLatLngBounds.fromMessageable(rawLatLngBounds);
  }

  @override
  Future<List<NLatLng>> getContentRegion({bool withPadding = false}) async {
    final messageable = NMessageable.forOnce(withPadding);
    final rawLatLngs = await invokeMethod("getContentRegion", messageable).then((rawList) => rawList as List);
    return rawLatLngs.map(NLatLng.fromMessageable).toList();
  }

  @override
  NLocationOverlay getLocationOverlay() {
    if (overlayController.locationOverlay != null) {
      return overlayController.locationOverlay!;
    }
    final lo = NLocationOverlay._attachToMapWhenFirstUse(overlayController);
    overlayController.locationOverlay = lo;
    return lo;
  }

  @override
  Future<NLatLng> screenLocationToLatLng(NPoint point) {
    return invokeMethod("screenLocationToLatLng", point).then((rawLatLng) => NLatLng.fromMessageable(rawLatLng));
  }

  @override
  Future<NPoint> latLngToScreenLocation(NLatLng latLng) {
    return invokeMethod("latLngToScreenLocation", latLng).then((rawPoint) => NPoint._fromMessageable(rawPoint));
  }

  @override
  double getMeterPerDp() {
    return getMeterPerDpAtLatitude(latitude: nowCameraPosition.target.latitude, zoom: nowCameraPosition.zoom);
  }

  @override
  double getMeterPerDpAtLatitude({required double latitude, required double zoom}) {
    return MathUtil.calcMeterPerDp(latitude, zoom);
  }

  @override
  Future<List<NPickableInfo>> pickAll(NPoint point, {double radius = 0}) async {
    final messageable = NMessageable.forOnceWithMap({"point": point, "radius": radius});

    final rawList = await invokeMethod("pickAll", messageable).then((raw) => raw as List);
    final pickableInfoList = rawList.map(NPickableInfo._fromMessageable).toList();

    return pickableInfoList;
  }

  @override
  Future<File> takeSnapshot({
    @Deprecated("showControls is not supported from 1.4.0") bool showControls = false,
    int compressQuality = 80,
  }) async {
    final messageable = NMessageable.forOnceWithMap({
      "showControls": showControls, // deprecated
      "compressQuality": compressQuality,
    });
    final path = await invokeMethod("takeSnapshot", messageable).then((raw) => raw as String);
    return createFile(path);
  }

  final _trackingModeStreamController = NValueHoldHotStreamController(NLocationTrackingMode.none);

  @override
  Stream<NLocationTrackingMode> get _locationTrackingModeStream => _trackingModeStreamController.stream;

  @override
  NLocationTrackingMode get locationTrackingMode => _trackingModeStreamController.currentData;

  @override
  void setLocationTrackingMode(NLocationTrackingMode mode) {
    if (locationTrackingMode == mode) return; // guard distinct
    final oldMode = locationTrackingMode;
    _trackingModeStreamController.add(mode);
    myLocationTracker._onChangeTrackingMode(getLocationOverlay(), this, mode, oldMode);
  }

  @override
  NMyLocationTracker myLocationTracker = NDefaultMyLocationTracker();

  @override
  void setMyLocationTracker(NMyLocationTracker tracker) {
    myLocationTracker = tracker;
  }

  @override
  Future<void> addOverlay(NAddableOverlay overlay) {
    return addOverlayAll({overlay});
  }

  @override
  Future<void> addOverlayAll(Set<NAddableOverlay> overlays) async {
    final addTaskFuture = invokeMethodWithIterable("addOverlayAll", overlays);
    _connectOverlayControllerOnOverlays(overlays);
    await addTaskFuture;
  }

  void _connectOverlayControllerOnOverlays(Iterable<NAddableOverlay> overlays) {
    for (final overlay in overlays) {
      overlay._addedOnMap(overlayController);
    }
  }

  @override
  Future<void> deleteOverlay(NOverlayInfo info) async {
    assert(info.type != NOverlayType.locationOverlay);
    await invokeMethod("deleteOverlay", info);
    overlayController.deleteWithInfo(info);
  }

  @override
  Future<void> clearOverlays({NOverlayType? type}) async {
    assert(type != NOverlayType.locationOverlay);
    overlayController.clear(type);
    await invokeMethod("clearOverlays", type);
  }

  @override
  Future<void> forceRefresh() async {
    await invokeMethod("forceRefresh");
  }

  /*
    --- internal methods ---
   */

  @override
  Future<void> openMapOpenSourceLicense() async {
    await invokeMethod("openMapOpenSourceLicense");
  }

  @override
  Future<void> openLegend() async {
    await invokeMethod("openLegend");
  }

  @override
  Future<void> openLegalNotice() async {
    await invokeMethod("openLegalNotice");
  }

  /*
    --- private methods ---
  */
  @override
  Future<void> _updateOptions(NaverMapViewOptions options) {
    return invokeMethod("updateOptions", options);
  }

  @override
  Future<void> _updateClusteringOptions(NaverMapClusteringOptions options) {
    return invokeMethod("updateClusteringOptions", options);
  }

  @override
  void _updateNowCameraPositionData(NCameraPosition position, NCameraUpdateReason? reason, bool isIdle) {
    _nowCameraPositionStreamController.add(OnCameraChangedParams(
        position: position, reason: reason ?? _nowCameraPositionStreamController.currentData.reason, isIdle: isIdle));
  }

  /*
    --- low level methods ---
  */

  @override
  String toString() => "NaverMapController(channel: ${channel.name})";

  @override
  void dispose() {
    myLocationTracker._stopTracking();
    _nowCameraPositionStreamController.close();
    _trackingModeStreamController.close();
    overlayController.disposeChannel();
  }
}

/// 웹 플랫폼용 NaverMapController 구현체.
/// MethodChannel 대신 JS interop을 통해 네이버 지도 JS SDK를 직접 조작합니다.
class _NaverMapControllerWebImpl implements NaverMapController {
  final int viewId;
  final dynamic _jsMap;
  final Map<NOverlayInfo, dynamic> _jsOverlays = {};
  late final _NOverlayControllerWebImpl _webOverlayController;

  final NValueHoldHotStreamController<OnCameraChangedParams> _nowCameraPositionStreamController;

  final _trackingModeStreamController = NValueHoldHotStreamController(NLocationTrackingMode.none);

  _NaverMapControllerWebImpl({
    required this.viewId,
    required dynamic jsMap,
    required NCameraPosition initialCameraPosition,
    required void Function(NPoint point, NLatLng latLng) onMapTapped,
    required void Function(NCameraUpdateReason reason, bool animated, NCameraPosition position) onCameraChange,
    required void Function(NCameraPosition position) onCameraIdle,
  })  : _jsMap = jsMap,
        _nowCameraPositionStreamController = NValueHoldHotStreamController(OnCameraChangedParams(
          position: initialCameraPosition,
          reason: NCameraUpdateReason.developer,
          isIdle: true,
        )) {
    web_ops.setupWebMapEventListeners(
      jsMap: _jsMap,
      onMapTapped: (lat, lng, x, y) {
        onMapTapped(NPoint(x, y), NLatLng(lat, lng));
      },
      onCameraChange: (lat, lng, zoom, tilt, bearing, animated) {
        final position = NCameraPosition(
          target: NLatLng(lat, lng),
          zoom: zoom,
          tilt: tilt,
          bearing: bearing,
        );
        _updateNowCameraPositionData(position, NCameraUpdateReason.gesture, false);
        onCameraChange(NCameraUpdateReason.gesture, animated, position);
      },
      onCameraIdle: (lat, lng, zoom, tilt, bearing) {
        final position = NCameraPosition(
          target: NLatLng(lat, lng),
          zoom: zoom,
          tilt: tilt,
          bearing: bearing,
        );
        _updateNowCameraPositionData(position, null, true);
        onCameraIdle(position);
      },
    );
    _webOverlayController = _NOverlayControllerWebImpl(
      viewId: viewId,
      jsOverlayRefs: _jsOverlays,
    );
  }

  @override
  @experimental
  NCameraPosition get nowCameraPosition => _nowCameraPositionStreamController.currentData.position;

  @override
  Stream<OnCameraChangedParams> get nowCameraPositionStream => _nowCameraPositionStreamController.stream;

  @override
  Stream<NLocationTrackingMode> get _locationTrackingModeStream => _trackingModeStreamController.stream;

  @override
  void _updateNowCameraPositionData(NCameraPosition position, NCameraUpdateReason? reason, bool isIdle) {
    _nowCameraPositionStreamController.add(OnCameraChangedParams(
        position: position, reason: reason ?? _nowCameraPositionStreamController.currentData.reason, isIdle: isIdle));
  }

  @override
  Future<bool> updateCamera(NCameraUpdate cameraUpdate) async {
    final payload = cameraUpdate.toNPayload().map;

    // bounds가 있으면 fitBounds 사용
    final boundsData = payload["bounds"];
    if (boundsData is Map) {
      final sw = boundsData["southWest"];
      final ne = boundsData["northEast"];
      if (sw is Map && ne is Map) {
        web_ops.webFitBounds(_jsMap, (sw["lat"] as num).toDouble(), (sw["lng"] as num).toDouble(),
            (ne["lat"] as num).toDouble(), (ne["lng"] as num).toDouble());
        return false;
      }
    }

    final target = payload["target"];
    double? lat, lng, zoom;

    if (target is Map) {
      lat = (target["lat"] as num?)?.toDouble();
      lng = (target["lng"] as num?)?.toDouble();
    }
    zoom = (payload["zoom"] as num?)?.toDouble();

    final animate = payload["animation"] != null && payload["animation"] != 0;

    web_ops.webUpdateCamera(_jsMap, lat: lat, lng: lng, zoom: zoom, animate: animate);
    return false;
  }

  @override
  Future<void> cancelTransitions({NCameraUpdateReason reason = NCameraUpdateReason.developer}) async {
    // JS SDK에서 직접적인 애니메이션 취소 API 없음
  }

  @override
  Future<NCameraPosition> getCameraPosition() async {
    final data = web_ops.webGetCameraPosition(_jsMap);
    return NCameraPosition(
      target: NLatLng(data["lat"]!, data["lng"]!),
      zoom: data["zoom"]!,
      tilt: data["tilt"]!,
      bearing: data["bearing"]!,
    );
  }

  @override
  Future<NLatLngBounds> getContentBounds({bool withPadding = false}) async {
    final data = web_ops.webGetContentBounds(_jsMap);
    return NLatLngBounds(
      southWest: NLatLng(data["swLat"]!, data["swLng"]!),
      northEast: NLatLng(data["neLat"]!, data["neLng"]!),
    );
  }

  @override
  Future<List<NLatLng>> getContentRegion({bool withPadding = false}) async {
    final bounds = await getContentBounds(withPadding: withPadding);
    return [
      bounds.southWest,
      NLatLng(bounds.northEast.latitude, bounds.southWest.longitude),
      bounds.northEast,
      NLatLng(bounds.southWest.latitude, bounds.northEast.longitude),
    ];
  }

  @override
  NLocationOverlay getLocationOverlay() {
    throw UnsupportedError("LocationOverlay is not supported on web");
  }

  @override
  Future<NLatLng> screenLocationToLatLng(NPoint point) async {
    final data = web_ops.webScreenToLatLng(_jsMap, point.x, point.y);
    return NLatLng(data["lat"]!, data["lng"]!);
  }

  @override
  Future<NPoint> latLngToScreenLocation(NLatLng latLng) async {
    final data = web_ops.webLatLngToScreen(_jsMap, latLng.latitude, latLng.longitude);
    return NPoint(data["x"]!, data["y"]!);
  }

  @override
  double getMeterPerDp() {
    return getMeterPerDpAtLatitude(latitude: nowCameraPosition.target.latitude, zoom: nowCameraPosition.zoom);
  }

  @override
  double getMeterPerDpAtLatitude({required double latitude, required double zoom}) {
    return MathUtil.calcMeterPerDp(latitude, zoom);
  }

  @override
  Future<List<NPickableInfo>> pickAll(NPoint point, {double radius = 0}) async {
    // 웹에서는 pickAll을 지원하지 않습니다.
    return [];
  }

  @override
  Future<File> takeSnapshot({
    @Deprecated("showControls is not supported from 1.4.0") bool showControls = false,
    int compressQuality = 80,
  }) async {
    throw UnsupportedError("takeSnapshot is not supported on web");
  }

  @override
  NLocationTrackingMode get locationTrackingMode => _trackingModeStreamController.currentData;

  @override
  void setLocationTrackingMode(NLocationTrackingMode mode) {
    // 웹에서는 위치 추적 모드를 지원하지 않습니다.
  }

  @override
  NMyLocationTracker myLocationTracker = NDefaultMyLocationTracker();

  @override
  void setMyLocationTracker(NMyLocationTracker tracker) {
    myLocationTracker = tracker;
  }

  @override
  Future<void> addOverlay(NAddableOverlay overlay) {
    return addOverlayAll({overlay});
  }

  @override
  Future<void> addOverlayAll(Set<NAddableOverlay> overlays) async {
    for (final overlay in overlays) {
      // JS Marker 생성자 내부에서 SDK 이벤트가 발생하여
      // Dart 콜백이 호출될 수 있으므로, _addedOnMap을 먼저 호출하여
      // _isAdded = true 상태를 보장합니다.
      overlay._addedOnMap(_webOverlayController);

      final jsOverlay = _createJsOverlay(overlay);
      if (jsOverlay != null) {
        _jsOverlays[overlay.info] = jsOverlay;

        // 웹에서는 항상 JS 클릭 리스너를 등록합니다.
        web_ops.webSetOverlayClickListener(jsOverlay, () {
          overlay._handle("onTap");
        });
      }
    }
  }

  dynamic _createJsOverlay(NAddableOverlay overlay) {
    final payload = overlay.toNPayload().map;

    switch (overlay.info.type) {
      case NOverlayType.marker:
        final pos = payload["position"];
        final iconData = payload["icon"];
        String? iconUrl;
        double? width, height;
        if (iconData is Map) {
          iconUrl = iconData["path"] as String?;
          // Size는 NMessageable이 아니므로 Dart Size 객체로 남아있음
          final sizeData = payload["size"];
          if (sizeData is Size) {
            width = sizeData.width;
            height = sizeData.height;
          } else if (sizeData is Map) {
            width = (sizeData["width"] as num?)?.toDouble();
            height = (sizeData["height"] as num?)?.toDouble();
          }
          if (width == 0 && height == 0) {
            // autoSize: 아이콘의 sourceSize 사용
            final srcW = (iconData["sourceWidth"] as num?)?.toDouble();
            final srcH = (iconData["sourceHeight"] as num?)?.toDouble();
            if (srcW != null && srcH != null && srcW > 0 && srcH > 0) {
              width = srcW;
              height = srcH;
            } else {
              width = null;
              height = null;
            }
          }
        }
        final anchorData = payload["anchor"];
        double? anchorX, anchorY;
        if (anchorData is NPoint) {
          anchorX = anchorData.x;
          anchorY = anchorData.y;
        } else if (anchorData is Map) {
          anchorX = (anchorData["x"] as num?)?.toDouble();
          anchorY = (anchorData["y"] as num?)?.toDouble();
        }
        return web_ops.webAddMarker(_jsMap,
            id: overlay.info.id,
            lat: (pos["lat"] as num).toDouble(),
            lng: (pos["lng"] as num).toDouble(),
            iconUrl: iconUrl,
            width: width,
            height: height,
            anchorX: anchorX,
            anchorY: anchorY,
            alpha: (payload["alpha"] as num?)?.toDouble() ?? 1.0,
            angle: (payload["angle"] as num?)?.toDouble() ?? 0,
            visible: payload["isVisible"] as bool? ?? true,
            zIndex: payload["zIndex"] as int? ?? 0,
            clickable: payload["hasOnTapListener"] as bool? ?? false);

      case NOverlayType.polylineOverlay:
        final coordsList = payload["coords"] as List;
        final coords = coordsList.map((c) => [(c["lat"] as num).toDouble(), (c["lng"] as num).toDouble()]).toList();
        final color = payload["color"] as int? ?? 0xFF000000;
        return web_ops.webAddPolyline(_jsMap,
            id: overlay.info.id,
            coords: coords,
            color: color,
            width: (payload["width"] as num?)?.toDouble() ?? 1.0,
            visible: payload["isVisible"] as bool? ?? true,
            zIndex: payload["zIndex"] as int? ?? 0,
            clickable: payload["hasOnTapListener"] as bool? ?? false);

      case NOverlayType.polygonOverlay:
        final coordsList = payload["coords"] as List;
        final coords = coordsList.map((c) => [(c["lat"] as num).toDouble(), (c["lng"] as num).toDouble()]).toList();
        final color = payload["color"] as int? ?? 0xFF000000;
        final outlineColor = payload["outlineColor"] as int? ?? 0xFF000000;
        return web_ops.webAddPolygon(_jsMap,
            id: overlay.info.id,
            coords: coords,
            color: color,
            outlineColor: outlineColor,
            outlineWidth: (payload["outlineWidth"] as num?)?.toDouble() ?? 1.0,
            visible: payload["isVisible"] as bool? ?? true,
            zIndex: payload["zIndex"] as int? ?? 0,
            clickable: payload["hasOnTapListener"] as bool? ?? false);

      case NOverlayType.circleOverlay:
        final center = payload["center"];
        final color = payload["color"] as int? ?? 0xFF000000;
        final outlineColor = payload["outlineColor"] as int? ?? 0xFF000000;
        return web_ops.webAddCircle(_jsMap,
            id: overlay.info.id,
            lat: (center["lat"] as num).toDouble(),
            lng: (center["lng"] as num).toDouble(),
            radius: (payload["radius"] as num).toDouble(),
            color: color,
            outlineColor: outlineColor,
            outlineWidth: (payload["outlineWidth"] as num?)?.toDouble() ?? 1.0,
            visible: payload["isVisible"] as bool? ?? true,
            zIndex: payload["zIndex"] as int? ?? 0,
            clickable: payload["hasOnTapListener"] as bool? ?? false);

      case NOverlayType.infoWindow:
        final text = payload["text"] as String? ?? "";
        final pos = payload["position"];
        double? lat, lng;
        if (pos is Map) {
          lat = (pos["lat"] as num?)?.toDouble();
          lng = (pos["lng"] as num?)?.toDouble();
        }
        return web_ops.webAddInfoWindow(_jsMap,
            id: overlay.info.id, content: text, lat: lat, lng: lng, zIndex: payload["zIndex"] as int? ?? 0);

      case NOverlayType.groundOverlay:
        final boundsData = payload["bounds"];
        final imageData = payload["image"];
        if (boundsData is Map && imageData is Map) {
          final swData = boundsData["southWest"];
          final neData = boundsData["northEast"];
          return web_ops.webAddGroundOverlay(_jsMap,
              id: overlay.info.id,
              imageUrl: imageData["path"] as String? ?? "",
              swLat: (swData["lat"] as num).toDouble(),
              swLng: (swData["lng"] as num).toDouble(),
              neLat: (neData["lat"] as num).toDouble(),
              neLng: (neData["lng"] as num).toDouble(),
              alpha: (payload["alpha"] as num?)?.toDouble() ?? 1.0);
        }
        return null;

      case NOverlayType.pathOverlay:
      case NOverlayType.multipartPathOverlay:
      case NOverlayType.arrowheadPathOverlay:
        // Path 오버레이를 Polyline으로 근사 구현
        final coordsList = payload["coords"] as List?;
        if (coordsList != null) {
          final coords = coordsList.map((c) => [(c["lat"] as num).toDouble(), (c["lng"] as num).toDouble()]).toList();
          final color = payload["color"] as int? ?? 0xFF000000;
          return web_ops.webAddPolyline(_jsMap,
              id: overlay.info.id,
              coords: coords,
              color: color,
              width: (payload["width"] as num?)?.toDouble() ?? 3.0,
              visible: payload["isVisible"] as bool? ?? true,
              zIndex: payload["zIndex"] as int? ?? 0,
              clickable: payload["hasOnTapListener"] as bool? ?? false);
        }
        return null;

      default:
        return null;
    }
  }

  @override
  Future<void> deleteOverlay(NOverlayInfo info) async {
    assert(info.type != NOverlayType.locationOverlay);
    final jsOverlay = _jsOverlays.remove(info);
    if (jsOverlay != null) {
      web_ops.webRemoveOverlay(jsOverlay);
    }
    _webOverlayController.deleteWithInfo(info);
  }

  @override
  Future<void> clearOverlays({NOverlayType? type}) async {
    assert(type != NOverlayType.locationOverlay);
    final keysToRemove = <NOverlayInfo>[];
    for (final entry in _jsOverlays.entries) {
      if (type == null || entry.key.type == type) {
        web_ops.webRemoveOverlay(entry.value);
        keysToRemove.add(entry.key);
      }
    }
    for (final key in keysToRemove) {
      _jsOverlays.remove(key);
    }
    _webOverlayController.clear(type);
  }

  @override
  Future<void> forceRefresh() async {
    // JS SDK에서는 별도의 새로고침이 필요하지 않음
  }

  @override
  Future<void> openMapOpenSourceLicense() async {
    // 웹에서는 지원하지 않음
  }

  @override
  Future<void> openLegend() async {
    // 웹에서는 지원하지 않음
  }

  @override
  Future<void> openLegalNotice() async {
    // 웹에서는 지원하지 않음
  }

  @override
  Future<void> _updateOptions(NaverMapViewOptions options) async {
    final payload = options.toNPayload().map;
    final jsOptions = <String, dynamic>{};

    if (payload["scrollGesturesEnable"] != null) {
      jsOptions["draggable"] = payload["scrollGesturesEnable"];
    }
    if (payload["zoomGesturesEnable"] != null) {
      jsOptions["scrollWheel"] = payload["zoomGesturesEnable"];
      jsOptions["pinchZoom"] = payload["zoomGesturesEnable"];
      jsOptions["disableDoubleClickZoom"] = !(payload["zoomGesturesEnable"] as bool);
    }
    if (payload["rotateGesturesEnable"] != null) {
      jsOptions["rotateEnabled"] = payload["rotateGesturesEnable"];
    }
    if (payload["tiltGesturesEnable"] != null) {
      jsOptions["tiltEnabled"] = payload["tiltGesturesEnable"];
    }

    if (jsOptions.isNotEmpty) {
      web_ops.webSetMapOptions(_jsMap, jsOptions);
    }

    // 맵 타입 변경
    final mapType = payload["mapType"];
    if (mapType is int) {
      final typeStr = _mapTypeIntToString(mapType);
      if (typeStr != null) {
        web_ops.webSetMapOptions(_jsMap, {"mapTypeId": typeStr.toLowerCase()});
      }
    } else if (mapType is String) {
      final typeStr = _mapTypeString(mapType.toLowerCase());
      if (typeStr != null) {
        web_ops.webSetMapOptions(_jsMap, {"mapTypeId": typeStr.toLowerCase()});
      }
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
        return "NORMAL";
      case 4:
        return "HYBRID";
      default:
        return null;
    }
  }

  String? _mapTypeString(String mapType) {
    switch (mapType) {
      case "basic":
        return "normal";
      case "navi":
        return "normal";
      case "satellite":
        return "satellite";
      case "hybrid":
      case "navihybrid":
        return "hybrid";
      case "terrain":
        return "terrain";
      case "none":
        return "normal";
      default:
        return null;
    }
  }

  @override
  Future<void> _updateClusteringOptions(NaverMapClusteringOptions options) async {
    // 웹에서는 클러스터링을 아직 지원하지 않습니다.
  }

  @override
  String toString() => "NaverMapController.web(viewId: $viewId)";

  @override
  void dispose() {
    myLocationTracker._stopTracking();
    _nowCameraPositionStreamController.close();
    _trackingModeStreamController.close();
    clearOverlays();
    _webOverlayController.clear(null);
  }
}

/// 웹 플랫폼용 오버레이 컨트롤러.
/// MethodChannel 없이 JS 오버레이 속성 변경을 처리합니다.
class _NOverlayControllerWebImpl extends _NOverlayController {
  @override
  final int viewId;

  @override
  late final MethodChannel channel;

  final Map<NOverlayInfo, dynamic> _jsOverlayRefs;
  final Map<NOverlayInfo, NOverlay> _overlays = {};

  _NOverlayControllerWebImpl({
    required this.viewId,
    required Map<NOverlayInfo, dynamic> jsOverlayRefs,
  }) : _jsOverlayRefs = jsOverlayRefs {
    // MethodChannel 없이 isChannelInitialized을 true로 설정
    isChannelInitialized = true;
  }

  @override
  void add(NOverlayInfo info, NOverlay overlay) {
    _overlays[info] = overlay;
  }

  @override
  void deleteWithInfo(NOverlayInfo info) {
    _overlays.remove(info);
  }

  @override
  void clear(NOverlayType? type) {
    if (type != null) {
      _overlays.removeWhere((info, _) => info.type == type);
    } else {
      _overlays.clear();
    }
  }

  @override
  Future<T?> invokeMethod<T>(String funcName, [NMessageable? arg]) async {
    // funcName 형식: "#TYPE#id#methodName"
    // 웹에서는 속성 변경 요청을 JS 오버레이에 반영합니다.
    final query = _NOverlayQuery.fromQuery(funcName);
    final jsOverlay = _jsOverlayRefs[query.info];
    if (jsOverlay == null) return null;

    final methodName = query.methodName;
    final value = arg?.payload;

    switch (methodName) {
      case "isVisible":
        if (value is bool) web_ops.webSetOverlayVisible(jsOverlay, value);
        break;
      case "zIndex" || "globalZIndex":
        if (value is int) web_ops.webSetOverlayZIndex(jsOverlay, value);
        if (value is double) web_ops.webSetOverlayZIndex(jsOverlay, value.toInt());
        break;
      case "position":
        if (value is Map) {
          web_ops.webSetMarkerPosition(jsOverlay, (value["lat"] as num).toDouble(), (value["lng"] as num).toDouble());
        }
        break;
      case "icon":
        if (value is Map) {
          final iconUrl = value["path"] as String?;
          final srcW = (value["sourceWidth"] as num?)?.toDouble();
          final srcH = (value["sourceHeight"] as num?)?.toDouble();
          web_ops.webSetMarkerIcon(jsOverlay, iconUrl, srcW, srcH);
        }
        break;
      case "hasOnTapListener":
        // 클릭 리스너는 addOverlayAll에서 이미 등록됨 - 무시
        break;
      case "performClick":
        final overlay = _overlays[query.info];
        if (overlay != null) overlay._handle("onTap");
        break;
    }

    return null;
  }
}

import "dart:js_interop";
import "dart:js_interop_unsafe";

import "naver_maps_js_interop.dart";

void setupWebMapEventListeners({
  required dynamic jsMap,
  required void Function(double lat, double lng, double x, double y) onMapTapped,
  required void Function(double lat, double lng, double zoom, double tilt, double bearing, bool animated)
      onCameraChange,
  required void Function(double lat, double lng, double zoom, double tilt, double bearing) onCameraIdle,
}) {
  final map = jsMap as JSNaverMap;

  naverMapsEvent.addListener(
    map as JSObject,
    "click".toJS,
    ((JSObject e) {
      final coord = e.getProperty<JSLatLng>("coord".toJS);
      final point = e.getProperty<JSPoint>("offset".toJS);
      onMapTapped(
        coord.lat().toDartDouble,
        coord.lng().toDartDouble,
        point.x.toDartDouble,
        point.y.toDartDouble,
      );
    }).toJS,
  );

  naverMapsEvent.addListener(
    map as JSObject,
    "bounds_changed".toJS,
    (() {
      final center = map.getCenter();
      final zoom = map.getZoom().toDartDouble;
      onCameraChange(
        center.lat().toDartDouble,
        center.lng().toDartDouble,
        zoom,
        0, // tilt - JS SDK에서 직접 지원하지 않음
        0, // bearing
        false,
      );
    }).toJS,
  );

  naverMapsEvent.addListener(
    map as JSObject,
    "idle".toJS,
    (() {
      final center = map.getCenter();
      final zoom = map.getZoom().toDartDouble;
      onCameraIdle(
        center.lat().toDartDouble,
        center.lng().toDartDouble,
        zoom,
        0,
        0,
      );
    }).toJS,
  );
}

Map<String, double> webGetCameraPosition(dynamic jsMap) {
  final map = jsMap as JSNaverMap;
  final center = map.getCenter();
  return {
    "lat": center.lat().toDartDouble,
    "lng": center.lng().toDartDouble,
    "zoom": map.getZoom().toDartDouble,
    "tilt": 0,
    "bearing": 0,
  };
}

Map<String, double> webGetContentBounds(dynamic jsMap) {
  final map = jsMap as JSNaverMap;
  final bounds = map.getBounds();
  final sw = bounds.getSW();
  final ne = bounds.getNE();
  return {
    "swLat": sw.lat().toDartDouble,
    "swLng": sw.lng().toDartDouble,
    "neLat": ne.lat().toDartDouble,
    "neLng": ne.lng().toDartDouble,
  };
}

Map<String, double> webScreenToLatLng(dynamic jsMap, double x, double y) {
  final map = jsMap as JSNaverMap;
  final projection = map.getProjection();
  final coord = projection.fromPagePixelToCoord(createPoint(x, y));
  return {
    "lat": coord.lat().toDartDouble,
    "lng": coord.lng().toDartDouble,
  };
}

Map<String, double> webLatLngToScreen(dynamic jsMap, double lat, double lng) {
  final map = jsMap as JSNaverMap;
  final projection = map.getProjection();
  final point = projection.fromCoordToPagePixel(createLatLng(lat, lng));
  return {
    "x": point.x.toDartDouble,
    "y": point.y.toDartDouble,
  };
}

void webUpdateCamera(
  dynamic jsMap, {
  double? lat,
  double? lng,
  double? zoom,
  bool animate = false,
}) {
  final map = jsMap as JSNaverMap;
  if (lat != null && lng != null) {
    final coord = createLatLng(lat, lng);
    if (animate) {
      if (zoom != null) {
        map.morph(coord, zoom.toJS);
      } else {
        map.panTo(coord);
      }
    } else {
      map.setCenter(coord);
      if (zoom != null) {
        map.setZoom(zoom.toJS);
      }
    }
  } else if (zoom != null) {
    map.setZoom(zoom.toJS, animate.toJS);
  }
}

void webFitBounds(dynamic jsMap, double swLat, double swLng, double neLat, double neLng) {
  final map = jsMap as JSNaverMap;
  final bounds = createLatLngBounds(
    createLatLng(swLat, swLng),
    createLatLng(neLat, neLng),
  );
  map.fitBounds(bounds as JSObject);
}

void webSetMapOptions(dynamic jsMap, Map<String, dynamic> options) {
  final map = jsMap as JSNaverMap;
  for (final entry in options.entries) {
    final key = entry.key;
    final value = entry.value;

    if (value is bool) {
      map.setOptions(key.toJS, value.toJS);
    } else if (value is int) {
      map.setOptions(key.toJS, value.toDouble().toJS);
    } else if (value is double) {
      map.setOptions(key.toJS, value.toJS);
    } else if (value is String) {
      map.setOptions(key.toJS, value.toJS);
    }
    if (key == "mapTypeId") {
      map.setMapTypeId(value.toString().toJS);
    }
  }
}

dynamic webAddMarker(
  dynamic jsMap, {
  required String id,
  required double lat,
  required double lng,
  String? iconUrl,
  double? width,
  double? height,
  double? anchorX,
  double? anchorY,
  double alpha = 1.0,
  double angle = 0,
  bool visible = true,
  int zIndex = 0,
  bool clickable = false,
}) {
  final map = jsMap as JSNaverMap;
  // map 옵션 없이 생성하여 생성자 내부 이벤트를 방지합니다.
  // setMap은 addOverlayAll에서 _addedOnMap 이후에 별도 호출됩니다.
  final options = JSMarkerOptions(
    position: createLatLng(lat, lng),
    visible: visible.toJS,
    zIndex: zIndex.toDouble().toJS,
    clickable: true.toJS,
  );

  if (iconUrl != null) {
    JSObject icon;
    if (width != null && height != null) {
      icon = JSImageIcon(
        url: iconUrl.toJS,
        scaledSize: createSize(width, height),
        anchor: anchorX != null && anchorY != null ? createPoint(anchorX * width, anchorY * height) : null,
      ) as JSObject;
    } else {
      icon = JSImageIcon(url: iconUrl.toJS) as JSObject;
    }
    (options as JSObject).setProperty("icon".toJS, icon);
  }

  final marker = JSMarker(options);
  marker.setMap(map);
  return marker;
}

dynamic webAddPolyline(
  dynamic jsMap, {
  required String id,
  required List<List<double>> coords,
  required int color,
  double width = 1.0,
  bool visible = true,
  int zIndex = 0,
  bool clickable = false,
}) {
  final map = jsMap as JSNaverMap;
  final path = coords.map((c) => createLatLng(c[0], c[1])).toList().toJS;

  final polyline = JSPolyline(JSPolylineOptions(
    path: path,
    strokeColor: colorToHexString(color).toJS,
    strokeOpacity: colorToOpacity(color).toJS,
    strokeWeight: width.toJS,
    visible: visible.toJS,
    zIndex: zIndex.toDouble().toJS,
    clickable: clickable.toJS,
  ));
  polyline.setMap(map);
  return polyline;
}

dynamic webAddPolygon(
  dynamic jsMap, {
  required String id,
  required List<List<double>> coords,
  required int color,
  required int outlineColor,
  double outlineWidth = 1.0,
  bool visible = true,
  int zIndex = 0,
  bool clickable = false,
}) {
  final map = jsMap as JSNaverMap;
  final paths = [coords.map((c) => createLatLng(c[0], c[1])).toList().toJS].toJS;

  final polygon = JSPolygon(JSPolygonOptions(
    paths: paths,
    fillColor: colorToHexString(color).toJS,
    fillOpacity: colorToOpacity(color).toJS,
    strokeColor: colorToHexString(outlineColor).toJS,
    strokeOpacity: colorToOpacity(outlineColor).toJS,
    strokeWeight: outlineWidth.toJS,
    visible: visible.toJS,
    zIndex: zIndex.toDouble().toJS,
    clickable: clickable.toJS,
  ));
  polygon.setMap(map);
  return polygon;
}

dynamic webAddCircle(
  dynamic jsMap, {
  required String id,
  required double lat,
  required double lng,
  required double radius,
  required int color,
  required int outlineColor,
  double outlineWidth = 1.0,
  bool visible = true,
  int zIndex = 0,
  bool clickable = false,
}) {
  final map = jsMap as JSNaverMap;
  final circle = JSCircle(JSCircleOptions(
    center: createLatLng(lat, lng),
    radius: radius.toJS,
    fillColor: colorToHexString(color).toJS,
    fillOpacity: colorToOpacity(color).toJS,
    strokeColor: colorToHexString(outlineColor).toJS,
    strokeOpacity: colorToOpacity(outlineColor).toJS,
    strokeWeight: outlineWidth.toJS,
    visible: visible.toJS,
    zIndex: zIndex.toDouble().toJS,
    clickable: clickable.toJS,
  ));
  circle.setMap(map);
  return circle;
}

dynamic webAddInfoWindow(
  dynamic jsMap, {
  required String id,
  required String content,
  double? lat,
  double? lng,
  dynamic anchorMarker,
  int zIndex = 0,
}) {
  final map = jsMap as JSNaverMap;
  final infoWindow = JSInfoWindow(JSInfoWindowOptions(
    content: content.toJS,
    zIndex: zIndex.toDouble().toJS,
  ));

  if (anchorMarker != null) {
    infoWindow.open(map, anchorMarker as JSObject);
  } else if (lat != null && lng != null) {
    infoWindow.setPosition(createLatLng(lat, lng));
    infoWindow.open(map);
  }

  return infoWindow;
}

dynamic webAddGroundOverlay(
  dynamic jsMap, {
  required String id,
  required String imageUrl,
  required double swLat,
  required double swLng,
  required double neLat,
  required double neLng,
  double alpha = 1.0,
  bool visible = true,
}) {
  final map = jsMap as JSNaverMap;
  final bounds = createLatLngBounds(
    createLatLng(swLat, swLng),
    createLatLng(neLat, neLng),
  );
  final groundOverlay = JSGroundOverlay(
    imageUrl.toJS,
    bounds,
    JSGroundOverlayOptions(
      opacity: alpha.toJS,
    ),
  );
  groundOverlay.setMap(map);
  return groundOverlay;
}

void webRemoveOverlay(dynamic jsOverlay) {
  final obj = jsOverlay as JSObject;
  if (obj.hasProperty("setMap".toJS).toDart) {
    obj.callMethodVarArgs("setMap".toJS, <JSAny?>[null]);
  } else if (obj.hasProperty("close".toJS).toDart) {
    obj.callMethodVarArgs("close".toJS, <JSAny?>[]);
  }
}

void webSetOverlayVisible(dynamic jsOverlay, bool visible) {
  final obj = jsOverlay as JSObject;
  if (obj.hasProperty("setVisible".toJS).toDart) {
    obj.callMethodVarArgs("setVisible".toJS, <JSAny?>[visible.toJS]);
  }
}

void webSetOverlayZIndex(dynamic jsOverlay, int zIndex) {
  final obj = jsOverlay as JSObject;
  if (obj.hasProperty("setZIndex".toJS).toDart) {
    obj.callMethodVarArgs("setZIndex".toJS, <JSAny?>[zIndex.toDouble().toJS]);
  }
}

void webSetMarkerPosition(dynamic jsMarker, double lat, double lng) {
  (jsMarker as JSMarker).setPosition(createLatLng(lat, lng));
}

void webSetMarkerIcon(dynamic jsMarker, String? iconUrl, double? width, double? height) {
  final marker = jsMarker as JSMarker;
  if (iconUrl == null) return;
  if (width != null && height != null) {
    marker.setIcon(JSImageIcon(
      url: iconUrl.toJS,
      scaledSize: createSize(width, height),
    ) as JSAny);
  } else {
    marker.setIcon(iconUrl.toJS);
  }
}

void webSetPolylineCoords(dynamic jsPolyline, List<List<double>> coords) {
  final path = coords.map((c) => createLatLng(c[0], c[1])).toList().toJS;
  (jsPolyline as JSPolyline).setPath(path);
}

void webSetCircleCenter(dynamic jsCircle, double lat, double lng) {
  (jsCircle as JSCircle).setCenter(createLatLng(lat, lng));
}

void webSetCircleRadius(dynamic jsCircle, double radius) {
  (jsCircle as JSCircle).setRadius(radius.toJS);
}

void webSetInfoWindowContent(dynamic jsInfoWindow, String content) {
  (jsInfoWindow as JSInfoWindow).setContent(content.toJS);
}

void webCloseInfoWindow(dynamic jsInfoWindow) {
  (jsInfoWindow as JSInfoWindow).close();
}

void webSetOverlayClickListener(dynamic jsOverlay, void Function() onClick) {
  naverMapsEvent.addListener(
    jsOverlay as JSObject,
    "click".toJS,
    (() => onClick()).toJS,
  );
}

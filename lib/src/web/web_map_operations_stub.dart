// Stub — 웹이 아닌 플랫폼에서는 호출되지 않아야 합니다.

void setupWebMapEventListeners({
  required dynamic jsMap,
  required void Function(double lat, double lng, double x, double y) onMapTapped,
  required void Function(double lat, double lng, double zoom, double tilt, double bearing, bool animated)
      onCameraChange,
  required void Function(double lat, double lng, double zoom, double tilt, double bearing) onCameraIdle,
}) {
  throw UnsupportedError("Web map operations are not supported on this platform");
}

Map<String, double> webGetCameraPosition(dynamic jsMap) => throw UnsupportedError("Not supported");

Map<String, double> webGetContentBounds(dynamic jsMap) => throw UnsupportedError("Not supported");

Map<String, double> webScreenToLatLng(dynamic jsMap, double x, double y) => throw UnsupportedError("Not supported");

Map<String, double> webLatLngToScreen(dynamic jsMap, double lat, double lng) => throw UnsupportedError("Not supported");

void webUpdateCamera(
  dynamic jsMap, {
  double? lat,
  double? lng,
  double? zoom,
  bool animate = false,
}) {
  throw UnsupportedError("Not supported");
}

void webFitBounds(dynamic jsMap, double swLat, double swLng, double neLat, double neLng) {
  throw UnsupportedError("Not supported");
}

void webSetMapOptions(dynamic jsMap, Map<String, dynamic> options) {
  throw UnsupportedError("Not supported");
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
  Map<String, dynamic>? caption,
  Map<String, dynamic>? subCaption,
  List<String> captionAligns = const ["bottom"],
  double captionOffset = 0,
  bool visible = true,
  int zIndex = 0,
  bool clickable = false,
}) {
  throw UnsupportedError("Not supported");
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
  throw UnsupportedError("Not supported");
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
  throw UnsupportedError("Not supported");
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
  throw UnsupportedError("Not supported");
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
  throw UnsupportedError("Not supported");
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
  throw UnsupportedError("Not supported");
}

void webRemoveOverlay(dynamic jsOverlay) {
  throw UnsupportedError("Not supported");
}

void webSetOverlayVisible(dynamic jsOverlay, bool visible) {
  throw UnsupportedError("Not supported");
}

void webSetOverlayZIndex(dynamic jsOverlay, int zIndex) {
  throw UnsupportedError("Not supported");
}

void webSetMarkerPosition(dynamic jsMarker, double lat, double lng) {
  throw UnsupportedError("Not supported");
}

void webSetMarkerIcon(dynamic jsMarker, String? iconUrl, double? width, double? height) {
  throw UnsupportedError("Not supported");
}

void webUpdateMarker(
  dynamic jsMarker, {
  String? iconUrl,
  double? width,
  double? height,
  double? anchorX,
  double? anchorY,
  double alpha = 1.0,
  double angle = 0,
  Map<String, dynamic>? caption,
  Map<String, dynamic>? subCaption,
  List<String> captionAligns = const ["bottom"],
  double captionOffset = 0,
}) {
  throw UnsupportedError("Not supported");
}

void webSetPolylineCoords(dynamic jsPolyline, List<List<double>> coords) {
  throw UnsupportedError("Not supported");
}

void webSetCircleCenter(dynamic jsCircle, double lat, double lng) {
  throw UnsupportedError("Not supported");
}

void webSetCircleRadius(dynamic jsCircle, double radius) {
  throw UnsupportedError("Not supported");
}

void webSetInfoWindowContent(dynamic jsInfoWindow, String content) {
  throw UnsupportedError("Not supported");
}

void webCloseInfoWindow(dynamic jsInfoWindow) {
  throw UnsupportedError("Not supported");
}

void webSetOverlayClickListener(dynamic jsOverlay, void Function() onClick) {
  throw UnsupportedError("Not supported");
}

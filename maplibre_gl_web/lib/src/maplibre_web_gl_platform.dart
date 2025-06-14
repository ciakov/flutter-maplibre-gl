part of '../maplibre_gl_web.dart';

class MapLibreMapController extends MapLibrePlatform
    implements MapLibreMapOptionsSink {
  late html.DivElement _mapElement;

  late Map<String, dynamic> _creationParams;
  late MapLibreMap _map;
  bool _mapReady = false;
  dynamic _draggedFeatureId;
  LatLng? _dragOrigin;
  LatLng? _dragPrevious;
  bool _dragEnabled = true;
  final _addedFeaturesByLayer = <String, FeatureCollection>{};

  final _interactiveFeatureLayerIds = <String>{};

  bool _trackCameraPosition = false;
  GeolocateControl? _geolocateControl;
  LatLng? _myLastLocation;

  String? _navigationControlPosition;
  NavigationControl? _navigationControl;
  AttributionControl? _attributionControl;
  Timer? lastResizeObserverTimer;

  @override
  Widget buildView(
    Map<String, dynamic> creationParams,
    OnPlatformViewCreatedCallback onPlatformViewCreated,
    Set<Factory<OneSequenceGestureRecognizer>>? gestureRecognizers,
  ) {
    _creationParams = creationParams;
    _registerViewFactory(onPlatformViewCreated, hashCode);
    return HtmlElementView(
      viewType: 'plugins.flutter.io/maplibre_gl_$hashCode',
    );
  }

  @override
  void dispose() {
    super.dispose();
    _map.remove();
  }

  void _registerViewFactory(void Function(int) callback, int identifier) {
    // ignore: undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory(
      'plugins.flutter.io/maplibre_gl_$identifier',
      (int viewId) {
        _mapElement =
            html.DivElement()
              ..style.position = 'absolute'
              ..style.top = '0'
              ..style.bottom = '0'
              ..style.width = '100%';
        callback(viewId);
        return _mapElement;
      },
    );
  }

  @override
  Future<void> initPlatform(int id) async {
    if (_creationParams.containsKey('initialCameraPosition')) {
      final camera = _creationParams['initialCameraPosition'];
      _dragEnabled = _creationParams['dragEnabled'] ?? true;

      _map = MapLibreMap(
        MapOptions(
          container: _mapElement,
          style: _creationParams['styleString'],
          center: LngLat(camera['target'][1], camera['target'][0]),
          zoom: camera['zoom'],
          bearing: camera['bearing'],
          pitch: camera['tilt'],
          preserveDrawingBuffer: _creationParams['webPreserveDrawingBuffer'],
          attributionControl: false, //avoid duplicate control
        ),
      );
      _map.on('style.load', _onStyleLoaded);
      _map.on('click', _onMapClick);
      // long click not available in web, so it is mapped to double click
      _map.on('dblclick', _onMapLongClick);
      _map.on('movestart', _onCameraMoveStarted);
      _map.on('move', _onCameraMove);
      _map.on('moveend', _onCameraIdle);
      _map.on('resize', (_) => _onMapResize());
      _map.on('styleimagemissing', _loadFromAssets);
      if (_dragEnabled) {
        _map.on('mouseup', _onMouseUp);
        _map.on('mousemove', _onMouseMove);
      }

      _initResizeObserver();
    }
    Convert.interpretMapLibreMapOptions(_creationParams['options'], this);
  }

  void _initResizeObserver() {
    final resizeObserver = html.ResizeObserver((entries, observer) {
      // The resize observer might be called a lot of times when the user resizes the browser window with the mouse for example.
      // Due to the fact that the resize call is quite expensive it should not be called for every triggered event but only the last one, like "onMoveEnd".
      // But because there is no event type for the end, there is only the option to spawn timers and cancel the previous ones if they get overwritten by a new event.
      lastResizeObserverTimer?.cancel();
      lastResizeObserverTimer = Timer(const Duration(milliseconds: 50), () {
        _onMapResize();
      });
    });
    resizeObserver.observe(html.document.body!);
  }

  Future<void> _loadFromAssets(Event event) async {
    final imagePath = event.id;
    final bytes = await rootBundle.load(imagePath);
    await addImage(imagePath, bytes.buffer.asUint8List());
  }

  void _onMouseDown(Event e) {
    final isDraggable = e.features[0].properties['draggable'];
    if (isDraggable != null && isDraggable) {
      // Prevent the default map drag behavior.
      e.preventDefault();
      _draggedFeatureId = e.features[0].id;
      _map.getCanvas().style.cursor = 'grabbing';
      final coords = e.lngLat;
      _dragOrigin = LatLng(coords.lat as double, coords.lng as double);

      if (_draggedFeatureId != null) {
        final current = LatLng(
          e.lngLat.lat.toDouble(),
          e.lngLat.lng.toDouble(),
        );
        final payload = {
          'id': _draggedFeatureId,
          'point': Point<double>(e.point.x.toDouble(), e.point.y.toDouble()),
          'origin': _dragOrigin,
          'current': current,
          'delta': const LatLng(0, 0),
          'eventType': 'start',
        };
        onFeatureDraggedPlatform(payload);
      }
    }
  }

  void _onMouseUp(Event e) {
    if (_draggedFeatureId != null) {
      final current = LatLng(e.lngLat.lat.toDouble(), e.lngLat.lng.toDouble());
      final payload = {
        'id': _draggedFeatureId,
        'point': Point<double>(e.point.x.toDouble(), e.point.y.toDouble()),
        'origin': _dragOrigin,
        'current': current,
        'delta': current - (_dragPrevious ?? _dragOrigin!),
        'eventType': 'end',
      };
      onFeatureDraggedPlatform(payload);
    }
    _draggedFeatureId = null;
    _dragPrevious = null;
    _dragOrigin = null;
    _map.getCanvas().style.cursor = '';
  }

  void _onMouseMove(Event e) {
    if (_draggedFeatureId != null) {
      final current = LatLng(e.lngLat.lat.toDouble(), e.lngLat.lng.toDouble());
      final payload = {
        'id': _draggedFeatureId,
        'point': Point<double>(e.point.x.toDouble(), e.point.y.toDouble()),
        'origin': _dragOrigin,
        'current': current,
        'delta': current - (_dragPrevious ?? _dragOrigin!),
        'eventType': 'drag',
      };
      _dragPrevious = current;
      onFeatureDraggedPlatform(payload);
    }
  }

  @override
  Future<CameraPosition?> updateMapOptions(
    Map<String, dynamic> optionsUpdate,
  ) async {
    // FIX: why is called indefinitely? (map_ui page)
    Convert.interpretMapLibreMapOptions(optionsUpdate, this);
    return _getCameraPosition();
  }

  @override
  Future<bool?> animateCamera(
    CameraUpdate cameraUpdate, {
    Duration? duration,
  }) async {
    final cameraOptions = Convert.toCameraOptions(cameraUpdate, _map).jsObject;

    final around = getProperty<dynamic>(cameraOptions, 'around');
    final bearing = getProperty<dynamic>(cameraOptions, 'bearing');
    final center = getProperty<dynamic>(cameraOptions, 'center');
    final pitch = getProperty<dynamic>(cameraOptions, 'pitch');
    final zoom = getProperty<dynamic>(cameraOptions, 'zoom');

    _map.flyTo({
      if (around != null) 'around': around,
      if (bearing != null) 'bearing': bearing,
      if (center != null) 'center': center,
      if (pitch != null) 'pitch': pitch,
      if (zoom != null) 'zoom': zoom,
      if (duration != null) 'duration': duration.inMilliseconds,
    });

    return true;
  }

  @override
  Future<bool?> moveCamera(CameraUpdate cameraUpdate) async {
    final cameraOptions = Convert.toCameraOptions(cameraUpdate, _map);
    _map.jumpTo(cameraOptions);
    return true;
  }

  @override
  Future<void> updateMyLocationTrackingMode(
    MyLocationTrackingMode myLocationTrackingMode,
  ) async {
    setMyLocationTrackingMode(myLocationTrackingMode.index);
  }

  @override
  Future<void> matchMapLanguageWithDeviceDefault() async {
    // Fix in https://github.com/maplibre/flutter-maplibre-gl/issues/263
    // ignore: deprecated_member_use
    await setMapLanguage(ui.window.locale.languageCode);
  }

  @override
  Future<void> setMapLanguage(String language) async {
    final layers = _map.getLayers();

    final languageRegex = RegExp('(name:[a-z]+)');

    final symbolLayers = layers.where((layer) => layer.type == 'symbol');

    for (final layer in symbolLayers) {
      final dynamic properties = _map.getLayoutProperty(layer.id, 'text-field');

      if (properties == null) {
        continue;
      }

      // We could skip the current iteration, whenever there is not current language.
      if (!languageRegex.hasMatch(properties.toString())) {
        continue;
      }

      final newProperties = [
        'coalesce',
        ['get', 'name:$language'],
        ['get', 'name:latin'],
        ['get', 'name'],
      ];

      _map.setLayoutProperty(layer.id, 'text-field', newProperties);
    }
  }

  @override
  Future<void> setTelemetryEnabled(bool enabled) async {
    html.window.console.log('Telemetry not available in web');
    return;
  }

  @override
  Future<bool> getTelemetryEnabled() async {
    html.window.console.log('Telemetry not available in web');
    return false;
  }

  @override
  Future<List<dynamic>> queryRenderedFeatures(
    Point<double> point,
    List<String> layerIds,
    List<Object>? filter,
  ) async {
    final options = <String, dynamic>{};
    if (layerIds.isNotEmpty) {
      options['layers'] = layerIds;
    }
    if (filter != null) {
      options['filter'] = filter;
    }

    // avoid issues with the js point type
    final pointAsList = [point.x, point.y];
    return _map
        .queryRenderedFeatures([pointAsList, pointAsList], options)
        .map(
          (feature) => {
            'type': 'Feature',
            'id': feature.id,
            'geometry': {
              'type': feature.geometry.type,
              'coordinates': feature.geometry.coordinates,
            },
            'properties': feature.properties,
            'source': feature.source,
          },
        )
        .toList();
  }

  @override
  Future<List<dynamic>> queryRenderedFeaturesInRect(
    Rect rect,
    List<String> layerIds,
    String? filter,
  ) async {
    final options = <String, dynamic>{};
    if (layerIds.isNotEmpty) {
      options['layers'] = layerIds;
    }
    if (filter != null) {
      options['filter'] = filter;
    }
    return _map
        .queryRenderedFeatures([
          [rect.left, rect.bottom],
          [rect.right, rect.top],
        ], options)
        .map(
          (feature) => {
            'type': 'Feature',
            'id': feature.id as int?,
            'geometry': {
              'type': feature.geometry.type,
              'coordinates': feature.geometry.coordinates,
            },
            'properties': feature.properties,
            'source': feature.source,
          },
        )
        .toList();
  }

  @override
  Future<List<dynamic>> querySourceFeatures(
    String sourceId,
    String? sourceLayerId,
    List<Object>? filter,
  ) async {
    final parameters = <String, dynamic>{};

    if (sourceLayerId != null) {
      parameters['sourceLayer'] = sourceLayerId;
    }

    if (filter != null) {
      parameters['filter'] = filter;
    }
    html.window.console.log(parameters);

    return _map
        .querySourceFeatures(sourceId, parameters)
        .map(
          (feature) => {
            'type': 'Feature',
            'id': feature.id,
            'geometry': {
              'type': feature.geometry.type,
              'coordinates': feature.geometry.coordinates,
            },
            'properties': feature.properties,
            'source': feature.source,
          },
        )
        .toList();
  }

  @override
  Future<dynamic> invalidateAmbientCache() async {
    html.window.console.log('Offline storage not available in web');
  }

  @override
  Future<dynamic> clearAmbientCache() async {
    html.window.console.log('Offline storage not available in web');
  }

  @override
  Future<LatLng?> requestMyLocationLatLng() async {
    return _myLastLocation;
  }

  @override
  Future<LatLngBounds> getVisibleRegion() async {
    final bounds = _map.getBounds();
    return LatLngBounds(
      southwest: LatLng(
        bounds.getSouthWest().lat as double,
        bounds.getSouthWest().lng as double,
      ),
      northeast: LatLng(
        bounds.getNorthEast().lat as double,
        bounds.getNorthEast().lng as double,
      ),
    );
  }

  @override
  Future<void> addImage(
    String name,
    Uint8List bytes, [
    bool sdf = false,
  ]) async {
    final photo = decodeImage(bytes)!;
    if (!_map.hasImage(name)) {
      _map.addImage(
        name,
        {
          'width': photo.width,
          'height': photo.height,
          'data': photo.getBytes(),
        },
        {'sdf': sdf},
      );
    }
  }

  @override
  Future<void> removeSource(String sourceId) async {
    _map.removeSource(sourceId);
  }

  CameraPosition? _getCameraPosition() {
    if (_trackCameraPosition) {
      final center = _map.getCenter();
      return CameraPosition(
        bearing: _map.getBearing() as double,
        target: LatLng(center.lat as double, center.lng as double),
        tilt: _map.getPitch() as double,
        zoom: _map.getZoom() as double,
      );
    }
    return null;
  }

  void _onStyleLoaded(_) {
    _mapReady = true;
    final loaded = _map.isStyleLoaded();
    if (!loaded) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _onStyleLoaded(_);
      });
      return;
    }
    _onMapResize();
    onMapStyleLoadedPlatform(null);
  }

  void _onMapResize() {
    Timer(Duration.zero, () {
      final container = _map.getContainer();
      final canvas = _map.getCanvas();
      final widthMismatch = canvas.clientWidth != container.clientWidth;
      final heightMismatch = canvas.clientHeight != container.clientHeight;
      if (widthMismatch || heightMismatch) {
        _map.resize();
      }
    });
  }

  void _onMapClick(Event e) {
    final features = _map.queryRenderedFeatures(
      [e.point.x, e.point.y],
      {'layers': _interactiveFeatureLayerIds.toList()},
    );
    final payload = {
      'point': Point<double>(e.point.x.toDouble(), e.point.y.toDouble()),
      'latLng': LatLng(e.lngLat.lat.toDouble(), e.lngLat.lng.toDouble()),
      if (features.isNotEmpty) 'id': features.first.id,
    };
    if (features.isNotEmpty) {
      onFeatureTappedPlatform(payload);
    } else {
      onMapClickPlatform(payload);
    }
  }

  void _onMapLongClick(Event e) {
    onMapLongClickPlatform({
      'point': Point<double>(e.point.x.toDouble(), e.point.y.toDouble()),
      'latLng': LatLng(e.lngLat.lat.toDouble(), e.lngLat.lng.toDouble()),
    });
  }

  void _onCameraMoveStarted(_) {
    onCameraMoveStartedPlatform(null);
  }

  void _onCameraMove(_) {
    final center = _map.getCenter();
    final camera = CameraPosition(
      bearing: _map.getBearing() as double,
      target: LatLng(center.lat as double, center.lng as double),
      tilt: _map.getPitch() as double,
      zoom: _map.getZoom() as double,
    );
    onCameraMovePlatform(camera);
  }

  void _onCameraIdle(_) {
    final center = _map.getCenter();
    final camera = CameraPosition(
      bearing: _map.getBearing() as double,
      target: LatLng(center.lat as double, center.lng as double),
      tilt: _map.getPitch() as double,
      zoom: _map.getZoom() as double,
    );
    onCameraIdlePlatform(camera);
  }

  void _onCameraTrackingChanged(bool isTracking) {
    if (isTracking) {
      onCameraTrackingChangedPlatform(MyLocationTrackingMode.tracking);
    } else {
      onCameraTrackingChangedPlatform(MyLocationTrackingMode.none);
    }
  }

  void _onCameraTrackingDismissed() {
    onCameraTrackingDismissedPlatform(null);
  }

  void _addGeolocateControl({bool trackUserLocation = false}) {
    _removeGeolocateControl();
    _geolocateControl = GeolocateControl(
      GeolocateControlOptions(
        positionOptions: PositionOptions(enableHighAccuracy: true),
        trackUserLocation: trackUserLocation,
        showAccuracyCircle: true,
        showUserLocation: true,
      ),
    );
    _geolocateControl!.on('geolocate', (dynamic e) {
      _myLastLocation = LatLng(e.coords.latitude, e.coords.longitude);
      onUserLocationUpdatedPlatform(
        UserLocation(
          position: LatLng(e.coords.latitude, e.coords.longitude),
          altitude: e.coords.altitude,
          bearing: e.coords.heading,
          speed: e.coords.speed,
          horizontalAccuracy: e.coords.accuracy,
          verticalAccuracy: e.coords.altitudeAccuracy,
          heading: null,
          timestamp: DateTime.fromMillisecondsSinceEpoch(e.timestamp),
        ),
      );
    });
    _geolocateControl!.on('trackuserlocationstart', (_) {
      _onCameraTrackingChanged(true);
    });
    _geolocateControl!.on('trackuserlocationend', (_) {
      _onCameraTrackingChanged(false);
      _onCameraTrackingDismissed();
    });
    _map.addControl(_geolocateControl, 'bottom-right');
  }

  void _removeGeolocateControl() {
    if (_geolocateControl != null) {
      _map.removeControl(_geolocateControl);
      _geolocateControl = null;
    }
  }

  void _updateNavigationControl({
    bool? compassEnabled,
    CompassViewPosition? position,
  }) {
    bool? prevShowCompass;
    if (_navigationControl != null) {
      prevShowCompass = _navigationControl!.options.showCompass;
    }
    final prevPosition = _navigationControlPosition;

    final positionString = switch (position) {
      CompassViewPosition.topRight => 'top-right',
      CompassViewPosition.topLeft => 'top-left',
      CompassViewPosition.bottomRight => 'bottom-right',
      CompassViewPosition.bottomLeft => 'bottom-left',
      _ => null,
    };

    final newShowCompass = compassEnabled ?? prevShowCompass ?? false;
    final newPosition = positionString ?? prevPosition;

    _removeNavigationControl();
    _navigationControl = NavigationControl(
      NavigationControlOptions(
        showCompass: newShowCompass,
        showZoom: false,
        visualizePitch: false,
      ),
    );

    if (newPosition == null) {
      _map.addControl(_navigationControl);
    } else {
      _map.addControl(_navigationControl, newPosition);
      _navigationControlPosition = newPosition;
    }
  }

  void _removeNavigationControl() {
    if (_navigationControl != null) {
      _map.removeControl(_navigationControl);
      _navigationControl = null;
    }
  }

  void _updateAttributionButton(AttributionButtonPosition position) {
    String? positionString;
    switch (position) {
      case AttributionButtonPosition.topRight:
        positionString = 'top-right';
      case AttributionButtonPosition.topLeft:
        positionString = 'top-left';
      case AttributionButtonPosition.bottomRight:
        positionString = 'bottom-right';
      case AttributionButtonPosition.bottomLeft:
        positionString = 'bottom-left';
    }

    _removeAttributionButton();
    _attributionControl = AttributionControl(AttributionControlOptions());
    _map.addControl(_attributionControl, positionString);
  }

  void _removeAttributionButton() {
    if (_attributionControl != null) {
      _map.removeControl(_attributionControl);
      _attributionControl = null;
    }
  }

  /*
   *  MapLibreMapOptionsSink
   */
  @override
  void setAttributionButtonMargins(int x, int y) {
    html.window.console.log('setAttributionButtonMargins not available in web');
  }

  @override
  void setCameraTargetBounds(LatLngBounds? bounds) {
    if (bounds == null) {
      _map.setMaxBounds(null);
    } else {
      _map.setMaxBounds(
        LngLatBounds(
          LngLat(bounds.southwest.longitude, bounds.southwest.latitude),
          LngLat(bounds.northeast.longitude, bounds.northeast.latitude),
        ),
      );
    }
  }

  @override
  void setCompassEnabled(bool compassEnabled) {
    _updateNavigationControl(compassEnabled: compassEnabled);
  }

  @override
  void setCompassAlignment(CompassViewPosition position) {
    _updateNavigationControl(position: position);
  }

  @override
  void setAttributionButtonAlignment(AttributionButtonPosition position) {
    _updateAttributionButton(position);
  }

  @override
  void setCompassViewMargins(int x, int y) {
    html.window.console.log('setCompassViewMargins not available in web');
  }

  @override
  void setLogoViewMargins(int x, int y) {
    html.window.console.log('setLogoViewMargins not available in web');
  }

  @override
  void setMinMaxZoomPreference(num? min, num? max) {
    // FIX: why is called indefinitely? (map_ui page)
    _map.setMinZoom(min);
    _map.setMaxZoom(max);
  }

  @override
  void setMyLocationEnabled(bool myLocationEnabled) {
    if (myLocationEnabled) {
      _addGeolocateControl();
    } else {
      _removeGeolocateControl();
    }
  }

  @override
  void setMyLocationRenderMode(int myLocationRenderMode) {
    html.window.console.log('myLocationRenderMode not available in web');
  }

  @override
  void setMyLocationTrackingMode(int myLocationTrackingMode) {
    if (_geolocateControl == null) {
      //myLocationEnabled is false, ignore myLocationTrackingMode
      return;
    }
    if (myLocationTrackingMode == 0) {
      _addGeolocateControl();
    } else {
      html.window.console.log('Only one tracking mode available in web');
      _addGeolocateControl(trackUserLocation: true);
    }
  }

  @override
  void setStyleString(String? styleString) {
    //remove old mouseenter callbacks to avoid multicalling
    for (final layerId in _interactiveFeatureLayerIds) {
      _map.off('mouseenter', layerId, _onMouseEnterFeature);
      _map.off('mousemouve', layerId, _onMouseEnterFeature);
      _map.off('mouseleave', layerId, _onMouseLeaveFeature);
      if (_dragEnabled) _map.off('mousedown', layerId, _onMouseDown);
    }
    _interactiveFeatureLayerIds.clear();

    _map.setStyle(styleString);
    // catch style loaded for later style changes
    if (_mapReady) {
      _map.once('styledata', _onStyleLoaded);
    }
  }

  @override
  void setTrackCameraPosition(bool trackCameraPosition) {
    _trackCameraPosition = trackCameraPosition;
  }

  @override
  Future<LatLng> toLatLng(Point<num> screenLocation) async {
    final lngLat = _map.unproject(
      geo_point.Point(screenLocation.x, screenLocation.y),
    );
    return LatLng(lngLat.lat as double, lngLat.lng as double);
  }

  @override
  Future<Point> toScreenLocation(LatLng latLng) async {
    final screenPosition = _map.project(
      LngLat(latLng.longitude, latLng.latitude),
    );
    final point = Point(screenPosition.x.round(), screenPosition.y.round());

    return point;
  }

  @override
  Future<List<Point<num>>> toScreenLocationBatch(
    Iterable<LatLng> latLngs,
  ) async {
    return latLngs
        .map((latLng) {
          final screenPosition = _map.project(
            LngLat(latLng.longitude, latLng.latitude),
          );
          return Point(screenPosition.x.round(), screenPosition.y.round());
        })
        .toList(growable: false);
  }

  @override
  Future<double> getMetersPerPixelAtLatitude(double latitude) async {
    //https://wiki.openstreetmap.org/wiki/Zoom_levels
    const circumference = 40075017.686;
    final zoom = _map.getZoom();
    return circumference * cos(latitude * (pi / 180)) / pow(2, zoom + 9);
  }

  @override
  Future<void> removeLayer(String imageLayerId) async {
    _interactiveFeatureLayerIds.remove(imageLayerId);
    _map.removeLayer(imageLayerId);
  }

  @override
  Future<void> setFilter(String layerId, dynamic filter) async {
    _map.setFilter(layerId, filter);
  }

  @override
  Future<void> addGeoJsonSource(
    String sourceId,
    Map<String, dynamic> geojson, {
    String? promoteId,
  }) async {
    final data = _makeFeatureCollection(geojson);
    _addedFeaturesByLayer[sourceId] = data;
    _map.addSource(sourceId, {
      'type': 'geojson',
      'data': geojson, // pass the raw string here to avoid errors
      if (promoteId != null) 'promoteId': promoteId,
    });
  }

  Feature _makeFeature(Map<String, dynamic> geojsonFeature) {
    return Feature(
      geometry: Geometry(
        type: geojsonFeature['geometry']['type'],
        coordinates: geojsonFeature['geometry']['coordinates'],
      ),
      properties: geojsonFeature['properties'],
      id: geojsonFeature['properties']?['id'] ?? geojsonFeature['id'],
    );
  }

  FeatureCollection _makeFeatureCollection(Map<String, dynamic> geojson) {
    return FeatureCollection(
      features: [for (final f in geojson['features'] ?? []) _makeFeature(f)],
    );
  }

  @override
  Future<void> setGeoJsonSource(
    String sourceId,
    Map<String, dynamic> geojson,
  ) async {
    final source = _map.getSource(sourceId) as GeoJsonSource;
    final data = _makeFeatureCollection(geojson);
    _addedFeaturesByLayer[sourceId] = data;
    source.setData(data);
  }

  @override
  Future<dynamic> setCameraBounds({
    required double west,
    required double north,
    required double south,
    required double east,
    required int padding,
  }) async {
    _map.fitBounds(LngLatBounds(LngLat(west, south), LngLat(east, north)), {
      'padding': padding,
    });
  }

  @override
  Future<void> addFillExtrusionLayer(
    String sourceId,
    String layerId,
    Map<String, dynamic> properties, {
    required bool enableInteraction,
    String? belowLayerId,
    String? sourceLayer,
    double? minzoom,
    double? maxzoom,
    dynamic filter,
  }) async {
    return _addLayer(
      sourceId,
      layerId,
      properties,
      'fill-extrusion',
      belowLayerId: belowLayerId,
      sourceLayer: sourceLayer,
      minzoom: minzoom,
      maxzoom: maxzoom,
      filter: filter,
      enableInteraction: enableInteraction,
    );
  }

  @override
  Future<void> addCircleLayer(
    String sourceId,
    String layerId,
    Map<String, dynamic> properties, {
    required bool enableInteraction,
    String? belowLayerId,
    String? sourceLayer,
    double? minzoom,
    double? maxzoom,
    dynamic filter,
  }) async {
    return _addLayer(
      sourceId,
      layerId,
      properties,
      'circle',
      belowLayerId: belowLayerId,
      sourceLayer: sourceLayer,
      minzoom: minzoom,
      maxzoom: maxzoom,
      filter: filter,
      enableInteraction: enableInteraction,
    );
  }

  @override
  Future<void> addFillLayer(
    String sourceId,
    String layerId,
    Map<String, dynamic> properties, {
    required bool enableInteraction,
    String? belowLayerId,
    String? sourceLayer,
    double? minzoom,
    double? maxzoom,
    dynamic filter,
  }) async {
    return _addLayer(
      sourceId,
      layerId,
      properties,
      'fill',
      belowLayerId: belowLayerId,
      sourceLayer: sourceLayer,
      minzoom: minzoom,
      maxzoom: maxzoom,
      filter: filter,
      enableInteraction: enableInteraction,
    );
  }

  @override
  Future<void> addLineLayer(
    String sourceId,
    String layerId,
    Map<String, dynamic> properties, {
    required bool enableInteraction,
    String? belowLayerId,
    String? sourceLayer,
    double? minzoom,
    double? maxzoom,
    dynamic filter,
  }) async {
    return _addLayer(
      sourceId,
      layerId,
      properties,
      'line',
      belowLayerId: belowLayerId,
      sourceLayer: sourceLayer,
      minzoom: minzoom,
      maxzoom: maxzoom,
      filter: filter,
      enableInteraction: enableInteraction,
    );
  }

  @override
  Future<void> setLayerProperties(
    String layerId,
    Map<String, dynamic> properties,
  ) async {
    for (final entry in properties.entries) {
      // Very hacky: because we don't know if the property is a layout
      // or paint property, we try to set it as both.
      try {
        _map.setLayoutProperty(layerId, entry.key, entry.value);
      } on Exception catch (e) {
        html.window.console.log(
          'Caught exception (usually safe to ignore): $e',
        );
      }
      try {
        _map.setPaintProperty(layerId, entry.key, entry.value);
      } on Exception catch (e) {
        html.window.console.log(
          'Caught exception (usually safe to ignore): $e',
        );
      }
    }
  }

  @override
  Future<void> addSymbolLayer(
    String sourceId,
    String layerId,
    Map<String, dynamic> properties, {
    required bool enableInteraction,
    String? belowLayerId,
    String? sourceLayer,
    double? minzoom,
    double? maxzoom,
    dynamic filter,
  }) async {
    return _addLayer(
      sourceId,
      layerId,
      properties,
      'symbol',
      belowLayerId: belowLayerId,
      sourceLayer: sourceLayer,
      minzoom: minzoom,
      maxzoom: maxzoom,
      filter: filter,
      enableInteraction: enableInteraction,
    );
  }

  @override
  Future<void> addHillshadeLayer(
    String sourceId,
    String layerId,
    Map<String, dynamic> properties, {
    String? belowLayerId,
    String? sourceLayer,
    double? minzoom,
    double? maxzoom,
  }) async {
    return _addLayer(
      sourceId,
      layerId,
      properties,
      'hillshade',
      belowLayerId: belowLayerId,
      sourceLayer: sourceLayer,
      minzoom: minzoom,
      maxzoom: maxzoom,
      enableInteraction: false,
    );
  }

  @override
  Future<void> addHeatmapLayer(
    String sourceId,
    String layerId,
    Map<String, dynamic> properties, {
    String? belowLayerId,
    String? sourceLayer,
    double? minzoom,
    double? maxzoom,
  }) async {
    return _addLayer(
      sourceId,
      layerId,
      properties,
      'heatmap',
      belowLayerId: belowLayerId,
      sourceLayer: sourceLayer,
      minzoom: minzoom,
      maxzoom: maxzoom,
      enableInteraction: false,
    );
  }

  @override
  Future<void> addRasterLayer(
    String sourceId,
    String layerId,
    Map<String, dynamic> properties, {
    String? belowLayerId,
    String? sourceLayer,
    double? minzoom,
    double? maxzoom,
  }) async {
    await _addLayer(
      sourceId,
      layerId,
      properties,
      'raster',
      belowLayerId: belowLayerId,
      sourceLayer: sourceLayer,
      minzoom: minzoom,
      maxzoom: maxzoom,
      enableInteraction: false,
    );
  }

  Future<void> _addLayer(
    String sourceId,
    String layerId,
    Map<String, dynamic> properties,
    String layerType, {
    required bool enableInteraction,
    String? belowLayerId,
    String? sourceLayer,
    double? minzoom,
    double? maxzoom,
    dynamic filter,
  }) async {
    final layout = Map.fromEntries(
      properties.entries.where((entry) => isLayoutProperty(entry.key)),
    );
    final paint = Map.fromEntries(
      properties.entries.where((entry) => !isLayoutProperty(entry.key)),
    );

    _map.addLayer({
      'id': layerId,
      'type': layerType,
      'source': sourceId,
      'layout': layout,
      'paint': paint,
      if (sourceLayer != null) 'source-layer': sourceLayer,
      if (minzoom != null) 'minzoom': minzoom,
      if (maxzoom != null) 'maxzoom': maxzoom,
      if (filter != null) 'filter': filter,
    }, belowLayerId);

    if (enableInteraction) {
      _interactiveFeatureLayerIds.add(layerId);
      if (layerType == 'fill') {
        _map.on('mousemove', layerId, _onMouseEnterFeature);
      } else {
        _map.on('mouseenter', layerId, _onMouseEnterFeature);
      }
      _map.on('mouseleave', layerId, _onMouseLeaveFeature);
      if (_dragEnabled) _map.on('mousedown', layerId, _onMouseDown);
    }
  }

  void _onMouseEnterFeature(_) {
    if (_draggedFeatureId == null) {
      _map.getCanvas().style.cursor = 'pointer';
    }
  }

  void _onMouseLeaveFeature(_) {
    _map.getCanvas().style.cursor = '';
  }

  @override
  void setGestures({
    required bool rotateGesturesEnabled,
    required bool scrollGesturesEnabled,
    required bool tiltGesturesEnabled,
    required bool zoomGesturesEnabled,
    required bool doubleClickZoomEnabled,
  }) {
    if (rotateGesturesEnabled &&
        scrollGesturesEnabled &&
        tiltGesturesEnabled &&
        zoomGesturesEnabled) {
      _map.keyboard.enable();
    } else {
      _map.keyboard.disable();
    }

    if (scrollGesturesEnabled) {
      _map.dragPan.enable();
    } else {
      _map.dragPan.disable();
    }

    if (zoomGesturesEnabled) {
      _map.doubleClickZoom.enable();
      _map.boxZoom.enable();
      _map.scrollZoom.enable();
      _map.touchZoomRotate.enable();
    } else {
      _map.doubleClickZoom.disable();
      _map.boxZoom.disable();
      _map.scrollZoom.disable();
      _map.touchZoomRotate.disable();
    }

    if (doubleClickZoomEnabled) {
      _map.doubleClickZoom.enable();
    } else {
      _map.doubleClickZoom.disable();
    }

    if (rotateGesturesEnabled) {
      _map.touchZoomRotate.enableRotation();
    } else {
      _map.touchZoomRotate.disableRotation();
    }

    // dragRotate is shared by both gestures
    if (tiltGesturesEnabled && rotateGesturesEnabled) {
      _map.dragRotate.enable();
    } else {
      _map.dragRotate.disable();
    }
  }

  @override
  Future<void> addSource(String sourceId, SourceProperties properties) async {
    _map.addSource(sourceId, properties.toJson());
  }

  @override
  Future<void> addImageSource(
    String imageSourceId,
    Uint8List bytes,
    LatLngQuad coordinates,
  ) {
    // TODO: implement addImageSource
    throw UnimplementedError();
  }

  @override
  Future<void> updateImageSource(
    String imageSourceId,
    Uint8List? bytes,
    LatLngQuad? coordinates,
  ) {
    // TODO: implement updateImageSource
    throw UnimplementedError();
  }

  @override
  Future<void> addLayer(
    String imageLayerId,
    String imageSourceId,
    double? minzoom,
    double? maxzoom,
  ) {
    // TODO: implement addLayer
    throw UnimplementedError();
  }

  @override
  Future<void> addLayerBelow(
    String imageLayerId,
    String imageSourceId,
    String belowLayerId,
    double? minzoom,
    double? maxzoom,
  ) {
    // TODO: implement addLayerBelow
    throw UnimplementedError();
  }

  @override
  Future<void> updateContentInsets(EdgeInsets insets, bool animated) {
    // TODO: implement updateContentInsets
    throw UnimplementedError();
  }

  @override
  Future<void> setFeatureForGeoJsonSource(
    String sourceId,
    Map<String, dynamic> geojsonFeature,
  ) async {
    final source = _map.getSource(sourceId) as GeoJsonSource?;
    final data = _addedFeaturesByLayer[sourceId];

    if (source != null && data != null) {
      final feature = _makeFeature(geojsonFeature);
      final features = data.features.toList();
      final index = features.indexWhere((f) => f.id == feature.id);
      if (index >= 0) {
        features[index] = feature;
        final newData = FeatureCollection(features: features);
        _addedFeaturesByLayer[sourceId] = newData;

        source.setData(newData);
      }
    }
  }

  @override
  void resizeWebMap() {
    _onMapResize();
  }

  @override
  void forceResizeWebMap() {
    _map.resize();
  }

  @override
  Future<void> setLayerVisibility(String layerId, bool visible) async {
    _map.setLayoutProperty(layerId, 'visibility', visible ? 'visible' : 'none');
  }

  @override
  Future<dynamic> getFilter(String layerId) async {
    return _map.getFilter(layerId);
  }

  @override
  Future<List<dynamic>> getLayerIds() async {
    return _map.getLayers().map((e) => e.id).toList();
  }

  @override
  Future<List<dynamic>> getSourceIds() async {
    throw UnimplementedError();
  }
}

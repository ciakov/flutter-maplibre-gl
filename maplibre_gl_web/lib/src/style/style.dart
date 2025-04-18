import 'package:maplibre_gl_web/src/interop/interop.dart';
import 'package:maplibre_gl_web/src/style/evaluation_parameters.dart';
import 'package:maplibre_gl_web/src/style/style_image.dart';
import 'package:maplibre_gl_web/src/ui/map.dart';

class StyleSetterOptions extends JsObjectWrapper<StyleSetterOptionsJsImpl> {
  /// Creates a new StyleSetterOptions from a [jsObject].
  StyleSetterOptions.fromJsObject(super.jsObject) : super.fromJsObject();
  bool get validate => jsObject.validate;
}

class Style extends JsObjectWrapper<StyleJsImpl> {
  /// Creates a new Style from a [jsObject].
  Style.fromJsObject(super.jsObject) : super.fromJsObject();
  dynamic loadURL(String url, dynamic options) =>
      jsObject.loadURL(url, options);

  dynamic loadJSON(dynamic json, StyleSetterOptions option) =>
      jsObject.loadJSON(json, option.jsObject);

  dynamic loaded() => jsObject.loaded();

  dynamic hasTransitions() => jsObject.hasTransitions();

  ///  Apply queued style updates in a batch and recalculate zoom-dependent paint properties.
  dynamic update(EvaluationParameters parameters) =>
      jsObject.update(parameters.jsObject);

  ///  Update this style's state to match the given style JSON, performing only
  ///  the necessary mutations.
  ///
  ///  May throw an Error ('Unimplemented: METHOD') if the maplibre-gl-style-spec
  ///  diff algorithm produces an operation that is not supported.
  ///
  ///  @returns {boolean} true if any changes were made; false otherwise
  ///  @private
  dynamic setState(dynamic nextState) => jsObject.setState(nextState);

  dynamic addImage(String id, StyleImage image) =>
      jsObject.addImage(id, image.jsObject);

  dynamic updateImage(String id, StyleImage image) =>
      jsObject.updateImage(id, image.jsObject);

  StyleImage getImage(String id) =>
      StyleImage.fromJsObject(jsObject.getImage(id));

  dynamic removeImage(String id) => jsObject.removeImage(id);

  dynamic listImages() => jsObject.listImages();

  dynamic addSource(String id, dynamic source, StyleSetterOptions options) =>
      jsObject.addSource(id, source, options.jsObject);

  ///  Remove a source from this stylesheet, given its id.
  ///  @param {string} id id of the source to remove
  ///  @throws {Error} if no source is found with the given ID
  dynamic removeSource(String id) => jsObject.removeSource(id);

  ///  Set the data of a GeoJSON source, given its id.
  ///  @param {string} id id of the source
  ///  @param {GeoJSON|string} data GeoJSON source
  dynamic setGeoJSONSourceData(String id, dynamic data) =>
      jsObject.setGeoJSONSourceData(id, data);

  ///  Get a source by id.
  ///  @param {string} id id of the desired source
  ///  @returns {Object} source
  dynamic getSource(String id) => jsObject.getSource(id);

  ///  Add a layer to the map style. The layer will be inserted before the layer with
  ///  ID `before`, or appended if `before` is omitted.
  ///  @param {string} [before] ID of an existing layer to insert before
  dynamic addLayer(
    dynamic layerObject, [
    String? before,
    StyleSetterOptions? options,
  ]) =>
      jsObject.addLayer(layerObject);

  ///  Moves a layer to a different z-position. The layer will be inserted before the layer with
  ///  ID `before`, or appended if `before` is omitted.
  ///  @param {string} id  ID of the layer to move
  ///  @param {string} [before] ID of an existing layer to insert before
  dynamic moveLayer(String id, [String? before]) => jsObject.moveLayer(id);

  ///  Remove the layer with the given id from the style.
  ///
  ///  If no such layer exists, an `error` event is fired.
  ///
  ///  @param {string} id id of the layer to remove
  ///  @fires error
  dynamic removeLayer(String id) => jsObject.removeLayer(id);

  ///  Return the style layer object with the given `id`.
  ///
  ///  @param {string} id - id of the desired layer
  ///  @returns {?Object} a layer, if one with the given `id` exists
  dynamic getLayer(String id) => jsObject.getLayer(id);

  dynamic setLayerZoomRange(String layerId, [num? minzoom, num? maxzoom]) =>
      jsObject.setLayerZoomRange(layerId);

  dynamic setFilter(
    String layerId,
    dynamic filter,
    StyleSetterOptions options,
  ) =>
      jsObject.setFilter(layerId, filter, options.jsObject);

  ///  Get a layer's filter object
  ///  @param {string} layer the layer to inspect
  ///  @returns {*} the layer's filter, if any
  dynamic getFilter(String layer) => jsObject.getFilter(layer);

  dynamic setLayoutProperty(
    String layerId,
    String name,
    dynamic value,
    StyleSetterOptions options,
  ) =>
      jsObject.setLayoutProperty(layerId, name, value, options.jsObject);

  ///  Get a layout property's value from a given layer
  ///  @param {string} layerId the layer to inspect
  ///  @param {string} name the name of the layout property
  ///  @returns {*} the property value
  dynamic getLayoutProperty(String layerId, String name) =>
      jsObject.getLayoutProperty(layerId, name);

  dynamic setPaintProperty(
    String layerId,
    String name,
    dynamic value,
    StyleSetterOptions options,
  ) =>
      jsObject.setPaintProperty(layerId, name, value, options.jsObject);

  dynamic getPaintProperty(String layer, String name) =>
      jsObject.getPaintProperty(layer, name);

  dynamic setFeatureState(dynamic target, dynamic state) =>
      jsObject.setFeatureState(target, state);

  dynamic removeFeatureState(dynamic target, [String? key]) =>
      jsObject.removeFeatureState(target);

  dynamic getFeatureState(dynamic target) => jsObject.getFeatureState(target);

  dynamic getTransition() => jsObject.getTransition();

  dynamic serialize() => jsObject.serialize();

  dynamic querySourceFeatures(String sourceID, dynamic params) =>
      jsObject.querySourceFeatures(sourceID, params);

  dynamic addSourceType(String name, dynamic sourceType, Function callback) =>
      jsObject.addSourceType(name, sourceType, callback);

  dynamic getLight() => jsObject.getLight();

  dynamic setLight(dynamic lightOptions, StyleSetterOptions options) =>
      jsObject.setLight(lightOptions, options.jsObject);

  // Callbacks from web workers

  dynamic getImages(String mapId, dynamic params, Function callback) =>
      jsObject.getImages(mapId, params, callback);

  dynamic getGlyphs(String mapId, dynamic params, Function callback) =>
      jsObject.getGlyphs(mapId, params, callback);

  dynamic getResource(
    String mapId,
    RequestParameters params,
    Function callback,
  ) =>
      jsObject.getResource(mapId, params.jsObject, callback);

  List<dynamic> get layers => jsObject.layers;
}

class StyleFunction extends JsObjectWrapper<StyleFunctionJsImpl> {
  factory StyleFunction({
    dynamic base,
    dynamic stops,
  }) =>
      StyleFunction.fromJsObject(StyleFunctionJsImpl(base: base, stops: stops));

  /// Creates a new StyleFunction from a [jsObject].
  StyleFunction.fromJsObject(super.jsObject) : super.fromJsObject();
}

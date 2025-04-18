import 'dart:html';

import 'package:maplibre_gl_web/src/interop/interop.dart';

class BoxZoomHandler extends JsObjectWrapper<BoxZoomHandlerJsImpl> {
  /// Creates a new BoxZoomHandler from a [jsObject].
  BoxZoomHandler.fromJsObject(super.jsObject) : super.fromJsObject();

  ///  Returns a Boolean indicating whether the "box zoom" interaction is enabled.
  ///
  ///  @returns {boolean} `true` if the "box zoom" interaction is enabled.
  bool isEnabled() => jsObject.isEnabled();

  ///  Returns a Boolean indicating whether the "box zoom" interaction is active, i.e. currently being used.
  ///
  ///  @returns {boolean} `true` if the "box zoom" interaction is active.
  bool isActive() => jsObject.isActive();

  ///  Enables the "box zoom" interaction.
  ///
  ///  @example
  ///    map.boxZoom.enable();
  dynamic enable() => jsObject.enable();

  ///  Disables the "box zoom" interaction.
  ///
  ///  @example
  ///    map.boxZoom.disable();
  dynamic disable() => jsObject.disable();

  dynamic onMouseDown(MouseEvent e) => jsObject.onMouseDown(e);
}

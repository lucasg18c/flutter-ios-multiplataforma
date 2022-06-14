import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class WebHandler {
  String nombre;
  JavaScriptHandlerCallback callback;

  WebHandler({required this.nombre, required this.callback});
}
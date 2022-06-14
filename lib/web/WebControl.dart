import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:marco_multiplataforma/web/WebHandler.dart';

class WebControl {
  InAppWebViewController controller;

  WebControl({required this.controller});


  void run(String function) {
    controller.evaluateJavascript(source: function);
  }

  void addHandler(WebHandler handler) {
    controller.addJavaScriptHandler(
        handlerName: handler.nombre, callback: handler.callback);
  }
}

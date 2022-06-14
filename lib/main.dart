import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'package:flutter_ble_lib/flutter_ble_lib.dart';
import 'package:marco_multiplataforma/BLE/BleCG.dart';
import 'package:marco_multiplataforma/auth/authManager.dart';
import 'package:marco_multiplataforma/web/WebControl.dart';
import 'package:marco_multiplataforma/web/WebHandler.dart';
import 'package:permission_handler/permission_handler.dart';

late BleCG ble;
late AuthManager auth;

Future main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Permission.bluetooth.request();
  await Permission.location.request();

  if (Platform.isAndroid) {
    await AndroidInAppWebViewController.setWebContentsDebuggingEnabled(true);
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  MyAppState createState() => MyAppState();
}

late InAppWebViewController _controller;


dynamic esMobile(List<dynamic> params) async {
  return {'so': Platform.operatingSystem};
}

class MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SafeArea(
          child: InAppWebView(
              initialUrlRequest:
                  URLRequest(url: Uri.parse("http://172.16.17.116:8080")),
              onWebViewCreated: (InAppWebViewController controller) {
                WebControl control = WebControl(controller: controller);
                ble = BleCG(controller: control);
                auth = AuthManager(controller: control);
                _controller = controller;
                control.addHandler(WebHandler(nombre: "esMobile", callback: esMobile));

                _controller.setOptions(
                    options: InAppWebViewGroupOptions(
                        crossPlatform:
                            InAppWebViewOptions(supportZoom: false)));
              },
            onReceivedServerTrustAuthRequest: (InAppWebViewController c, URLAuthenticationChallenge challenge) async {
                return ServerTrustAuthResponse(action: ServerTrustAuthResponseAction.PROCEED);
            }
          ),
        ),
        floatingActionButton: FloatingActionButton(
          child: const Icon(Icons.refresh),
          onPressed: () {
            _controller.reload();
          },
        ),
      ),
    );
  }
}

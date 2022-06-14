import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:rxdart/streams.dart';
import 'package:torch_light/torch_light.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:awesome_notifications/awesome_notifications.dart';

import 'package:flutter/services.dart';
import 'package:rxdart/subjects.dart';
import 'package:hex/hex.dart';
import 'package:flutter_ble_lib/flutter_ble_lib.dart';
import 'package:permission_handler/permission_handler.dart';

import 'dart:developer';

var ledPrendida = false;

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

/// Streams are created so that app can respond to notification-related events
/// since the plugin is initialised in the `main` function
final BehaviorSubject<ReceivedNotification> didReceiveLocalNotificationSubject =
BehaviorSubject<ReceivedNotification>();

final BehaviorSubject<String?> selectNotificationSubject =
BehaviorSubject<String?>();

const MethodChannel platform = MethodChannel('cg/ejemplo_notificacion');

class ReceivedNotification {
  ReceivedNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.payload,
  });

  final int id;
  final String? title;
  final String? body;
  final String? payload;
}

String? selectedNotificationPayload;
late BleManager ble;

Future main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Permission.bluetooth.request();
  await Permission.location.request();

  if (Platform.isAndroid) {
    await AndroidInAppWebViewController.setWebContentsDebuggingEnabled(true);
  }

  ble = BleManager();
  await ble.createClient();

  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();
  const AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('@mipmap/ic_launcher');

  final IOSInitializationSettings initializationSettingsIOS =
  IOSInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      onDidReceiveLocalNotification: (
          int id,
          String? title,
          String? body,
          String? payload,
          ) async {
        didReceiveLocalNotificationSubject.add(
          ReceivedNotification(
            id: id,
            title: title,
            body: body,
            payload: payload,
          ),
        );
      });

  final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid, iOS: initializationSettingsIOS);

  await flutterLocalNotificationsPlugin.initialize(initializationSettings,
      onSelectNotification: (String? payload) async {
        if (payload != null) {
          debugPrint('notification payload: $payload');
        }
        selectedNotificationPayload = payload;
        selectNotificationSubject.add(payload);
      });

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  MyAppState createState() => MyAppState();
}

late InAppWebViewController _controller;

dynamic buscarBLE(List<dynamic> params) async {
  log("buscando BLE");

  ble.startPeripheralScan().listen((event) {
    ejecutar(
        "addDevice({ mac: '${event.peripheral.identifier}', uuid: ${event.advertisementData.manufacturerData}, rssi: ${event.rssi} })");
  });
}

dynamic alternarLED(List<dynamic> params) async {
  try {
    final ledDisponible = await TorchLight.isTorchAvailable();
    if (ledDisponible) {
      ledPrendida = !ledPrendida;
      if (ledPrendida) {
        await TorchLight.enableTorch();
      } else {
        TorchLight.disableTorch();
      }
    }
  } on Exception catch (_) {}
}

dynamic push1(List<dynamic> params) async {
  const AndroidNotificationDetails androidPlatformChannelSpecifics =
  AndroidNotificationDetails('id_canal_cg', 'Notificación de prueba',
      channelDescription: 'Acá aparecen notificaciones de prueba',
      importance: Importance.max,
      priority: Priority.max,
      ticker: 'ticker');
  const NotificationDetails platformChannelSpecifics =
  NotificationDetails(android: androidPlatformChannelSpecifics);
  // await Future.delayed(const Duration(seconds: 5));
  await flutterLocalNotificationsPlugin.show(
      0, 'Buen día! 😁', params[0]["mensaje"], platformChannelSpecifics,
      payload: 'item x');
}

dynamic push2(List<dynamic> params) async {
  AwesomeNotifications().createNotification(
      content: NotificationContent(
          id: 10,
          channelKey: 'cg_awesome_canal',
          title: 'Awesome Notification',
          body: params[0]["mensaje"]));
}

Peripheral? device;
Characteristic? characteristic;

dynamic conectarBLE(List<dynamic> params) async {
  ble.stopPeripheralScan();

  String id = params[0]["mac"];
  String service = params[0]["serviceID"];
  ejecutar(
      "estadoConexion({mac: '$id', estado: 'intentando conectar a $id...'})");

  device = ble.createUnsafePeripheral(id);
  device!.observeConnectionState().listen((event) {
    ejecutar("estadoConexion({mac: '$id', estado: '${event.name}'})");
  });

  await device!.connect();
  await device!.discoverAllServicesAndCharacteristics();

  List<Characteristic> chars = await device!.characteristics(service);

  if (chars.isEmpty) {
    log("Error: No se encontraron características");
    return;
  }

  characteristic = chars[0];
  characteristic!.isIndicatable = true;
  characteristic!.monitor().listen((answer) {
    ejecutar("notify({mac: '${device!.identifier}', estado: $answer})");
    log("Respuesta $answer");
  });
  ejecutar("estadoConexion({mac: '$id', estado: 'listo'})");
}

dynamic desconectarBLE(List<dynamic> params) async {
  if (device != null || await device!.isConnected()) {
    String id = device!.identifier;
    await device!.disconnectOrCancelConnection();
    ejecutar("estadoConexion({mac: '$id', estado: 'disconnected'})");
  }
}

dynamic writeCharBLE(List<dynamic> params) async {

  log("Escribiendo ${params[0]["value"]}...");
  Uint8List value = Uint8List.fromList(HEX.decode(params[0]["value"]));
  log("Valor a escribir: $value");

  await Future.delayed(const Duration(milliseconds: 50));
  await characteristic!.write(value, true);
}

void ejecutar(String funcion) {
  _controller.evaluateJavascript(source: funcion);
}

class MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SafeArea(
          child: InAppWebView(
            // initialData: InAppWebViewInitialData(data: "cargando..."),
              initialUrlRequest:
              URLRequest(url: Uri.parse("http://172.16.17.116:8080")),
              // "http://172.16.17.116:50719/Access/Landing.aspx")),
              onWebViewCreated: (InAppWebViewController controller) {
                _controller = controller;
                _controller.setOptions(
                    options: InAppWebViewGroupOptions(
                        crossPlatform:
                        InAppWebViewOptions(supportZoom: false)));
                // _controller.loadFile(assetFilePath: "assets/testPage.html");

                _controller.addJavaScriptHandler(
                    handlerName: "led", callback: alternarLED);
                _controller.addJavaScriptHandler(
                    handlerName: "push1", callback: push1);
                _controller.addJavaScriptHandler(
                    handlerName: "push2", callback: push2);
                _controller.addJavaScriptHandler(
                    handlerName: "ble", callback: buscarBLE);
                _controller.addJavaScriptHandler(
                    handlerName: "conectar", callback: conectarBLE);
                _controller.addJavaScriptHandler(
                    handlerName: "writeBLE", callback: writeCharBLE);
                _controller.addJavaScriptHandler(
                    handlerName: "desconectar", callback: desconectarBLE);
              }),
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

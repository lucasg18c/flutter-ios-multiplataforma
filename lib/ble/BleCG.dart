import 'dart:collection';
import 'dart:developer';
import 'dart:typed_data';

import 'package:flutter_ble_lib/flutter_ble_lib.dart';
import 'package:hex/hex.dart';
import 'package:marco_multiplataforma/BLE/Parser.dart';
import 'package:marco_multiplataforma/web/WebControl.dart';
import 'package:marco_multiplataforma/web/WebHandler.dart';

class BleCG {
  late BleManager ble;
  WebControl controller;
  Peripheral? device;
  late Map<String, List<Characteristic>> caracteristicas = HashMap();
  late List<Service> servicios;

  BleCG({required this.controller}) {
    iniciarBle();
    iniciarHandlers();
  }

  dynamic buscarDispositivos(List<dynamic> params) async {
    log("Buscando dispositivos");
    ble.startPeripheralScan().listen((d) {
      controller.run("dispositivoEncontrado( ${Parser.device(d)} )");
    });
  }

  dynamic conectar(List<dynamic> params) async {
    log("Conectando a dispositivo $params");
    String deviceID = params[0]["deviceID"];

    controller.run("estadoConexion({"
        "deviceID: '$deviceID', "
        "estado: 'intentando conectar a $deviceID...'}"
        ")");

    device = ble.createUnsafePeripheral(deviceID);
    device!.observeConnectionState().listen((event) {
      controller.run(
          "estadoConexion({deviceID: '$deviceID', estado: '${event.name}'})");
    });

    await device!.connect();
    await device!.discoverAllServicesAndCharacteristics();
    servicios = await device!.services();
    log("Servicios $servicios");
    caracteristicas = HashMap();
    for (var servicio in servicios) {
      caracteristicas[servicio.uuid] = await servicio.characteristics();
    }
    controller.run("estadoConexion({deviceID: '$deviceID', estado: 'listo'})");
    log("Caracteristicas $caracteristicas");
  }

  dynamic desconectar(List<dynamic> params) async {
    log("Desconectando de dispositivo");
    if (device != null || await device!.isConnected()) {
      String id = device!.identifier;
      await device!.disconnectOrCancelConnection();
      controller
          .run("estadoConexion({deviceID: '$id', estado: 'disconnected'})");
    }
  }

  dynamic detenerBusqueda(List<dynamic> params) async {
    log("Detener búsqueda de dispositivos");
    ble.stopPeripheralScan();
  }

  dynamic detenerRespuestas(List<dynamic> params) async {
    log("Detener escucha de respuestas");
    String charID = params[0]["charID"];
    ble.cancelTransaction(charID);
  }

  dynamic escribir(List<dynamic> params) async {
    log("Escribir mensaje BLE $params");
    String serviceID = params[0]["serviceID"];
    String charID = params[0]["charID"];
    Uint8List valor = Uint8List.fromList(HEX.decode(params[0]["valor"]));

    Characteristic? caracteristica = _buscarCaracteristica(serviceID, charID);

    if (caracteristica == null) {
      return; //todo: agregar un canal de errores
    }

    Future.delayed(const Duration(milliseconds: 50));
    caracteristica.write(valor, true);
  }

  dynamic setIndicaciones(List<dynamic> params) async {
    String serviceID = params[0]["serviceID"];
    String charID = params[0]["charID"];
    bool esIndicable = params[0]["esIndicable"];
    log("Set indicaciones $params");

    Characteristic? c = _buscarCaracteristica(serviceID, charID);
    log("Caracteristicas $caracteristicas");
    log("Caracteristica para indiable $c");
    c?.isIndicatable = esIndicable;
  }

  dynamic setNotificaciones(List<dynamic> params) async {
    String serviceID = params[0]["serviceID"];
    String charID = params[0]["charID"];
    bool esNotificable = params[0]["esNotificable"];
    log("Set notificaciones $params");

    Characteristic? c = _buscarCaracteristica(serviceID, charID);
    log("Caracteristicas $caracteristicas");
    log("Caracteristica para notificable $c");
    c?.isNotifiable = esNotificable;
  }

  dynamic escuchar(List<dynamic> params) async {
    String serviceID = params[0]["serviceID"];
    String charID = params[0]["charID"];
    log("Set indicaciones $params");
    _buscarCaracteristica(serviceID, charID)
        ?.monitor(transactionId: charID)
        .listen((answer) {
      controller
          .run("answer({ charID: '$charID', valor: '${HEX.encode(answer)}' })");
    });
  }

  dynamic negociarMTU(List<dynamic> params) async {
    int? mtu = int.tryParse(params[0]["mtu"]);
    mtu = mtu ?? 186;

    int? mtuNegociado = await device?.requestMtu(mtu);
    return {'mtu': mtuNegociado};
  }

  Characteristic? _buscarCaracteristica(String serviceID, String charID) {
    return caracteristicas[serviceID]
        ?.firstWhere((char) => char.uuid == charID);
  }

  void iniciarHandlers() {
    List<WebHandler> handlers = [
      WebHandler(nombre: "buscarDispositivosBLE", callback: buscarDispositivos),
      WebHandler(nombre: "conectarBLE", callback: conectar),
      WebHandler(nombre: "desconectarBLE", callback: desconectar),
      WebHandler(nombre: "escribirBLE", callback: escribir),
      WebHandler(nombre: "detenerBusquedaBLE", callback: detenerBusqueda),
      WebHandler(nombre: "setIndicacionesBLE", callback: setIndicaciones),
      WebHandler(nombre: "detenerRespuestasBLE", callback: detenerRespuestas),
      WebHandler(nombre: "escucharBLE", callback: escuchar),
      WebHandler(nombre: "setNotificableBLE", callback: setNotificaciones),
      WebHandler(nombre: "negociarMTUBLE", callback: negociarMTU),
    ];

    for (var handler in handlers) {
      controller.addHandler(handler);
    }
  }

  void iniciarBle() async {
    ble = BleManager();
    await ble.createClient();
  }
}

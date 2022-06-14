import 'package:local_auth/local_auth.dart';

import '../web/WebControl.dart';
import '../web/WebHandler.dart';

class AuthManager {
  final LocalAuthentication auth = LocalAuthentication();
  WebControl controller;

  AuthManager({required this.controller}) {
    iniciarHandlers();
  }

  dynamic autenticar(List<dynamic> params) async {
    String motivo = params[0]["motivo"];
    bool autenticado = await auth.authenticate(localizedReason: motivo);
    return {"autenticado": autenticado};
  }

  void iniciarHandlers() {
    List<WebHandler> handlers = [
      WebHandler(nombre: "autenticar", callback: autenticar),
    ];

    for (var handler in handlers) {
      controller.addHandler(handler);
    }
  }
}

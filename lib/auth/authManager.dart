import 'dart:developer';

import 'package:local_auth/local_auth.dart';

import '../web/WebControl.dart';
import '../web/WebHandler.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_ios/local_auth_ios.dart';

class AuthManager {
  final LocalAuthentication auth = LocalAuthentication();
  WebControl controller;

  AuthManager({required this.controller}) {
    iniciarHandlers();
  }

  dynamic autenticar(List<dynamic> params) async {
    String motivo = params[0]["motivo"];
    log("Puede ver biometrics: ${await auth.canCheckBiometrics}");
    log("Biometrics disponibles: ${await auth.getAvailableBiometrics()}");

    bool autenticado = await auth.authenticate(
        localizedReason: motivo,
        authMessages: [
          const AndroidAuthMessages(
              biometricHint: "Te doy una pista",
              biometricNotRecognized: "Biometrics no reconocido",
              biometricRequiredTitle: "Uh, validate con biometrics",
              biometricSuccess: "Éxito!",
              cancelButton: "Nah dejá",
              deviceCredentialsRequiredTitle: "Credenciales requeridas",
              deviceCredentialsSetupDescription: "Preparar credenciales",
              goToSettingsButton: "Ir a ajustes",
              goToSettingsDescription: "Descripción, ir a ajustes",
              signInTitle: "A U T E N T I C A T E"),
          const IOSAuthMessages(
              lockOut: "Lock out?",
              goToSettingsDescription: "Descripcion, Ir a ajustes",
              goToSettingsButton: "Ir a ajustes",
              cancelButton: "Cancelar",
              localizedFallbackTitle: "Eee fallback")
        ],
        options: const AuthenticationOptions(biometricOnly: true));
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

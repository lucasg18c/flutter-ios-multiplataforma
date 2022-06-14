import 'package:flutter_ble_lib/flutter_ble_lib.dart';

class Parser {
  static String device(ScanResult device) {
    return "{ "
        "deviceID: '${device.peripheral.identifier}', "
        "manufacturer: ${device.advertisementData.manufacturerData}, "
        "rssi: ${device.rssi}"
        " }";
  }
}

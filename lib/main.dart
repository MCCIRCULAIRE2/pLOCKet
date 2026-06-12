import 'package:flutter/material.dart';
import 'app.dart';
import 'platform/device_info_stub.dart'
    if (dart.library.js_util) 'platform/device_info_web.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  initDeviceInfoForWebImpl();
  runApp(const PLocketApp());
}

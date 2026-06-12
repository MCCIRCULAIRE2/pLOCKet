import 'package:device_info_plus_platform_interface/device_info_plus_platform_interface.dart';
import 'package:device_info_plus/src/device_info_plus_web.dart' as device_info_web;
import 'package:web/web.dart' as html;

void initDeviceInfoForWebImpl() {
  DeviceInfoPlatform.instance = device_info_web.DeviceInfoPlusWebPlugin(html.window.navigator);
}

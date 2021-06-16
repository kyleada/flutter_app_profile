import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_app_profile/main.dart';
import 'package:flutter_driver/driver_extension.dart';

void main() {
  debugProfileBuildsEnabled = true;
  debugProfilePaintsEnabled = true;
  enableFlutterDriverExtension();
  runApp(MyApp());
}
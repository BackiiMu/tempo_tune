import 'package:flutter/services.dart';

class AudioEngine {
  static const channel = MethodChannel('tempotune/audio');
  static const events = EventChannel('tempotune/events');
  Stream<Map<dynamic, dynamic>> get stream =>
      events.receiveBroadcastStream().map((e) => Map<dynamic, dynamic>.from(e));
  Future<void> configure(Map<String, dynamic> values) =>
      channel.invokeMethod('configure', values);
  Future<void> start() => channel.invokeMethod('start');
  Future<void> stop() => channel.invokeMethod('stop');
  Future<void> startMic() => channel.invokeMethod('startMic');
  Future<void> stopMic() => channel.invokeMethod('stopMic');
  Future<void> openSettings() => channel.invokeMethod('openSettings');
}

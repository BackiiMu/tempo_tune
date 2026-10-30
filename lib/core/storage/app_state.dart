import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/tuner/data/tunings.dart';

final appProvider = Provider<AppState>((ref) => throw UnimplementedError());

class AppState extends ChangeNotifier {
  final SharedPreferences prefs;
  Map<String, dynamic> data;
  AppState(this.prefs) : data = _read(prefs);
  static Map<String, dynamic> _read(SharedPreferences p) {
    try {
      return Map<String, dynamic>.from(
        jsonDecode(p.getString('settings') ?? '{}'),
      );
    } catch (_) {
      return {};
    }
  }

  T get<T>(String key, T fallback) =>
      data[key] is T ? data[key] as T : fallback;
  double get bpm => (data['bpm'] as num? ?? 120).toDouble();
  String get meter => get('meter', '4/4');
  double number(String k, double fallback) =>
      (data[k] as num? ?? fallback).toDouble();
  List<Map<String, dynamic>> get presets => (data['presets'] as List? ?? [])
      .map((e) => Map<String, dynamic>.from(e))
      .toList();
  List<Tuning> get customTunings => (data['customTunings'] as List? ?? [])
      .map((e) => Tuning.fromJson(Map<String, dynamic>.from(e)))
      .toList();
  Future<void> set(String k, dynamic v) async {
    data[k] = v;
    notifyListeners();
    final saved = Map<String, dynamic>.from(data);
    if (!get('rememberTuning', true)) saved.remove('tuning');
    await prefs.setString('settings', jsonEncode(saved));
  }

  Future<void> reset() async {
    data = {};
    notifyListeners();
    await prefs.remove('settings');
  }
}

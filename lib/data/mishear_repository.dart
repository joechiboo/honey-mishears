import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'mishear_rule.dart';

/// 負責把 JSON 設定檔讀進來。
/// 之後要支援「線上更新梗」時，只要換掉這一層的實作即可。
class MishearRepository {
  static const String assetPath = 'assets/config/mishear_rules.json';

  Future<MishearConfig> load() async {
    final raw = await rootBundle.loadString(assetPath);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return MishearConfig.fromJson(json);
  }
}

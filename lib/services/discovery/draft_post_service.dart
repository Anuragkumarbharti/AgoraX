import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class DraftPostService {
  static const String _draftKey = 'creania_post_draft_v1';

  static Future<void> saveDraft(Map<String, dynamic> draftData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_draftKey, jsonEncode(draftData));
    } catch (_) {}
  }

  static Future<Map<String, dynamic>?> getDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_draftKey);
      if (str != null && str.isNotEmpty) {
        return jsonDecode(str) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  static Future<void> clearDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_draftKey);
    } catch (_) {}
  }
}

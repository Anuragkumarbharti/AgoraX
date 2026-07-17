import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VoiceRepository {
  /// Invokes backend function to retrieve token, appID, and expire timestamps.
  /// Never stores AppSign or Secrets inside Flutter client code.
  Future<Map<String, dynamic>> fetchVoiceToken(String userId) async {
    try {
      debugPrint('[VoiceRepository] Requesting token for user $userId from backend...');
      final response = await Supabase.instance.client.functions.invoke(
        'zego-token',
        body: {'userId': userId},
      );

      if (response.status != 200) {
        throw Exception('Server returned status ${response.status}: ${response.data}');
      }

      final data = response.data as Map<String, dynamic>;
      debugPrint('[VoiceRepository] Token successfully fetched.');
      return data;
    } catch (e) {
      debugPrint('[VoiceRepository] Error fetching voice token: $e');
      rethrow;
    }
  }
}

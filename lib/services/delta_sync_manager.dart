import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DeltaSyncManager extends GetxService {
  static DeltaSyncManager get to => Get.find();

  static const String _prefPrefix = 'delta_sync_ts_';
  SharedPreferences? _prefs;

  @override
  void onInit() {
    super.onInit();
    _initPrefs();
  }

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Get the last recorded sync timestamp for a given table/key.
  String? getLastSyncTimestamp(String tableKey) {
    return _prefs?.getString('$_prefPrefix$tableKey');
  }

  /// Set the last sync timestamp for a table/key.
  Future<void> setLastSyncTimestamp(String tableKey, String timestamp) async {
    await _prefs?.setString('$_prefPrefix$tableKey', timestamp);
  }

  /// Fetch delta records from Supabase since last sync timestamp.
  /// If no last sync timestamp exists, fetches full page bounds.
  Future<List<Map<String, dynamic>>> fetchDeltaUpdates({
    required String table,
    required String primaryKey,
    String? customFilterColumn,
    dynamic customFilterValue,
    int limit = 50,
  }) async {
    try {
      final lastTs = getLastSyncTimestamp(table);
      var query = Supabase.instance.client.from(table).select();

      if (customFilterColumn != null && customFilterValue != null) {
        query = query.eq(customFilterColumn, customFilterValue);
      }

      if (lastTs != null && lastTs.isNotEmpty) {
        query = query.gt('updated_at', lastTs);
      }

      final response = await query.order('updated_at', ascending: true).limit(limit);
      final List<Map<String, dynamic>> records = List<Map<String, dynamic>>.from(response);

      if (records.isNotEmpty) {
        // Record newest timestamp in batch
        final newestTs = records.last['updated_at']?.toString();
        if (newestTs != null && newestTs.isNotEmpty) {
          await setLastSyncTimestamp(table, newestTs);
        }
        debugPrint('[DeltaSyncManager] Fetched ${records.length} delta updates for table "$table" (Newest TS: $newestTs)');
      } else {
        debugPrint('[DeltaSyncManager] Zero delta updates for table "$table" (Up to date).');
      }

      return records;
    } catch (e) {
      debugPrint('[DeltaSyncManager] Delta sync error for table "$table": $e');
      return [];
    }
  }

  /// Reset sync timestamp for full resync.
  Future<void> clearSyncTimestamp(String tableKey) async {
    await _prefs?.remove('$_prefPrefix$tableKey');
  }
}

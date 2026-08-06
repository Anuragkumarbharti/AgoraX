import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/room/room_governance_model.dart';

class RoomGovernanceController extends GetxController {
  static RoomGovernanceController get to => Get.find<RoomGovernanceController>();

  final Rxn<RoomGovernanceOverview> overview = Rxn<RoomGovernanceOverview>();
  final RxBool isLoading = false.obs;
  final RxBool isEmergencyMode = false.obs;

  Future<void> fetchGovernanceOverview(String roomId) async {
    try {
      isLoading.value = true;
      final response = await Supabase.instance.client.rpc(
        'get_room_governance_overview',
        params: {'p_room_id': roomId},
      );

      if (response != null && response is Map) {
        final data = RoomGovernanceOverview.fromJson(Map<String, dynamic>.from(response));
        overview.value = data;
        isEmergencyMode.value = data.isEmergencyMode;
      }
    } catch (e) {
      debugPrint('Error fetching governance overview: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> promoteMemberV2({
    required String roomId,
    required String targetUserId,
    required String newRole,
    int? expiryHours,
    AdminCustomPermissions? permissions,
  }) async {
    try {
      final response = await Supabase.instance.client.rpc(
        'promote_room_member_role_v2',
        params: {
          'p_room_id': roomId,
          'p_target_user_id': targetUserId,
          'p_new_role': newRole,
          'p_expiry_hours': expiryHours,
          'p_custom_permissions': permissions?.toJson(),
        },
      );

      if (response != null && response['success'] == true) {
        Get.snackbar(
          'Role Promoted 👑',
          'Successfully assigned $newRole role to member.',
          backgroundColor: const Color(0xFF1E293B),
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
        );
        await fetchGovernanceOverview(roomId);
        return true;
      }
      return false;
    } catch (e) {
      Get.snackbar(
        'Promotion Failed ⚠️',
        e.toString().replaceAll('Exception:', '').trim(),
        backgroundColor: Colors.red.shade900,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
      );
      return false;
    }
  }

  Future<bool> demoteMemberV2({
    required String roomId,
    required String targetUserId,
    bool applyCooldown = false,
  }) async {
    try {
      final response = await Supabase.instance.client.rpc(
        'demote_room_member_role_v2',
        params: {
          'p_room_id': roomId,
          'p_target_user_id': targetUserId,
          'p_apply_cooldown': applyCooldown,
        },
      );

      if (response != null && response['success'] == true) {
        Get.snackbar(
          'Role Removed 🛡️',
          'User demoted to Listener role.',
          backgroundColor: const Color(0xFF1E293B),
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
        );
        await fetchGovernanceOverview(roomId);
        return true;
      }
      return false;
    } catch (e) {
      Get.snackbar(
        'Action Blocked 🛡️',
        e.toString().replaceAll('Exception:', '').trim(),
        backgroundColor: Colors.red.shade900,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
      );
      return false;
    }
  }

  Future<bool> issueWarning({
    required String roomId,
    required String targetUserId,
    required String reason,
  }) async {
    try {
      final response = await Supabase.instance.client.rpc(
        'issue_room_warning',
        params: {
          'p_room_id': roomId,
          'p_target_user_id': targetUserId,
          'p_reason': reason,
        },
      );

      if (response != null && response['success'] == true) {
        final level = response['warning_level'];
        final kicked = response['auto_kicked'] == true;
        Get.snackbar(
          kicked ? 'User Auto-Kicked 🥾' : 'Warning Issued ⚠️',
          kicked ? 'Warning 3 reached. User automatically removed.' : 'Warning level $level issued.',
          backgroundColor: Colors.amber.shade900,
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
        );
        await fetchGovernanceOverview(roomId);
        return true;
      }
      return false;
    } catch (e) {
      Get.snackbar(
        'Warning Error ⚠️',
        e.toString().replaceAll('Exception:', '').trim(),
        backgroundColor: Colors.red.shade900,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
      );
      return false;
    }
  }

  Future<bool> toggleEmergencyMode(String roomId, bool enabled) async {
    try {
      final response = await Supabase.instance.client.rpc(
        'toggle_room_emergency_mode',
        params: {
          'p_room_id': roomId,
          'p_enabled': enabled,
        },
      );

      if (response != null && response['success'] == true) {
        isEmergencyMode.value = enabled;
        Get.snackbar(
          enabled ? '🚨 EMERGENCY MODE ENABLED' : '🛡️ Emergency Mode Deactivated',
          enabled
              ? 'Seats locked, chat slowed, mic requests off & audience muted.'
              : 'Normal room governance restored.',
          backgroundColor: enabled ? Colors.red.shade900 : Colors.green.shade900,
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
        );
        await fetchGovernanceOverview(roomId);
        return true;
      }
      return false;
    } catch (e) {
      Get.snackbar(
        'Emergency Action Failed',
        e.toString().replaceAll('Exception:', '').trim(),
        backgroundColor: Colors.red.shade900,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
      );
      return false;
    }
  }
}

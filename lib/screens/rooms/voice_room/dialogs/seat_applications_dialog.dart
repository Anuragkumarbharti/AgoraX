import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:creania/core/theme.dart';
import '../../../../services/room/room_controller.dart';

class SeatApplicationsDialog extends StatefulWidget {
  final String roomId;
  const SeatApplicationsDialog({required this.roomId, Key? key})
      : super(key: key);

  @override
  State<SeatApplicationsDialog> createState() => _SeatApplicationsDialogState();
}

class _SeatApplicationsDialogState extends State<SeatApplicationsDialog> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isChecking = true;
  bool _hasApplied = false;
  String _userRole = 'Listener';
  List<Map<String, dynamic>> _applications = [];

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    setState(() => _isChecking = true);
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) return;

      // 1. Get room role
      final roomRes = await _supabase
          .from('rooms')
          .select()
          .eq('id', widget.roomId)
          .maybeSingle();
      if (roomRes != null) {
        if (roomRes['host_id'] == currentUserId ||
            roomRes['founder_id'] == currentUserId) {
          _userRole = 'Host';
        } else {
          final memberRes = await _supabase
              .from('room_members')
              .select()
              .eq('room_id', widget.roomId)
              .eq('user_id', currentUserId)
              .maybeSingle();
          if (memberRes != null) {
            _userRole = memberRes['role'] ?? 'Listener';
          }
        }
      }

      // 2. Check if current user has pending application
      final appRes = await _supabase
          .from('room_seat_applications')
          .select()
          .eq('room_id', widget.roomId)
          .eq('applicant_id', currentUserId)
          .eq('status', 'pending')
          .maybeSingle();
      _hasApplied = appRes != null;

      // 3. If Host/Co-Host, load all pending applications
      if (_userRole == 'Host' || _userRole == 'Co-Host') {
        final apps = await _supabase
            .from('room_seat_applications')
            .select('*, profiles(username, avatar)')
            .eq('room_id', widget.roomId)
            .eq('status', 'pending');
        _applications = List<Map<String, dynamic>>.from(apps);
      }
    } catch (e) {
      debugPrint('Error fetching seat application details: $e');
    } finally {
      if (mounted) {
        setState(() => _isChecking = false);
      }
    }
  }

  Future<void> _applyForSeat() async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) return;

    try {
      await _supabase.from('room_seat_applications').upsert({
        'room_id': widget.roomId,
        'applicant_id': currentUserId,
        'status': 'pending',
      });
      Get.snackbar('Success', 'Application submitted successfully!');
      _fetchDetails();
    } catch (e) {
      Get.snackbar('Error', 'Failed to apply: $e');
    }
  }

  Future<void> _acceptApplication(
      String id, String applicantId, String applicantName) async {
    try {
      // Find first empty seat
      final emptyIndex = RoomController.to.roomSeatsInfo[widget.roomId]
              ?.indexWhere(
                  (s) => s['userId'] == null && s['isLocked'] != true) ??
          -1;
      if (emptyIndex == -1) {
        Get.snackbar('Error', 'No empty seats available.');
        return;
      }

      // 1. Assign applicant to seat via joinRoomSeat
      await RoomController.to.joinRoomSeat(widget.roomId, emptyIndex);
      await _supabase
          .from('room_seat_applications')
          .update({'status': 'accepted'}).eq('id', id);

      Get.snackbar('Accepted',
          '$applicantName has been assigned to Seat ${emptyIndex + 1}.');
      _fetchDetails();
    } catch (e) {
      Get.snackbar('Error', 'Failed to accept: $e');
    }
  }

  Future<void> _rejectApplication(String id) async {
    try {
      await _supabase.from('room_seat_applications').delete().eq('id', id);
      Get.snackbar('Rejected', 'Application rejected.');
      _fetchDetails();
    } catch (e) {
      Get.snackbar('Error', 'Failed to reject: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isManager = _userRole == 'Host' || _userRole == 'Co-Host';

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: Get.width * 0.9,
        height: 400,
        decoration: BoxDecoration(
          color: context.scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: context.borderColor),
        ),
        padding: const EdgeInsets.all(20),
        child: _isChecking
            ? Center(
                child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(context.primaryColor)))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Seat Applications',
                    style: GoogleFonts.poppins(
                      color: context.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: isManager
                        ? (_applications.isEmpty
                            ? Center(
                                child: Text(
                                  'No pending applications',
                                  style: GoogleFonts.poppins(
                                      color: context.textSecondary,
                                      fontSize: 13),
                                ),
                              )
                            : ListView.builder(
                                itemCount: _applications.length,
                                itemBuilder: (context, index) {
                                  final app = _applications[index];
                                  final profile =
                                      app['profiles'] as Map<String, dynamic>?;
                                  final name = profile?['username'] ?? 'User';
                                  final avatarUrl = profile?['avatar'] ?? '';

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: context.surfaceColor,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color: context.borderColor),
                                    ),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 16,
                                          backgroundImage: avatarUrl.isNotEmpty
                                              ? NetworkImage(avatarUrl)
                                              : null,
                                          child: avatarUrl.isEmpty
                                              ? const Icon(Icons.person,
                                                  size: 16)
                                              : null,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            name,
                                            style: GoogleFonts.poppins(
                                                color: context.textPrimary,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                              Icons.check_circle_outline,
                                              color: Colors.greenAccent),
                                          onPressed: () => _acceptApplication(
                                              app['id'],
                                              app['applicant_id'],
                                              name),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                              Icons.cancel_outlined,
                                              color: Colors.redAccent),
                                          onPressed: () =>
                                              _rejectApplication(app['id']),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ))
                        : Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _hasApplied
                                      ? 'Your application is pending'
                                      : 'Apply to speak on stage',
                                  style: GoogleFonts.poppins(
                                      color: context.textSecondary,
                                      fontSize: 13),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _hasApplied
                                        ? Colors.grey
                                        : context.primaryColor,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 24, vertical: 12),
                                  ),
                                  onPressed: _hasApplied ? null : _applyForSeat,
                                  child: Text(
                                    _hasApplied ? 'Applied' : 'Apply for Seat',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                  Center(
                    child: TextButton(
                      onPressed: () => Get.back(),
                      child: Text('Close',
                          style: GoogleFonts.poppins(
                              color: context.textSecondary)),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

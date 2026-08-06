import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:creania/core/theme.dart';

import '../../../../models/room/room_model.dart';
import '../../../../services/room/room_controller.dart';
import '../../../../widgets/profile/custom_image_editor.dart';
import 'room_settings_management.dart';

class RoomSettingsDialog extends StatefulWidget {
  final String roomId;
  final VoiceRoom room;
  const RoomSettingsDialog({required this.roomId, required this.room, Key? key})
      : super(key: key);

  @override
  State<RoomSettingsDialog> createState() => _RoomSettingsDialogState();
}

class _RoomSettingsDialogState extends State<RoomSettingsDialog> {
  final RoomController _controller = RoomController.to;

  late String _roomName;
  late String _bulletin;
  late String _greetings;
  late String _theme;
  late String _whoCanJoin;
  late String _whoCanBeSeated;
  late String _avatar;
  bool _elitesPriority = true;
  late bool _coHostCanEditCover;
  late bool _adminCanEditCover;

  @override
  void initState() {
    super.initState();
    _roomName = widget.room.name;
    _bulletin = widget.room.bulletin;
    _greetings = widget.room.greetings;
    _theme = widget.room.roomTheme;
    _whoCanJoin = widget.room.whoCanJoin;
    _whoCanBeSeated = widget.room.seatPermissions;
    _avatar = widget.room.avatar ??
        'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=150';
    _coHostCanEditCover = widget.room.coHostCanEditCover;
    _adminCanEditCover = widget.room.adminCanEditCover;
  }

  void _saveField(String field, String value) {
    setState(() {
      if (field == 'name') _roomName = value;
      if (field == 'bulletin') _bulletin = value;
      if (field == 'greetings') _greetings = value;
    });
    _controller.updateRoomSettings(
      widget.roomId,
      name: _roomName,
      bulletin: _bulletin,
      greetings: _greetings,
      theme: _theme,
      whoCanJoin: _whoCanJoin,
      seatPermissions: _whoCanBeSeated,
      avatar: _avatar,
    );
  }

  void _showEditTextField(String title, String field, String initialValue) {
    final textController = TextEditingController(text: initialValue);
    Get.dialog(
      Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: context.secondaryBackgroundColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Edit $title',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: textController,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.black26,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                      onPressed: () => Get.back(),
                      child: const Text('Cancel',
                          style: TextStyle(color: Colors.white54))),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: context.primaryColor),
                    onPressed: () {
                      if (textController.text.trim().isNotEmpty) {
                        _saveField(field, textController.text.trim());
                      }
                      Get.back();
                    },
                    child: const Text('Save'),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  void _showCoverPhotoPicker() {
    final ImagePicker picker = ImagePicker();

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: context.scaffoldBackgroundColor.withOpacity(0.95),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Change Room Cover Photo',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.white),
              title: const Text('Take Photo',
                  style: TextStyle(color: Colors.white)),
              onTap: () async {
                Get.back();
                try {
                  final XFile? image = await picker.pickImage(
                    source: ImageSource.camera,
                    imageQuality: 75,
                    maxWidth: 1024,
                    maxHeight: 1024,
                  );
                  if (image != null) {
                    final editedFile = await CustomImageEditor.editImage(
                        context, io.File(image.path));
                    if (editedFile == null) return;
                    final uploadedUrl = await _controller.uploadRoomCoverPhoto(
                      widget.roomId,
                      io.File(editedFile.path),
                    );
                    if (uploadedUrl != null) {
                      setState(() => _avatar = uploadedUrl);
                      Get.snackbar(
                          'Success', 'Cover photo updated successfully.',
                          snackPosition: SnackPosition.BOTTOM);
                    }
                  }
                } catch (e) {
                  Get.snackbar('Error', 'Failed to pick image: $e',
                      snackPosition: SnackPosition.BOTTOM);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.white),
              title: const Text('Choose from Gallery',
                  style: TextStyle(color: Colors.white)),
              onTap: () async {
                Get.back();
                try {
                  final XFile? image = await picker.pickImage(
                    source: ImageSource.gallery,
                    imageQuality: 75,
                    maxWidth: 1024,
                    maxHeight: 1024,
                  );
                  if (image != null) {
                    final editedFile = await CustomImageEditor.editImage(
                        context, io.File(image.path));
                    if (editedFile == null) return;
                    final uploadedUrl = await _controller.uploadRoomCoverPhoto(
                      widget.roomId,
                      io.File(editedFile.path),
                    );
                    if (uploadedUrl != null) {
                      setState(() => _avatar = uploadedUrl);
                      Get.snackbar(
                          'Success', 'Cover photo updated successfully.',
                          snackPosition: SnackPosition.BOTTOM);
                    }
                  }
                } catch (e) {
                  Get.snackbar('Error', 'Failed to pick image: $e',
                      snackPosition: SnackPosition.BOTTOM);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Remove Cover',
                  style: TextStyle(color: Colors.red)),
              onTap: () async {
                Get.back();
                setState(() => _avatar =
                    'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=150');
                _controller.updateRoomSettings(
                  widget.roomId,
                  avatar:
                      'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=150',
                  roomCoverUrl: '',
                );
                Get.snackbar('Success', 'Cover photo removed.',
                    snackPosition: SnackPosition.BOTTOM);
              },
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Get.back(),
              child:
                  const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
          ],
        ),
      ),
    );
  }

  void _showOptionSelector(
      String title, String field, List<String> options, String currentValue) {
    Get.bottomSheet(
      Container(
        decoration: const BoxDecoration(
          color: Color(0xFF141A28),
          borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24), topRight: Radius.circular(24)),
          border: Border(top: BorderSide(color: Colors.white12, width: 1)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select $title',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...options
                .map((opt) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(opt,
                          style: TextStyle(
                              color: opt == currentValue
                                  ? context.primaryColor
                                  : Colors.white70,
                              fontWeight: opt == currentValue
                                  ? FontWeight.bold
                                  : FontWeight.normal)),
                      trailing: opt == currentValue
                          ? Icon(Icons.check, color: context.primaryColor)
                          : null,
                      onTap: () {
                        setState(() {
                          if (field == 'whoCanJoin') _whoCanJoin = opt;
                          if (field == 'whoCanBeSeated') _whoCanBeSeated = opt;
                          if (field == 'theme') _theme = opt;
                        });
                        _controller.updateRoomSettings(
                          widget.roomId,
                          theme: _theme,
                          whoCanJoin: _whoCanJoin,
                          seatPermissions: _whoCanBeSeated,
                        );
                        Get.back();
                      },
                    ))
                .toList(),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Get.back(),
        ),
        title: Text('Edit the arena',
            style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Basic Information'),
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                children: [
                  _buildListTile('Arena Name',
                      trailingText: _roomName,
                      onTap: () =>
                          _showEditTextField('Arena Name', 'name', _roomName)),
                  _buildDivider(),
                  _buildListTile(
                    'Cover Photo',
                    trailingWidget: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(_avatar,
                          width: 28, height: 28, fit: BoxFit.cover),
                    ),
                    onTap: () {
                      final currentUid =
                          Supabase.instance.client.auth.currentUser?.id;
                      final isHost = widget.room.hostId == currentUid ||
                          widget.room.founderId == currentUid;
                      final isCoHost =
                          widget.room.coOwnerIds.contains(currentUid);
                      final isAdmin = widget.room.adminIds.contains(currentUid);

                      final canEditCover = isHost ||
                          (isCoHost && widget.room.coHostCanEditCover) ||
                          (isAdmin && widget.room.adminCanEditCover);

                      if (canEditCover) {
                        _showCoverPhotoPicker();
                      } else {
                        Get.snackbar(
                          'Permission Denied',
                          'Only Owner/Host or permitted roles can change the cover.',
                          snackPosition: SnackPosition.BOTTOM,
                          backgroundColor: Colors.red.withOpacity(0.8),
                          colorText: Colors.white,
                        );
                      }
                    },
                  ),
                  _buildDivider(),
                  _buildListTile('Background',
                      trailingText: _theme,
                      onTap: () => _showOptionSelector(
                          'Background Theme',
                          'theme',
                          [
                            'Classic Dark',
                            'Purple Velvet',
                            'Emerald Sea',
                            'Cozy Family'
                          ],
                          _theme)),
                  _buildDivider(),
                  _buildListTile('Bulletin',
                      trailingText: _bulletin,
                      onTap: () => _showEditTextField(
                          'Bulletin', 'bulletin', _bulletin)),
                  _buildDivider(),
                  _buildListTile('Greetings',
                      trailingText: _greetings,
                      onTap: () => _showEditTextField(
                          'Greetings', 'greetings', _greetings)),
                  _buildDivider(),
                  _buildListTile('Arena Mode',
                      trailingText: widget.room.type, onTap: () {}),
                ],
              ),
            ),
            const SizedBox(height: 24),

            _buildSectionHeader('Arena Admin'),
            Obx(() {
              final room = _controller.rooms
                      .firstWhereOrNull((r) => r.id == widget.roomId) ??
                  (_controller.rooms.isNotEmpty
                      ? _controller.rooms.first
                      : null);

              if (room == null) return const SizedBox.shrink();

              final activeUserIds =
                  _controller.activeMembers.map((m) => m.userId).toSet();
              final coOwners = List<String>.from(room.coOwnerIds)
                  .where((id) => activeUserIds.contains(id))
                  .toList();
              final admins = List<String>.from(room.adminIds)
                  .where((id) => activeUserIds.contains(id))
                  .toList();
              final starMembers = List<String>.from(room.starMemberIds)
                  .where((id) => activeUserIds.contains(id))
                  .toList();
              final ownerId = room.hostId;

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  children: [
                    RoomSettingsManagement.buildRoleGroupTile(
                      context: context,
                      role: 'Owner',
                      memberIds: [ownerId],
                      color: const Color(0xFFFFD700),
                      room: widget.room,
                    ),

                    _buildDivider(),
                    RoomSettingsManagement.buildRoleGroupTile(
                      context: context,
                      role: 'Co-owner',
                      memberIds: coOwners,
                      color: Colors.amber,
                      room: widget.room,
                    ),

                    _buildDivider(),
                    RoomSettingsManagement.buildRoleGroupTile(
                      context: context,
                      role: 'Admin',
                      memberIds: admins,
                      color: Colors.purpleAccent,
                      room: widget.room,
                    ),

                    _buildDivider(),
                    RoomSettingsManagement.buildRoleGroupTile(
                      context: context,
                      role: 'Star Member',
                      memberIds: starMembers,
                      color: Colors.cyanAccent,
                      room: widget.room,
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 24),

            _buildSectionHeader('Arena Management'),
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                children: [
                  _buildListTile(
                    'Arena Elites take priority in queuing',
                    trailingText: _elitesPriority ? 'YES' : 'NO',
                    onTap: () =>
                        setState(() => _elitesPriority = !_elitesPriority),
                  ),
                  _buildDivider(),
                  _buildListTile('Who Can Join',
                      trailingText: _whoCanJoin,
                      onTap: () => _showOptionSelector(
                          'Who Can Join',
                          'whoCanJoin',
                          ['Everyone', 'Members Only', 'VIP Only'],
                          _whoCanJoin)),
                  _buildDivider(),
                  _buildListTile('Who can be seated',
                      trailingText: _whoCanBeSeated,
                      onTap: () => _showOptionSelector(
                          'Who Can Be Seated',
                          'whoCanBeSeated',
                          ['Everyone', 'Speakers Only', 'Management Only'],
                          _whoCanBeSeated)),
                  _buildDivider(),
                  _buildListTile('Song List',
                      trailingText: '3 Songs', onTap: () {}),
                  _buildDivider(),
                  Obx(() {
                    final liveRoom = _controller.rooms
                            .firstWhereOrNull((r) => r.id == widget.roomId) ??
                        widget.room;
                    return _buildListTile(
                      'Block List',
                      trailingText: '${liveRoom.blockList.length} Users',
                      onTap: () => RoomSettingsManagement.showBlockListManager(context, widget.roomId, liveRoom, _controller),
                    );
                  }),
                  if (widget.room.hostId ==
                          Supabase.instance.client.auth.currentUser?.id ||
                      widget.room.founderId ==
                          Supabase.instance.client.auth.currentUser?.id) ...[
                    _buildDivider(),
                    _buildListTile(
                      'Co-owners can edit cover photo',
                      trailingWidget: Switch(
                        value: _coHostCanEditCover,
                        onChanged: (val) {
                          setState(() => _coHostCanEditCover = val);
                          _controller.updateRoomSettings(
                            widget.roomId,
                            coHostCanEditCover: val,
                          );
                        },
                        activeColor: context.primaryColor,
                      ),
                      onTap: () {},
                    ),
                    _buildDivider(),
                    _buildListTile(
                      'Admins can edit cover photo',
                      trailingWidget: Switch(
                        value: _adminCanEditCover,
                        onChanged: (val) {
                          setState(() => _adminCanEditCover = val);
                          _controller.updateRoomSettings(
                            widget.roomId,
                            adminCanEditCover: val,
                          );
                        },
                        activeColor: context.primaryColor,
                      ),
                      onTap: () {},
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.poppins(
            color: Colors.cyanAccent,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8),
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(height: 1, thickness: 0.5, color: Colors.white12);
  }

  Widget _buildListTile(String title,
      {String? trailingText,
      Widget? trailingWidget,
      required VoidCallback onTap}) {
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      title: Text(title,
          style: GoogleFonts.poppins(
              color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailingWidget != null) trailingWidget,
          if (trailingText != null)
            Text(
              trailingText.length > 22
                  ? '${trailingText.substring(0, 20)}...'
                  : trailingText,
              style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
            ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, color: Colors.white54, size: 16),
        ],
      ),
      onTap: onTap,
    );
  }
}

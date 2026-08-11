import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../services/user/user_profile_cache_manager.dart';

class HelpSupportScreen extends StatefulWidget {
  final String? targetUserId;
  final String? initialCategory;

  const HelpSupportScreen({
    Key? key,
    this.targetUserId,
    this.initialCategory,
  }) : super(key: key);

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> with SingleTickerProviderStateMixin {
  final SupabaseClient _supabase = Supabase.instance.client;
  late TabController _tabController;

  // Form state
  final _formKey = GlobalKey<FormState>();
  final _subjectCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _reportedUserCtrl = TextEditingController();
  final _chatTranscriptCtrl = TextEditingController();
  
  late String _selectedCategory;
  bool _isSubmitting = false;

  // File Attachments
  final List<File> _attachedFiles = [];
  final List<String> _uploadedAttachmentUrls = [];
  bool _isUploadingFiles = false;
  bool _attachChatLogs = false;

  // Tickets list state
  bool _isLoadingTickets = true;
  List<Map<String, dynamic>> _myTickets = [];

  final List<String> _categories = [
    'General',
    'Report',
    'Request',
    'Account Recovery',
    'Bug Report',
    'Harassment',
    'Scam / Fraud',
    'Impersonation',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedCategory = widget.initialCategory ?? 'General';
    if (widget.targetUserId != null && widget.targetUserId!.isNotEmpty) {
      _reportedUserCtrl.text = widget.targetUserId!;
      _selectedCategory = 'Report';
    }
    _fetchMyTickets();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _subjectCtrl.dispose();
    _descriptionCtrl.dispose();
    _reportedUserCtrl.dispose();
    _chatTranscriptCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAttachment() async {
    if (_attachedFiles.length >= 3) {
      Get.snackbar('Limit Reached', 'You can attach up to 3 evidence files.');
      return;
    }

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile != null) {
      setState(() {
        _attachedFiles.add(File(pickedFile.path));
      });
    }
  }

  Future<void> _fetchMyTickets() async {
    final userId = UserProfileCacheManager.currentUserId;
    if (userId.isEmpty) return;

    setState(() => _isLoadingTickets = true);
    try {
      final res = await _supabase
          .from('support_tickets')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      setState(() {
        _myTickets = List<Map<String, dynamic>>.from(res);
        _isLoadingTickets = false;
      });
    } catch (e) {
      debugPrint('[HelpSupportScreen] Error fetching tickets: $e');
      setState(() => _isLoadingTickets = false);
    }
  }

  Future<void> _submitTicket() async {
    if (!_formKey.currentState!.validate()) return;
    final userId = UserProfileCacheManager.currentUserId;
    if (userId.isEmpty) return;

    setState(() => _isSubmitting = true);

    try {
      // 1. Upload files to report-attachments bucket if attached
      _uploadedAttachmentUrls.clear();
      if (_attachedFiles.isNotEmpty) {
        setState(() => _isUploadingFiles = true);
        for (int i = 0; i < _attachedFiles.length; i++) {
          final file = _attachedFiles[i];
          final fileName = 'report_${userId}_${DateTime.now().millisecondsSinceEpoch}_$i.png';
          try {
            await _supabase.storage.from('report-attachments').upload(fileName, file);
            final publicUrl = _supabase.storage.from('report-attachments').getPublicUrl(fileName);
            _uploadedAttachmentUrls.add(publicUrl);
          } catch (uploadErr) {
            debugPrint('[HelpSupportScreen] Attachment upload error: $uploadErr');
          }
        }
        setState(() => _isUploadingFiles = false);
      }

      // Prepare Chat Log Proof Payload if requested
      Map<String, dynamic>? chatLogPayload;
      if (_attachChatLogs && _chatTranscriptCtrl.text.trim().isNotEmpty) {
        chatLogPayload = {
          'transcript': _chatTranscriptCtrl.text.trim(),
          'timestamp': DateTime.now().toIso8601String(),
          'reported_user_id': _reportedUserCtrl.text.trim(),
        };
      }

      // 2. Insert into support_tickets table
      await _supabase.from('support_tickets').insert({
        'user_id': userId,
        'category': _selectedCategory,
        'subject': _subjectCtrl.text.trim(),
        'description': _descriptionCtrl.text.trim(),
        'status': 'Open',
        'attachment_urls': _uploadedAttachmentUrls,
        'chat_transcript': chatLogPayload,
      });

      // 3. Also insert into reports table if it is a user/content report
      if (_selectedCategory == 'Report' ||
          _selectedCategory == 'Harassment' ||
          _selectedCategory == 'Scam / Fraud' ||
          _selectedCategory == 'Impersonation') {
        try {
          await _supabase.from('reports').insert({
            'reporter_id': userId,
            'reported_user_id': _reportedUserCtrl.text.trim().isNotEmpty ? _reportedUserCtrl.text.trim() : null,
            'resource_type': 'user',
            'resource_id': _reportedUserCtrl.text.trim().isNotEmpty ? _reportedUserCtrl.text.trim() : userId,
            'reason': '${_selectedCategory}: ${_subjectCtrl.text.trim()} - ${_descriptionCtrl.text.trim()}',
            'status': 'Open',
            'attachment_urls': _uploadedAttachmentUrls,
            'chat_transcript': chatLogPayload,
          });
        } catch (_) {}
      }

      _subjectCtrl.clear();
      _descriptionCtrl.clear();
      _reportedUserCtrl.clear();
      _chatTranscriptCtrl.clear();
      setState(() {
        _attachedFiles.clear();
        _uploadedAttachmentUrls.clear();
        _selectedCategory = 'General';
        _attachChatLogs = false;
        _isSubmitting = false;
      });

      Get.snackbar(
        'Report Submitted 🎉',
        'Your report and attached evidence have been sent to Creania Moderators.',
        backgroundColor: const Color(0xFF10B981),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );

      _tabController.animateTo(1);
      _fetchMyTickets();
    } catch (e) {
      setState(() => _isSubmitting = false);
      Get.snackbar('Submission Failed', 'Error submitting report: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Help & Support Center',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: context.textPrimary),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Get.back(),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: context.primaryColor,
          labelColor: context.primaryColor,
          unselectedLabelColor: context.textSecondary,
          labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'Submit Report / Ticket'),
            Tab(text: 'My Tickets'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSubmitTab(),
          _buildMyTicketsTab(),
        ],
      ),
    );
  }

  Widget _buildSubmitTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How can we help you?',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: context.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Submit a support request or report violations with attached proof.',
              style: GoogleFonts.poppins(color: context.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 20),

            // Category Selection
            Text(
              'Category / Reason',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: context.textPrimary, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: context.surfaceColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.borderColor, width: 0.5),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCategory,
                  isExpanded: true,
                  dropdownColor: context.surfaceColor,
                  style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 13),
                  items: _categories.map((cat) {
                    return DropdownMenuItem<String>(
                      value: cat,
                      child: Text(cat),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedCategory = val);
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Subject Field
            Text(
              'Subject',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: context.textPrimary, fontSize: 13),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _subjectCtrl,
              style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Brief summary of the issue or report',
                hintStyle: GoogleFonts.poppins(color: context.textSecondary, fontSize: 12),
                filled: true,
                fillColor: context.surfaceColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.borderColor, width: 0.5),
                ),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Please enter a subject';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Description Field
            Text(
              'Details & Evidence Description',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: context.textPrimary, fontSize: 13),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _descriptionCtrl,
              maxLines: 4,
              style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Provide complete details regarding the issue or violation...',
                hintStyle: GoogleFonts.poppins(color: context.textSecondary, fontSize: 12),
                filled: true,
                fillColor: context.surfaceColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.borderColor, width: 0.5),
                ),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Please describe the issue';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // File Attachment Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Attach Screenshots / Files',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: context.textPrimary, fontSize: 13),
                ),
                TextButton.icon(
                  onPressed: _pickAttachment,
                  icon: Icon(Icons.attach_file_rounded, size: 16, color: context.primaryColor),
                  label: Text('Add File', style: GoogleFonts.poppins(color: context.primaryColor, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
            if (_attachedFiles.isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _attachedFiles.length,
                  itemBuilder: (context, index) {
                    return Stack(
                      children: [
                        Container(
                          margin: const EdgeInsets.only(right: 10),
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            image: DecorationImage(image: FileImage(_attachedFiles[index]), fit: BoxFit.cover),
                          ),
                        ),
                        Positioned(
                          top: 2,
                          right: 12,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _attachedFiles.removeAt(index);
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                              child: const Icon(Icons.close, size: 12, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 16),

            // Chat Transcript Section
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Attach Chat Log Transcript Proof',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: context.textPrimary, fontSize: 13),
              ),
              subtitle: Text(
                'Include recent chat message conversation history as proof.',
                style: GoogleFonts.poppins(color: context.textSecondary, fontSize: 11),
              ),
              value: _attachChatLogs,
              activeColor: context.primaryColor,
              onChanged: (val) => setState(() => _attachChatLogs = val),
            ),
            if (_attachChatLogs) ...[
              const SizedBox(height: 8),
              TextFormField(
                controller: _chatTranscriptCtrl,
                maxLines: 3,
                style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'Paste relevant chat messages or transcript context...',
                  hintStyle: GoogleFonts.poppins(color: context.textSecondary, fontSize: 11),
                  filled: true,
                  fillColor: context.surfaceColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: context.borderColor, width: 0.5),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitTicket,
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSubmitting
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _isUploadingFiles ? 'Uploading Evidence...' : 'Submitting...',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                          ),
                        ],
                      )
                    : Text(
                        'Submit Report / Ticket',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                      ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildMyTicketsTab() {
    if (_isLoadingTickets) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_myTickets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_outlined, size: 64, color: context.textSecondary.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text(
              'No Reports or Tickets',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18, color: context.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Your submitted reports & support tickets will be listed here.',
              style: GoogleFonts.poppins(color: context.textSecondary, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchMyTickets,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _myTickets.length,
        itemBuilder: (context, index) {
          final ticket = _myTickets[index];
          final String category = ticket['category'] ?? 'General';
          final String subject = ticket['subject'] ?? 'No Subject';
          final String description = ticket['description'] ?? '';
          final String status = ticket['status'] ?? 'Open';
          final String? adminResponse = ticket['admin_response'];
          final List attachmentUrls = ticket['attachment_urls'] ?? [];
          final String createdAtStr = ticket['created_at'] ?? '';
          DateTime? createdAt;
          if (createdAtStr.isNotEmpty) {
            createdAt = DateTime.tryParse(createdAtStr);
          }

          Color statusColor = Colors.orangeAccent;
          if (status == 'In Review') statusColor = Colors.blueAccent;
          if (status == 'Resolved') statusColor = const Color(0xFF10B981);
          if (status == 'Closed') statusColor = Colors.grey;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.borderColor, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: context.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        category,
                        style: GoogleFonts.poppins(
                          color: context.primaryColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: GoogleFonts.poppins(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  subject,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    color: context.textPrimary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: context.textSecondary,
                    fontSize: 12,
                  ),
                ),
                if (attachmentUrls.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.attach_file_rounded, size: 14, color: context.primaryColor),
                      const SizedBox(width: 4),
                      Text(
                        '${attachmentUrls.length} file evidence attached',
                        style: GoogleFonts.poppins(color: context.primaryColor, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
                if (adminResponse != null && adminResponse.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: context.scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: context.primaryColor.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Moderator Response:',
                          style: GoogleFonts.poppins(
                            color: context.primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          adminResponse,
                          style: GoogleFonts.poppins(
                            color: context.textPrimary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (createdAt != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Submitted ${DateFormat.yMMMd().add_jm().format(createdAt)}',
                    style: GoogleFonts.poppins(
                      color: context.caption,
                      fontSize: 10,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

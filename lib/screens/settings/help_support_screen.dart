import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../services/user/user_profile_cache_manager.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({Key? key}) : super(key: key);

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> with SingleTickerProviderStateMixin {
  final SupabaseClient _supabase = Supabase.instance.client;
  late TabController _tabController;

  // New ticket form state
  final _formKey = GlobalKey<FormState>();
  final _subjectCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  String _selectedCategory = 'General';
  bool _isSubmitting = false;

  // Tickets list state
  bool _isLoadingTickets = true;
  List<Map<String, dynamic>> _myTickets = [];

  final List<String> _categories = [
    'General',
    'Report',
    'Request',
    'Account Recovery',
    'Bug Report',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchMyTickets();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _subjectCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
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
      await _supabase.from('support_tickets').insert({
        'user_id': userId,
        'category': _selectedCategory,
        'subject': _subjectCtrl.text.trim(),
        'description': _descriptionCtrl.text.trim(),
        'status': 'Open',
      });

      _subjectCtrl.clear();
      _descriptionCtrl.clear();
      setState(() {
        _selectedCategory = 'General';
        _isSubmitting = false;
      });

      Get.snackbar(
        'Ticket Submitted 🎉',
        'Your support request has been submitted to Creania Support.',
        backgroundColor: const Color(0xFF10B981),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );

      _tabController.animateTo(1);
      _fetchMyTickets();
    } catch (e) {
      setState(() => _isSubmitting = false);
      Get.snackbar('Submission Failed', 'Error submitting ticket: $e');
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
            Tab(text: 'Submit Request'),
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
              'Submit a support request or report an issue directly to our team.',
              style: GoogleFonts.poppins(color: context.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 20),

            // Category Selection
            Text(
              'Category',
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
                hintText: 'Brief summary of the issue',
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
              'Details / Description',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: context.textPrimary, fontSize: 13),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _descriptionCtrl,
              maxLines: 5,
              style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Provide complete details regarding your issue or inquiry...',
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
                  return 'Please describe your issue';
                }
                return null;
              },
            ),
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
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        'Submit Ticket',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                      ),
              ),
            ),
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
              'No Support Tickets',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18, color: context.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Your submitted support tickets will be listed here.',
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
                          'Support Response:',
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

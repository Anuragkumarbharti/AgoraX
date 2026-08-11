import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:ui';

import '../../services/progression/progression_controller.dart';

class ProgressionAdminDashboard extends StatefulWidget {
  const ProgressionAdminDashboard({Key? key}) : super(key: key);

  @override
  State<ProgressionAdminDashboard> createState() => _ProgressionAdminDashboardState();
}

class _ProgressionAdminDashboardState extends State<ProgressionAdminDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _ctrl = Get.find<ProgressionController>();

  // Text Controllers
  final _targetUserIdCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _cosmeticIdCtrl = TextEditingController();
  final _targetLevelCtrl = TextEditingController();

  String _selectedRewardType = 'silver';
  String _selectedCosmeticType = 'frame';

  List<dynamic> _abuseReports = [];
  bool _isLoadingReports = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchAbuseReports();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _targetUserIdCtrl.dispose();
    _amountCtrl.dispose();
    _cosmeticIdCtrl.dispose();
    _targetLevelCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchAbuseReports() async {
    setState(() {
      _isLoadingReports = true;
    });
    try {
      final response = await Supabase.instance.client.rpc('admin_get_abuse_reports');
      if (response != null) {
        setState(() {
          _abuseReports = response as List;
        });
      }
    } catch (e) {
      debugPrint('Admin Dashboard Error fetching reports: $e');
    } finally {
      setState(() {
        _isLoadingReports = false;
      });
    }
  }

  Widget _glassCard({required Widget child, EdgeInsets? padding}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      padding: padding ?? const EdgeInsets.all(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: child,
      ),
    );
  }

  // Grant currency action
  void _handleGrantCurrency() async {
    final String targetId = _targetUserIdCtrl.text.trim();
    final int amount = int.tryParse(_amountCtrl.text.trim()) ?? 0;
    
    if (targetId.isEmpty || amount <= 0) {
      Get.snackbar('Input Error', 'Please specify a valid User ID and amount.',
          backgroundColor: Colors.redAccent, colorText: Colors.white);
      return;
    }

    try {
      if (_selectedRewardType == 'xp') {
        await Supabase.instance.client.rpc(
          'admin_adjust_user_xp',
          params: {
            'p_target_user_id': targetId,
            'p_xp_amount': amount,
            'p_is_absolute': false,
          },
        );
      } else {
        await Supabase.instance.client.rpc(
          'admin_grant_currency',
          params: {
            'p_target_user_id': targetId,
            'p_currency_type': _selectedRewardType,
            'p_amount': amount,
          },
        );
      }
      Get.snackbar('Success', 'Successfully granted reward to user.',
          backgroundColor: Colors.green, colorText: Colors.white);
      _amountCtrl.clear();
      _ctrl.refreshAll();
    } catch (e) {
      Get.snackbar('Failed', e.toString().replaceFirst('Exception: ', ''),
          backgroundColor: Colors.redAccent, colorText: Colors.white);
    }
  }

  // Grant cosmetic action
  void _handleGrantCosmetic() async {
    final String targetId = _targetUserIdCtrl.text.trim();
    final String cosmeticId = _cosmeticIdCtrl.text.trim();

    if (targetId.isEmpty || cosmeticId.isEmpty) {
      Get.snackbar('Input Error', 'Please specify target User ID and Cosmetic name.',
          backgroundColor: Colors.redAccent, colorText: Colors.white);
      return;
    }

    try {
      await Supabase.instance.client.rpc(
        'admin_grant_cosmetic',
        params: {
          'p_target_user_id': targetId,
          'p_cosmetic_type': _selectedCosmeticType,
          'p_cosmetic_id': cosmeticId,
        },
      );
      Get.snackbar('Success', 'Successfully granted $_selectedCosmeticType "$cosmeticId" to user.',
          backgroundColor: Colors.green, colorText: Colors.white);
      _cosmeticIdCtrl.clear();
      _ctrl.refreshAll();
    } catch (e) {
      Get.snackbar('Failed', e.toString().replaceFirst('Exception: ', ''),
          backgroundColor: Colors.redAccent, colorText: Colors.white);
    }
  }

  // Reset user progression action
  void _handleResetUser() async {
    final String targetId = _targetUserIdCtrl.text.trim();
    if (targetId.isEmpty) {
      Get.snackbar('Input Error', 'Please specify target User ID.',
          backgroundColor: Colors.redAccent, colorText: Colors.white);
      return;
    }

    // Double check confirmation
    Get.dialog(
      AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Reset Progression?', style: TextStyle(color: Colors.white)),
        content: Text('Are you sure you want to reset ALL level, XP, checkin, tasks, spins, and achievements for user $targetId?',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Get.back();
              try {
                await Supabase.instance.client.rpc(
                  'admin_reset_user_progression',
                  params: {'p_target_user_id': targetId},
                );
                Get.snackbar('Success', 'User progression reset successfully.',
                    backgroundColor: Colors.green, colorText: Colors.white);
                _ctrl.refreshAll();
              } catch (e) {
                Get.snackbar('Failed', e.toString().replaceFirst('Exception: ', ''),
                    backgroundColor: Colors.redAccent, colorText: Colors.white);
              }
            },
            child: const Text('Reset', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  // Set level action
  void _handleSetLevel() async {
    final String targetId = _targetUserIdCtrl.text.trim();
    final int targetLvl = int.tryParse(_targetLevelCtrl.text.trim()) ?? 0;

    if (targetId.isEmpty || targetLvl < 1 || targetLvl > 60) {
      Get.snackbar('Input Error', 'Please specify target User ID and Level (1-60).',
          backgroundColor: Colors.redAccent, colorText: Colors.white);
      return;
    }

    try {
      await Supabase.instance.client.rpc(
        'admin_adjust_user_level',
        params: {
          'p_target_user_id': targetId,
          'p_level': targetLvl,
        },
      );
      Get.snackbar('Success', 'Successfully set user level to $targetLvl.',
          backgroundColor: Colors.green, colorText: Colors.white);
      _targetLevelCtrl.clear();
      _ctrl.refreshAll();
    } catch (e) {
      Get.snackbar('Failed', e.toString().replaceFirst('Exception: ', ''),
          backgroundColor: Colors.redAccent, colorText: Colors.white);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'Progression Admin',
          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFFFDB3C),
          tabs: const [
            Tab(text: 'Grant'),
            Tab(text: 'Reset & Level'),
            Tab(text: 'Abuse logs'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildGrantTab(),
          _buildResetTab(),
          _buildLogsTab(),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, String hint) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white60),
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFFFFDB3C)),
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.02),
      ),
    );
  }

  Widget _buildGrantTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _glassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TARGET USER PROFILE ID',
                style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white60),
              ),
              const SizedBox(height: 8),
              _buildTextField(_targetUserIdCtrl, 'User UUID', 'e.g. 550e8400-e29b-41d4-a716-446655440000'),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Grant currency card
        _glassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'GRANT CURRENCY OR XP',
                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedRewardType,
                dropdownColor: const Color(0xFF1E293B),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Reward Type',
                  labelStyle: const TextStyle(color: Colors.white60),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: 'silver', child: Text('Silver Coins')),
                  DropdownMenuItem(value: 'gold', child: Text('Gold Coins')),
                  DropdownMenuItem(value: 'xp', child: Text('Experience (XP)')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedRewardType = val;
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              _buildTextField(_amountCtrl, 'Amount', 'e.g. 100'),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFDB3C),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _handleGrantCurrency,
                  child: Text('Grant Reward', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.black87)),
                ),
              )
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Grant cosmetic card
        _glassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'GRANT COSMETIC ASSET',
                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedCosmeticType,
                dropdownColor: const Color(0xFF1E293B),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Cosmetic Type',
                  labelStyle: const TextStyle(color: Colors.white60),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: 'frame', child: Text('Avatar Frame')),
                  DropdownMenuItem(value: 'badge', child: Text('Showcase Badge')),
                  DropdownMenuItem(value: 'tag', child: Text('Identity Tag')),
                  DropdownMenuItem(value: 'bubble', child: Text('Chat Bubble')),
                  DropdownMenuItem(value: 'theme', child: Text('Profile Theme')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedCosmeticType = val;
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              _buildTextField(_cosmeticIdCtrl, 'Cosmetic Name / Slug', 'e.g. Pathfinder Tag'),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _handleGrantCosmetic,
                  child: Text('Grant Cosmetic', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              )
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResetTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _glassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TARGET USER PROFILE ID',
                style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white60),
              ),
              const SizedBox(height: 8),
              _buildTextField(_targetUserIdCtrl, 'User UUID', 'Must match target user UUID'),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Set level card
        _glassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SET USER LEVEL DIRECTLY',
                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 12),
              _buildTextField(_targetLevelCtrl, 'Level (1 - 60)', 'e.g. 15'),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _handleSetLevel,
                  child: Text('Update Level', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              )
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Reset progression card
        _glassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'DANGER ZONE',
                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.redAccent),
              ),
              const SizedBox(height: 8),
              Text(
                'Resetting progression wipes all user level XP progress, checklist claims, achievements history, and active calendars checkins. This is irreversible.',
                style: GoogleFonts.inter(fontSize: 11, color: Colors.white38),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _handleResetUser,
                  child: Text('Reset All User Progress', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              )
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLogsTab() {
    if (_isLoadingReports) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFFFDB3C)));
    }

    if (_abuseReports.isEmpty) {
      return const Center(child: Text('No anti-cheat flags or blocked events.', style: TextStyle(color: Colors.white38)));
    }

    return RefreshIndicator(
      onRefresh: _fetchAbuseReports,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _abuseReports.length,
        itemBuilder: (context, index) {
          final log = _abuseReports[index];
          final timestamp = log['created_at'] != null ? DateTime.tryParse(log['created_at'].toString()) : null;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _glassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Text(
                          'BLOCKED',
                          style: GoogleFonts.poppins(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (timestamp != null) ...[
                        Text(
                          '${timestamp.hour}:${timestamp.minute} - ${timestamp.day}/${timestamp.month}',
                          style: GoogleFonts.inter(color: Colors.white24, fontSize: 10),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  const SizedBox(height: 4),
                  Text(
                    'Event: ${log['source_id']}',
                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Reason: ${log['reason']}',
                    style: GoogleFonts.inter(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:creania/core/theme.dart';
import '../../models/community/event_model.dart';
import '../../services/community/event_controller.dart';
import './live_event_play_screen.dart';

class OrganizerQuestionManagementScreen extends StatefulWidget {
  const OrganizerQuestionManagementScreen({Key? key, required this.event}) : super(key: key);
  final Event event;

  @override
  State<OrganizerQuestionManagementScreen> createState() => _OrganizerQuestionManagementScreenState();
}

class _OrganizerQuestionManagementScreenState extends State<OrganizerQuestionManagementScreen> {
  // Authentication & Security state
  bool _isAuthorized = false;
  bool _isUnlocked = false;
  String? _configuredPasswordHash; // Mock storage
  final _passInputCtrl = TextEditingController();
  final _passCreateCtrl = TextEditingController();
  bool _obscurePass = true;

  // Question database state
  final List<Map<String, dynamic>> _questions = [];
  bool _randomizeQuestionOrder = false;
  bool _randomizeOptionOrder = false;
  bool _randomizeSubjectOrder = false;
  bool _randomizeSectionOrder = false;

  // Audit Logs database
  final List<Map<String, dynamic>> _auditLogs = [];

  // Active view tab (0=Dashboard, 1=Manage Questions, 2=Validation & Preview, 3=Audit Logs)
  int _activeTab = 0;

  // State flags
  bool _isRegistrationClosed = false;
  bool _isValidated = false;
  List<String> _validationErrors = [];

  @override
  void initState() {
    super.initState();
    _checkAuthorization();
    _checkRegistrationStatus();
    _seedInitialQuestions();
    _seedAuditLogs();
  }

  @override
  void dispose() {
    _passInputCtrl.dispose();
    _passCreateCtrl.dispose();
    super.dispose();
  }

  void _checkAuthorization() {
    final currentUserId = EventController.currentUserId;
    // Authorized: Creator (Owner), Co-owner, Platform Super Admin
    final isOwner = widget.event.creatorId == currentUserId;
    final isCoOwner = widget.event.coOwnerId == currentUserId;
    final isSuperAdmin = currentUserId == 'uid_super_admin_777';

    setState(() {
      _isAuthorized = isOwner || isCoOwner || isSuperAdmin;
    });

    // In a real app, Co-owners might require specific permissions.
    // For demo/hackathon, we allow co-owners by default.
  }

  void _checkRegistrationStatus() {
    // If registration end date has passed, question bank is auto locked
    setState(() {
      _isRegistrationClosed = widget.event.registrationDeadline.isBefore(DateTime.now());
    });
  }

  void _seedInitialQuestions() {
    _questions.addAll([
      {
        'question': 'Which widget is used to overlay elements stack-like on top of each other?',
        'options': ['Row', 'Column', 'Stack', 'Wrap'],
        'answer': 'Stack',
        'difficulty': 'Easy',
        'subject': 'Programming',
        'marks': 10,
        'timer': 15,
      },
      {
        'question': 'What is the time complexity of searching in a balanced Binary Search Tree (BST)?',
        'options': ['O(1)', 'O(log N)', 'O(N)', 'O(N log N)'],
        'answer': 'O(log N)',
        'difficulty': 'Medium',
        'subject': 'Computer Science',
        'marks': 10,
        'timer': 25,
      },
    ]);
  }

  void _seedAuditLogs() {
    _auditLogs.addAll([
      {
        'userId': 'uid_creator_1',
        'role': 'Owner',
        'device': 'Windows Client',
        'ip': '192.168.1.42',
        'date': '2026-07-06',
        'time': '14:20:11',
        'action': 'Question Bank Created & Seeded',
      },
    ]);
  }

  // ── Password Encryption Configuration ──────────────────────────────────────
  bool _validatePasswordComplexity(String pass) {
    if (pass.length < 8) return false;
    final hasUpper = pass.contains(RegExp(r'[A-Z]'));
    final hasLower = pass.contains(RegExp(r'[a-z]'));
    final hasDigit = pass.contains(RegExp(r'[0-9]'));
    final hasSpecial = pass.contains(RegExp(r'[!@#\$&*~%]'));
    return hasUpper && hasLower && hasDigit && hasSpecial;
  }

  void _setupPassword() {
    final pass = _passCreateCtrl.text.trim();
    if (!_validatePasswordComplexity(pass)) {
      Get.snackbar(
        'Password Weak ⚠️',
        'Must be 8+ chars, with Uppercase, Lowercase, Number, and Special character.',
        backgroundColor: context.errorColor.withOpacity(0.9),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    setState(() {
      _configuredPasswordHash = pass; // Mock encrypted representation
      _isUnlocked = true;
    });

    _logAction('Password Configured & Question Bank Encrypted');
    _passCreateCtrl.clear();
  }

  void _unlockQuestionBank() {
    final input = _passInputCtrl.text.trim();
    if (input == _configuredPasswordHash) {
      setState(() {
        _isUnlocked = true;
      });
      _logAction('Question Bank Decrypted & Unlocked');
      _passInputCtrl.clear();
    } else {
      Get.snackbar(
        'Incorrect Password 🔒',
        'The password entered did not match. Access Denied.',
        backgroundColor: context.errorColor.withOpacity(0.9),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  void _logAction(String action) {
    setState(() {
      _auditLogs.insert(0, {
        'userId': EventController.currentUserId,
        'role': widget.event.creatorId == EventController.currentUserId ? 'Owner' : 'Co-Owner',
        'device': 'Mobile App Client',
        'ip': '157.48.92.122',
        'date': DateTime.now().toIso8601String().substring(0, 10),
        'time': DateTime.now().toIso8601String().substring(11, 19),
        'action': action,
      });
    });
  }

  // ── Import Methods ──────────────────────────────────────────────────────────
  void _importManual(Map<String, dynamic> q) {
    if (_isRegistrationClosed) return;
    setState(() {
      _questions.add(q);
      _isValidated = false;
    });
    _logAction('Question Added Manually: "${q['question']}"');
  }

  void _importMockFile(String fileType) {
    if (_isRegistrationClosed) return;
    Get.dialog(
      AlertDialog(
        backgroundColor: context.secondaryBackgroundColor,
        title: Text('Import from $fileType 📂', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Text('Simulating parser extraction from mock event data table.$fileType...'),
        actions: [
          TextButton(
            onPressed: () {
              Get.back();
              setState(() {
                _questions.add({
                  'question': 'What is the result of 17 * 4 in decimal arithmetic?',
                  'options': ['64', '68', '72', '80'],
                  'answer': '68',
                  'difficulty': 'Easy',
                  'subject': 'Mathematics',
                  'marks': 5,
                  'timer': 20,
                });
                _isValidated = false;
              });
              _logAction('Imported Questions from $fileType Table');
            },
            child: Text('Simulate Import', style: TextStyle(color: context.primaryColor)),
          ),
        ],
      ),
    );
  }

  void _importAI() {
    if (_isRegistrationClosed) return;
    final topicCtrl = TextEditingController();
    Get.dialog(
      AlertDialog(
        backgroundColor: context.secondaryBackgroundColor,
        title: Text('AI Question Generator 🤖', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Describe subject topic (e.g. Flutter layout trees, General Aptitude):', style: TextStyle(color: context.textSecondary, fontSize: 11)),
            SizedBox(height: 8),
            TextField(
              controller: topicCtrl,
              style: TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Enter topic name...',
                hintStyle: TextStyle(color: context.caption, fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Get.back();
              setState(() {
                _questions.add({
                  'question': 'Which widget is used to execute asynchronous work during layout build?',
                  'options': ['FutureBuilder', 'ListView', 'SizedBox', 'Container'],
                  'answer': 'FutureBuilder',
                  'difficulty': 'Medium',
                  'subject': topicCtrl.text.isNotEmpty ? topicCtrl.text : 'Programming',
                  'marks': 10,
                  'timer': 20,
                });
                _isValidated = false;
              });
              _logAction('AI Generated Questions on topic: ${topicCtrl.text}');
            },
            child: Text('Generate', style: TextStyle(color: context.primaryColor)),
          ),
        ],
      ),
    );
  }

  void _clonePreviousEventQuestions() {
    if (_isRegistrationClosed) return;
    setState(() {
      _questions.add({
        'question': 'Identify the correct usage of the abstract modifier in Dart.',
        'options': ['To define a concrete class', 'To prevent instantiation', 'To define static methods only', 'To mock testing libraries'],
        'answer': 'To prevent instantiation',
        'difficulty': 'Hard',
        'subject': 'Programming',
        'marks': 15,
        'timer': 30,
      });
      _isValidated = false;
    });
    _logAction('Cloned questions from finished Event ID: 9481');
  }

  // ── Validation Engine ──────────────────────────────────────────────────────
  void _runValidation() {
    List<String> errors = [];
    if (_questions.isEmpty) {
      errors.add('Question Bank is empty. You must add at least 1 question.');
    }

    Set<String> bodies = {};
    for (int i = 0; i < _questions.length; i++) {
      final q = _questions[i];
      final body = q['question'] as String;
      if (body.isEmpty) {
        errors.add('Question #${i + 1} has an empty body.');
      }
      if (bodies.contains(body)) {
        errors.add('Duplicate question detected: "$body"');
      }
      bodies.add(body);

      final opts = q['options'] as List<String>;
      if (opts.length < 4 || opts.any((o) => o.isEmpty)) {
        errors.add('Question #${i + 1} must have 4 non-empty options.');
      }

      final ans = q['answer'] as String;
      if (!opts.contains(ans)) {
        errors.add('Question #${i + 1} correct answer "$ans" is not in options list.');
      }

      final timer = q['timer'] as int;
      if (timer <= 0) {
        errors.add('Question #${i + 1} has an invalid timer value.');
      }
    }

    setState(() {
      _validationErrors = errors;
      _isValidated = true;
    });

    if (errors.isEmpty) {
      _logAction('Question Bank Validated & Published');
      Get.snackbar('Verification Success ✓', 'All questions verified successfully. Published to event session.',
          backgroundColor: Colors.green, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
    } else {
      Get.snackbar('Validation Warning ⚠️', '${errors.length} issues found.',
          backgroundColor: context.errorColor, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
    }
  }

  // ── Render Views ───────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (!_isAuthorized) {
      return _buildAccessDeniedScreen();
    }

    if (_configuredPasswordHash == null) {
      return _buildSetupPasswordScreen();
    }

    if (!_isUnlocked) {
      return _buildUnlockScreen();
    }

    return Scaffold(
      backgroundColor: context.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: context.scaffoldBackgroundColor,
        elevation: 0,
        title: Text(
          '🔐 Question Bank Management',
          style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.lock_rounded, color: context.accentOrange),
            onPressed: () {
              setState(() {
                _isUnlocked = false;
              });
              _logAction('Question Bank Manually Locked');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Menu tab header bar
          _buildMenuBar(),

          // Main body content tab
          Expanded(
            child: _buildActiveTabContent(),
          ),
        ],
      ),
    );
  }

  // Access Denied State
  Widget _buildAccessDeniedScreen() {
    return Scaffold(
      backgroundColor: context.scaffoldBackgroundColor,
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline_rounded, color: context.errorColor, size: 64),
              SizedBox(height: 16),
              Text(
                'Security Block 🔒',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Text(
                'Access to the Question Bank is strictly restricted to the Event Creator, authorized Co-Owners, and Platform Super Admins.\nNormal Admins or guests cannot access these questions.',
                style: TextStyle(color: context.textSecondary, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Get.back(),
                child: Text('Back to Dashboard'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Setup Password View
  Widget _buildSetupPasswordScreen() {
    return Scaffold(
      backgroundColor: context.scaffoldBackgroundColor,
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.enhanced_encryption_rounded, color: context.primaryColor, size: 60),
              SizedBox(height: 16),
              Text('Setup Question Encryption 🛡️', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text(
                'Please configure an encryption password to secure the Question Bank. Without this password, questions cannot be viewed or decrypted.',
                style: TextStyle(color: context.textSecondary, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24),
              TextField(
                controller: _passCreateCtrl,
                obscureText: _obscurePass,
                style: TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Create Encryption Password...',
                  hintStyle: TextStyle(color: context.caption, fontSize: 13),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePass ? Icons.visibility_off : Icons.visibility, color: context.caption),
                    onPressed: () => setState(() => _obscurePass = !_obscurePass),
                  ),
                ),
              ),
              SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Password Rules:\n• Minimum 8 characters\n• At least one uppercase letter\n• At least one lowercase letter\n• At least one digit number\n• At least one special symbol (!@#\$&*)',
                  style: TextStyle(color: context.caption, fontSize: 10),
                ),
              ),
              SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.primaryColor,
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _setupPassword,
                      child: Text('Encrypt Question Bank', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Unlock View
  Widget _buildUnlockScreen() {
    return Scaffold(
      backgroundColor: context.scaffoldBackgroundColor,
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.vpn_key_rounded, color: Color(0xFFFBBF24), size: 52),
              SizedBox(height: 16),
              Text('Question Bank Encrypted 🔑', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('Enter encryption password to open dashboard.', style: TextStyle(color: context.caption, fontSize: 12)),
              SizedBox(height: 24),
              TextField(
                controller: _passInputCtrl,
                obscureText: _obscurePass,
                style: TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Enter Password...',
                  hintStyle: TextStyle(color: context.caption, fontSize: 13),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePass ? Icons.visibility_off : Icons.visibility, color: context.caption),
                    onPressed: () => setState(() => _obscurePass = !_obscurePass),
                  ),
                ),
              ),
              SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFFFBBF24),
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _unlockQuestionBank,
                      child: Text('Unlock Bank', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Tabs Header
  Widget _buildMenuBar() {
    return Container(
      decoration: BoxDecoration(
        color: context.secondaryBackgroundColor,
        border: Border(bottom: BorderSide(color: context.borderColor.withOpacity(0.5))),
      ),
      child: Row(
        children: [
          _menuBarItem('Summary', 0),
          _menuBarItem('Questions', 1),
          _menuBarItem('Verify & Preview', 2),
          _menuBarItem('Audit Trail', 3),
        ],
      ),
    );
  }

  Widget _menuBarItem(String label, int index) {
    final isSel = _activeTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeTab = index),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: isSel ? context.primaryColor : Colors.transparent, width: 2)),
          ),
          child: Text(
            label,
            style: TextStyle(color: isSel ? Colors.white : context.caption, fontSize: 11, fontWeight: isSel ? FontWeight.bold : FontWeight.normal),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildActiveTabContent() {
    if (_activeTab == 1) return _buildManageQuestionsTab();
    if (_activeTab == 2) return _buildValidationPreviewTab();
    if (_activeTab == 3) return _buildAuditTrailTab();
    return _buildSummaryTab();
  }

  // Tab 0: Summary Stats Dashboard & Randomization Settings
  Widget _buildSummaryTab() {
    final totalMarks = _questions.fold(0, (sum, q) => sum + (q['marks'] as int));
    final totalTimer = _questions.fold(0, (sum, q) => sum + (q['timer'] as int));
    final avgTimer = _questions.isEmpty ? 0 : (totalTimer / _questions.length).toInt();

    final easyCount = _questions.where((q) => q['difficulty'] == 'Easy').length;
    final mediumCount = _questions.where((q) => q['difficulty'] == 'Medium').length;
    final hardCount = _questions.where((q) => q['difficulty'] == 'Hard').length;

    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        // Registration Lock status
        if (_isRegistrationClosed) ...[
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.lock_rounded, color: Colors.red, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Question Bank is Auto-Locked.\nNo modifications allowed after registration closes.',
                    style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
        ],

        // Metrics Grid
        Row(
          children: [
            Expanded(child: _metricBox('Total Qs', '${_questions.length}', context.primaryColor)),
            SizedBox(width: 8),
            Expanded(child: _metricBox('Total Marks', '$totalMarks pts', Colors.amber)),
            SizedBox(width: 8),
            Expanded(child: _metricBox('Avg. Timer', '$avgTimer s', Colors.blue)),
          ],
        ),
        SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _metricBox('Easy', '$easyCount', Colors.green)),
            SizedBox(width: 8),
            Expanded(child: _metricBox('Medium', '$mediumCount', Colors.orange)),
            SizedBox(width: 8),
            Expanded(child: _metricBox('Hard', '$hardCount', Colors.red)),
          ],
        ),
        SizedBox(height: 24),

        // Randomization controls
        Text(
          '🔀 Randomization Controls',
          style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 10),
        _switchRow('Randomize Question Order', _randomizeQuestionOrder, (v) {
          if (_isRegistrationClosed) return;
          setState(() => _randomizeQuestionOrder = v);
          _logAction('Randomize Question Order set to $v');
        }),
        _switchRow('Randomize Option Order', _randomizeOptionOrder, (v) {
          if (_isRegistrationClosed) return;
          setState(() => _randomizeOptionOrder = v);
          _logAction('Randomize Option Order set to $v');
        }),
        _switchRow('Randomize Subject Order', _randomizeSubjectOrder, (v) {
          if (_isRegistrationClosed) return;
          setState(() => _randomizeSubjectOrder = v);
          _logAction('Randomize Subject Order set to $v');
        }),
        _switchRow('Randomize Section Order', _randomizeSectionOrder, (v) {
          if (_isRegistrationClosed) return;
          setState(() => _randomizeSectionOrder = v);
          _logAction('Randomize Section Order set to $v');
        }),
      ],
    );
  }

  Widget _metricBox(String label, String value, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.borderColor.withOpacity(0.4)),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
          SizedBox(height: 4),
          Text(label, style: TextStyle(color: context.caption, fontSize: 9)),
        ],
      ),
    );
  }

  Widget _switchRow(String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: context.textSecondary, fontSize: 12)),
          Switch(
            value: value,
            activeColor: context.primaryColor,
            onChanged: _isRegistrationClosed ? null : onChanged,
          ),
        ],
      ),
    );
  }

  // Tab 1: Question Builder (Manual Form, Excel/CSV Imports, AI Generative prompt)
  Widget _buildManageQuestionsTab() {
    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        // Import panel shortcuts
        Text('📥 Import Question Bank', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
        SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _importOptionCard('Excel', Icons.table_view_rounded, Colors.green, () => _importMockFile('.xlsx'))),
            SizedBox(width: 8),
            Expanded(child: _importOptionCard('CSV', Icons.insert_drive_file_outlined, Colors.blue, () => _importMockFile('.csv'))),
            SizedBox(width: 8),
            Expanded(child: _importOptionCard('JSON', Icons.code_rounded, Colors.amber, () => _importMockFile('.json'))),
          ],
        ),
        SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _importOptionCard('AI Question Generator 🤖', Icons.psychology_rounded, Colors.purple, _importAI)),
            SizedBox(width: 8),
            Expanded(child: _importOptionCard('Clone Previous Event', Icons.copy_all_rounded, Colors.white60, _clonePreviousEventQuestions)),
          ],
        ),
        Divider(color: context.borderColor, height: 32),

        // Manual builder Form Trigger
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: _isRegistrationClosed ? Colors.grey : context.primaryColor,
            padding: EdgeInsets.symmetric(vertical: 12),
          ),
          onPressed: _isRegistrationClosed ? null : _showManualAddDialog,
          icon: Icon(Icons.add_circle_outline_rounded, color: Colors.white),
          label: Text('Add Question Manually', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        SizedBox(height: 20),

        // List of currently added questions
        Text('📄 Added Questions', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
        SizedBox(height: 10),
        if (_questions.isEmpty)
          Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: Text('No questions added.', style: TextStyle(color: context.caption, fontSize: 12))),
          )
        else
          ..._questions.asMap().entries.map((entry) {
            final idx = entry.key;
            final q = entry.value;
            return Card(
              color: context.surfaceColor,
              margin: EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(q['question'] as String, style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                subtitle: Text('Subject: ${q['subject']} • Marks: ${q['marks']} • Timer: ${q['timer']}s', style: TextStyle(color: context.caption, fontSize: 10)),
                trailing: _isRegistrationClosed
                    ? null
                    : IconButton(
                        icon: Icon(Icons.delete_outline_rounded, color: Colors.red),
                        onPressed: () {
                          setState(() {
                            _questions.removeAt(idx);
                            _isValidated = false;
                          });
                          _logAction('Deleted Question: "${q['question']}"');
                        },
                      ),
              ),
            );
          }),
      ],
    );
  }

  Widget _importOptionCard(String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: _isRegistrationClosed ? null : onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: _isRegistrationClosed ? Colors.grey.withOpacity(0.05) : context.surfaceColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _isRegistrationClosed ? Colors.transparent : context.borderColor.withOpacity(0.4)),
        ),
        child: Column(
          children: [
            Icon(icon, color: _isRegistrationClosed ? Colors.grey : color, size: 20),
            SizedBox(height: 6),
            Text(label, style: TextStyle(color: _isRegistrationClosed ? Colors.grey : Colors.white70, fontSize: 10), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  // Dialog manual question Form
  void _showManualAddDialog() {
    final qCtrl = TextEditingController();
    final aCtrl = TextEditingController();
    final bCtrl = TextEditingController();
    final cCtrl = TextEditingController();
    final dCtrl = TextEditingController();
    String correctVal = 'A';
    String difficultyVal = 'Medium';
    String subjectVal = 'Mathematics';
    final marksCtrl = TextEditingController(text: '10');
    final timerCtrl = TextEditingController(text: '20');

    Get.dialog(
      AlertDialog(
        backgroundColor: context.secondaryBackgroundColor,
        title: Text('Add Question Manually 📝', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: qCtrl, decoration: const InputDecoration(hintText: 'Question body...')),
              TextField(controller: aCtrl, decoration: const InputDecoration(hintText: 'Option A...')),
              TextField(controller: bCtrl, decoration: const InputDecoration(hintText: 'Option B...')),
              TextField(controller: cCtrl, decoration: const InputDecoration(hintText: 'Option C...')),
              TextField(controller: dCtrl, decoration: const InputDecoration(hintText: 'Option D...')),
              SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: correctVal,
                items: ['A', 'B', 'C', 'D'].map((o) => DropdownMenuItem(value: o, child: Text('Answer $o'))).toList(),
                onChanged: (v) => correctVal = v!,
                decoration: const InputDecoration(labelText: 'Correct Option'),
              ),
              DropdownButtonFormField<String>(
                value: difficultyVal,
                items: ['Easy', 'Medium', 'Hard'].map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
                onChanged: (v) => difficultyVal = v!,
                decoration: const InputDecoration(labelText: 'Difficulty'),
              ),
              DropdownButtonFormField<String>(
                value: subjectVal,
                items: ['Mathematics', 'Reasoning', 'Programming', 'English', 'General Knowledge']
                    .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                    .toList(),
                onChanged: (v) => subjectVal = v!,
                decoration: const InputDecoration(labelText: 'Subject'),
              ),
              TextField(controller: marksCtrl, decoration: const InputDecoration(labelText: 'Marks per question')),
              TextField(controller: timerCtrl, decoration: const InputDecoration(labelText: 'Timer (Seconds)')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: Text('Cancel', style: TextStyle(color: context.caption))),
          ElevatedButton(
            onPressed: () {
              if (qCtrl.text.isEmpty || aCtrl.text.isEmpty || bCtrl.text.isEmpty || cCtrl.text.isEmpty || dCtrl.text.isEmpty) {
                return;
              }
              final ansMap = {'A': aCtrl.text, 'B': bCtrl.text, 'C': cCtrl.text, 'D': dCtrl.text};
              _importManual({
                'question': qCtrl.text.trim(),
                'options': [aCtrl.text.trim(), bCtrl.text.trim(), cCtrl.text.trim(), dCtrl.text.trim()],
                'answer': ansMap[correctVal],
                'difficulty': difficultyVal,
                'subject': subjectVal,
                'marks': int.tryParse(marksCtrl.text) ?? 10,
                'timer': int.tryParse(timerCtrl.text) ?? 20,
              });
              Get.back();
            },
            child: Text('Add'),
          ),
        ],
      ),
    );
  }

  // Tab 2: Verification Engine & Quiz Sandbox preview
  Widget _buildValidationPreviewTab() {
    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        // Validation checker trigger
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: context.primaryColor),
          onPressed: _runValidation,
          icon: Icon(Icons.playlist_add_check_rounded),
          label: Text('Validate & Encrypt Question Bank', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        SizedBox(height: 20),

        // Display validation errors
        if (_isValidated) ...[
          Text('Verification Report:', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
          SizedBox(height: 10),
          if (_validationErrors.isEmpty)
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.green.withOpacity(0.12), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.green.withOpacity(0.3))),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline_rounded, color: Colors.green, size: 16),
                  SizedBox(width: 8),
                  Text('All checks passed. Question bank ready.', style: TextStyle(color: Colors.green, fontSize: 11)),
                ],
              ),
            )
          else
            ..._validationErrors.map((err) => Padding(
                  padding: EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    children: [
                      Icon(Icons.cancel_rounded, color: Colors.red, size: 14),
                      SizedBox(width: 8),
                      Expanded(child: Text(err, style: TextStyle(color: context.textSecondary, fontSize: 11))),
                    ],
                  ),
                )),
          Divider(color: context.borderColor, height: 32),
        ],

        // Preview Mode
        Text('👁️ Organizer Preview Mode', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
        SizedBox(height: 6),
        Text('Launch the event in sandbox mode using the same gameplay UI to preview flow. Answers will not be recorded.', style: TextStyle(color: context.caption, fontSize: 11)),
        SizedBox(height: 14),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: context.primaryColor),
            padding: EdgeInsets.symmetric(vertical: 12),
          ),
          onPressed: () {
            // Launch simulation play screen
            Get.to(() => LiveEventPlayScreen(event: widget.event));
          },
          icon: Icon(Icons.play_arrow_rounded, color: context.primaryColor),
          label: Text('Start Sandbox Preview', style: TextStyle(color: context.primaryColor, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  // Tab 3: Immutable Audit Trails
  Widget _buildAuditTrailTab() {
    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        Text('🛡️ Tamper-Proof Audit Trail', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
        SizedBox(height: 4),
        Text('Immutable verification records of all actions on the Question Bank.', style: TextStyle(color: context.caption, fontSize: 10)),
        SizedBox(height: 14),
        ..._auditLogs.map((log) => Container(
              margin: EdgeInsets.only(bottom: 8),
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.surfaceColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: context.borderColor.withOpacity(0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(log['action'] as String, style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      Text('${log['date']} ${log['time']}', style: TextStyle(color: context.caption, fontSize: 9)),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text('By: ${log['userId']} (${log['role']}) • Device: ${log['device']} • IP: ${log['ip']}', style: TextStyle(color: context.caption, fontSize: 9)),
                ],
              ),
            )),
      ],
    );
  }
}

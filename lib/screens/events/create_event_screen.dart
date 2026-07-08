import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme.dart';
import '../../models/event_model.dart';
import '../../services/event_controller.dart';

class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({Key? key}) : super(key: key);

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _rulesController = TextEditingController();
  final _termsController = TextEditingController();
  final _passwordController = TextEditingController();
  final _customDurationController = TextEditingController();
  final _customWinnerController = TextEditingController();
  final _customCategoryController = TextEditingController();

  final EventController _eventController = Get.find<EventController>();

  // ── Presets ────────────────────────────────────────────────────────────────
  final List<String> _presetBanners = [
    'https://images.unsplash.com/photo-1542751371-adc38448a05e', // Gaming/BGMI
    'https://images.unsplash.com/photo-1517694712202-14dd9538aa97', // Coding
    'https://images.unsplash.com/photo-1434030216411-0b793f4b4173', // Study
    'https://images.unsplash.com/photo-1516321318423-f06f85e504b3', // Quiz/General
    'https://images.unsplash.com/photo-1486312338219-ce68d2c6f44d', // Hackathon
  ];
  int _currentBannerIndex = 0;

  final List<String> _categories = [
    'Computer Science',
    'Engineering',
    'Government Exams',
    'JEE/NEET Prep',
    'BGMI Tournament',
    'Aptitude & Quiz',
    'Other (Custom)'
  ];
  String _selectedCategory = 'Computer Science';

  // ── Basic variables ────────────────────────────────────────────────────────
  String _selectedDifficulty = 'Medium';
  String _selectedFormat = 'Quiz';
  bool _isPaid = false;
  int _entryFeeAmount = 0;

  // ── Participants bounds ────────────────────────────────────────────────────
  int _minSeats = 10;
  int _maxSeats = 100;
  int _minUsers = 10;
  int _maxUsers = 100;

  // ── Scheduling ─────────────────────────────────────────────────────────────
  DateTime _registrationStartDate = DateTime.now();
  DateTime _registrationEndDate = DateTime.now().add(const Duration(days: 2));
  DateTime _eventStartDate = DateTime.now().add(const Duration(days: 3));
  TimeOfDay _eventStartTime = const TimeOfDay(hour: 18, minute: 0); // 6:00 PM

  String _durationString = '1 hour'; // 15 min, 30 min, 1 hour, 2 hours, 3 hours, Custom

  // ── Security & Winners ─────────────────────────────────────────────────────
  String _winnerType = 'top3'; // top3, top5, top10, custom
  bool _isPublic = true;
  bool _passwordProtected = false;
  bool _allowAdminsJoin = false;

  // ── Anti-Cheat & Proctoring ────────────────────────────────────────────────
  bool _screenMonitoring = false;
  bool _negativeMarking = false;

  // ── New Features ───────────────────────────────────────────────────────────
  bool _allowSpectators = true;
  bool _allowLateJoin = false;
  bool _autoCancelMinUsers = true;
  bool _autoRefund = true;
  bool _chatEnabled = true;
  bool _voiceRoomEnabled = false;
  bool _screenShareEnabled = false;
  bool _recordingEnabled = false;
  bool _autoPrizeCalculation = true;
  bool _isMultiRound = false;
  List<RoundConfig> _configuredRounds = [];
  String? _customGalleryBannerPath;
  String _numRoundsSelection = '1 Round';

  // ── Custom Registration Form Requirements ──────────────────────────────────
  bool _reqName = true;
  bool _reqPhone = true;
  bool _reqEmail = true;
  bool _reqUpi = false;
  bool _reqPhoto = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _rulesController.dispose();
    _termsController.dispose();
    _passwordController.dispose();
    _customDurationController.dispose();
    _customWinnerController.dispose();
    _customCategoryController.dispose();
    super.dispose();
  }

  // ── DateTime Pickers ───────────────────────────────────────────────────────
  Future<void> _selectDate(BuildContext context, DateTime initialDate, Function(DateTime) onPicked) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.primaryColor,
              onPrimary: Colors.white,
              surface: AppTheme.bgLight,
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: AppTheme.bgDark,
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => onPicked(picked));
    }
  }

  Future<void> _selectTime(BuildContext context, TimeOfDay initialTime, Function(TimeOfDay) onPicked) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.primaryColor,
              onPrimary: Colors.white,
              surface: AppTheme.bgLight,
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: AppTheme.bgDark,
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => onPicked(picked));
    }
  }

  // ── Calculation Properties ─────────────────────────────────────────────────
  DateTime get computedEventStart {
    return DateTime(
      _eventStartDate.year,
      _eventStartDate.month,
      _eventStartDate.day,
      _eventStartTime.hour,
      _eventStartTime.minute,
    );
  }

  DateTime get computedEventEnd {
    int mins = 60;
    if (_durationString == '15 min') mins = 15;
    else if (_durationString == '30 min') mins = 30;
    else if (_durationString == '1 hour') mins = 60;
    else if (_durationString == '2 hours') mins = 120;
    else if (_durationString == '3 hours') mins = 180;
    else {
      mins = int.tryParse(_customDurationController.text) ?? 60;
    }
    return computedEventStart.add(Duration(minutes: mins));
  }

  // ── Submit Logic ───────────────────────────────────────────────────────────
  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    // Date validations
    if (_registrationEndDate.isBefore(_registrationStartDate)) {
      Get.snackbar('Invalid Timeline ⏰', 'Registration end date must be after registration start date.',
          snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red.withOpacity(0.9), colorText: Colors.white);
      return;
    }
    if (computedEventStart.isBefore(_registrationEndDate)) {
      Get.snackbar('Timeline Conflict ⏰', 'Event must start after the registration ends.',
          snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red.withOpacity(0.9), colorText: Colors.white);
      return;
    }

    final creationCost = 59;
    if (_eventController.silverCoins.value < creationCost) {
      Get.snackbar(
        'Insufficient Coins 🪙',
        'You need $creationCost Silver Coins to create this event. Current balance: ${_eventController.silverCoins.value}.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withOpacity(0.9),
        colorText: Colors.white,
      );
      return;
    }

    // Build fields list
    final List<String> fields = [];
    if (_reqName) fields.add('name');
    if (_reqPhone) fields.add('phone');
    if (_reqEmail) fields.add('email');
    if (_reqUpi) fields.add('upi_id');
    if (_reqPhoto) fields.add('photo');

    final terms = _termsController.text.isNotEmpty
        ? _termsController.text.trim()
        : 'I agree to participate with honesty and adhere to the proctoring rules of this competition.';

    final double minCol = _minSeats * _entryFeeAmount.toDouble();
    final double maxCol = _maxSeats * _entryFeeAmount.toDouble();
    final double minPrize = minCol * 0.58;
    final double maxPrize = maxCol * 0.58;

    final String finalCategory = _selectedCategory == 'Other (Custom)'
        ? _customCategoryController.text.trim()
        : _selectedCategory;

    final String finalWinnerType = _winnerType == 'custom'
        ? 'top${_customWinnerController.text}'
        : _winnerType;

    Get.dialog(
      AlertDialog(
        backgroundColor: AppTheme.bgLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.assignment_turned_in_rounded, color: AppTheme.primaryColor, size: 24),
            SizedBox(width: 10),
            Text(
              'Publish Event Preview',
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Verify event details before deducting creation coins and publishing.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
              ),
              const SizedBox(height: 12),
              if (_isPaid) ...[
                Text(
                  '🏆 Prize Pool: ₹${minPrize.toInt()} - ₹${maxPrize.toInt()}',
                  style: const TextStyle(color: Color(0xFFFBBF24), fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text('Winner Split: ${finalWinnerType.toUpperCase()}', style: const TextStyle(color: Colors.white, fontSize: 11)),
                const SizedBox(height: 12),
              ],
              const Divider(color: AppTheme.borderColor),
              const SizedBox(height: 8),
               Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Host Fee', style: TextStyle(color: AppTheme.textTertiary, fontSize: 12)),
                  const Text('🪙 59', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Creation Cost', style: TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
                  Text(
                    '🪙 $creationCost',
                    style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 15, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Edit Form', style: TextStyle(color: AppTheme.textTertiary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final EventFormat fmt;
              switch (_selectedFormat) {
                case 'Quiz': fmt = EventFormat.quiz; break;
                case 'Coding Contest': fmt = EventFormat.codingContest; break;
                case 'Debate': fmt = EventFormat.debate; break;
                case 'Hackathon': fmt = EventFormat.hackathon; break;
                default: fmt = EventFormat.liveTest; break;
              }

              final newEvent = Event(
                id: 'event_${DateTime.now().millisecondsSinceEpoch}',
                title: _nameController.text.trim(),
                description: _descController.text.trim(),
                bannerUrl: _customGalleryBannerPath ?? _presetBanners[_currentBannerIndex],
                category: finalCategory,
                difficulty: _selectedDifficulty,
                organizer: 'My Custom Community',
                isOfficial: false,
                startDate: computedEventStart,
                endDate: computedEventEnd,
                registrationDeadline: _registrationEndDate,
                resultDate: computedEventEnd.add(const Duration(hours: 1)),
                maxParticipants: _maxSeats,
                isUnlimited: false,
                entryFeeType: _isPaid ? EntryFeeType.cash : EntryFeeType.free,
                entryFeeAmount: _isPaid ? _entryFeeAmount : 0,
                prizePool: _isPaid ? '₹${minPrize.toInt()} - ₹${maxPrize.toInt()}' : '🏆 Certification',
                rewards: EventReward(coins: _isPaid ? 500 : 100, xp: 200, certificate: true),
                status: EventStatus.registrationOpen,
                format: fmt,
                rules: _rulesController.text.isNotEmpty ? _rulesController.text.split(',') : ['Follow fair play rules.'],
                requiredRegistrationFields: fields,
                termsAndConditions: terms,
                isPaid: _isPaid,
                minParticipants: _minSeats,
                winnerType: finalWinnerType,
                autoPrizePool: _autoPrizeCalculation,
                passwordProtected: _passwordProtected,
                password: _passwordController.text,
                allowAdminsJoin: _allowAdminsJoin,
                creatorId: EventController.currentUserId,
                adminIds: [],
                durationString: _durationString,
                allowSpectators: _allowSpectators,
                allowLateJoin: _allowLateJoin,
                autoCancelMinUsers: _autoCancelMinUsers,
                autoRefund: _autoRefund,
                chatEnabled: _chatEnabled,
                voiceRoomEnabled: _voiceRoomEnabled,
                screenShareEnabled: _screenShareEnabled,
                recordingEnabled: _recordingEnabled,
                timelineStatus: 'Registration Started',
                winners: [],
                isMultiRound: _isMultiRound,
                rounds: _isMultiRound ? _configuredRounds : [],
              );

              Get.back(); // close dialog
              final bool success = _eventController.createPaidEvent(newEvent);
              if (success) {
                Get.back(); // back to events list
                Get.snackbar(
                  '🎉 Event Published Successfully!',
                  'Deducted 🪙 $creationCost coins from your account.',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: AppTheme.accentColor.withOpacity(0.9),
                  colorText: Colors.white,
                );
              }
            },
            child: const Text('Publish Event', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        backgroundColor: AppTheme.bgDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        title: const Text(
          'Host New Event',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Banner selector preset card ────────────────────────────────
            _buildBannerSelector(),
            const SizedBox(height: 16),

            // ── Section 1: Basic Information ──────────────────────────────
            _buildInputSection(
              title: '📝 Basic Information',
              children: [
                _buildTextField('Event Name', _nameController, 'Enter event title', (v) => v!.isEmpty ? 'Name required' : null),
                const SizedBox(height: 12),
                _buildTextField('Description', _descController, 'Explain target audience, syllabus details...', null, maxLines: 3),
                const SizedBox(height: 12),
                _buildDropdown('Category', _selectedCategory, _categories, (val) => setState(() => _selectedCategory = val!)),
                if (_selectedCategory == 'Other (Custom)') ...[
                  const SizedBox(height: 10),
                  _buildTextField('Custom Category Name', _customCategoryController, 'Enter category name', (v) => v!.isEmpty ? 'Category required' : null),
                ],
              ],
            ),
            const SizedBox(height: 16),

            // ── Section 2: Formatting & Type ──────────────────────────────
            _buildInputSection(
              title: '🎨 Format & Difficulty',
              children: [
                _buildDropdown('Format Type', _selectedFormat, ['Quiz', 'Coding Contest', 'Debate', 'Hackathon', 'Live Test'], (val) => setState(() => _selectedFormat = val!)),
                const SizedBox(height: 12),
                _buildDropdown('Difficulty', _selectedDifficulty, ['Easy', 'Medium', 'Hard'], (val) => setState(() => _selectedDifficulty = val!)),
                const SizedBox(height: 12),
                _buildTextField('Rules & Syllabus (comma separated)', _rulesController, 'e.g. Plagiarism check active, time limit 20 mins', null),
                const SizedBox(height: 12),
                _buildToggleRow('Is Multi-Round Event', _isMultiRound, (v) {
                  setState(() {
                    _isMultiRound = v;
                    if (v && _configuredRounds.isEmpty) {
                      // Seed a default round 1
                      _configuredRounds.add(const RoundConfig(
                        name: 'Qualifying Round',
                        description: 'Initial screening round.',
                        format: 'MCQ Quiz',
                        totalQuestions: 10,
                        marksPerQuestion: 10,
                        negativeMarking: false,
                        timerPerQuestion: 20,
                        qualifyingCriteria: 'Top 50%',
                        breakTimeMinutes: 15,
                        autoStartNextRound: true,
                      ));
                    }
                  });
                }),
                if (_isMultiRound) ...[
                  const SizedBox(height: 10),
                  _buildMultiRoundWidget(),
                ],
              ],
            ),
            const SizedBox(height: 16),

            // ── Section 3: Registration & Scheduling ───────────────────────
            _buildInputSection(
              title: '⏰ Scheduling & Duration',
              children: [
                // Registration start picker
                _buildDateTimePickerRow(
                  label: 'Registration Start',
                  dateTime: _registrationStartDate,
                  onDateTap: () => _selectDate(context, _registrationStartDate, (d) => _registrationStartDate = d),
                  onTimeTap: () => _selectTime(context, TimeOfDay.fromDateTime(_registrationStartDate), (t) {
                    _registrationStartDate = DateTime(_registrationStartDate.year, _registrationStartDate.month, _registrationStartDate.day, t.hour, t.minute);
                  }),
                ),
                const SizedBox(height: 12),
                // Registration end picker
                _buildDateTimePickerRow(
                  label: 'Registration End',
                  dateTime: _registrationEndDate,
                  onDateTap: () => _selectDate(context, _registrationEndDate, (d) => _registrationEndDate = d),
                  onTimeTap: () => _selectTime(context, TimeOfDay.fromDateTime(_registrationEndDate), (t) {
                    _registrationEndDate = DateTime(_registrationEndDate.year, _registrationEndDate.month, _registrationEndDate.day, t.hour, t.minute);
                  }),
                ),
                const Divider(color: AppTheme.borderColor, height: 24),
                // Event Start Date/Time
                _buildDateTimePickerRow(
                  label: 'Event Start Time',
                  dateTime: DateTime(_eventStartDate.year, _eventStartDate.month, _eventStartDate.day, _eventStartTime.hour, _eventStartTime.minute),
                  onDateTap: () => _selectDate(context, _eventStartDate, (d) => _eventStartDate = d),
                  onTimeTap: () => _selectTime(context, _eventStartTime, (t) => _eventStartTime = t),
                ),
                const SizedBox(height: 12),
                // Duration configuration
                _buildDropdown('Event Duration', _durationString, ['15 min', '30 min', '1 hour', '2 hours', '3 hours', 'Custom Duration'], (val) => setState(() => _durationString = val!)),
                if (_durationString == 'Custom Duration') ...[
                  const SizedBox(height: 10),
                  _buildNumberField('Custom Duration (Minutes)', (v) => setState(() {}), '60', controller: _customDurationController),
                ],
              ],
            ),
            const SizedBox(height: 16),

            // ── Section 4: Pricing & Dynamic Prize Pool ───────────────────
            _buildInputSection(
              title: '🪙 Entry Fee & Prize Pool',
              children: [
                _buildToggleRow('Is Paid Event (Host Cost: 50 Silver Coins)', _isPaid, (v) {
                  setState(() {
                    _isPaid = v;
                  });
                }),
                if (_isPaid) ...[
                  const SizedBox(height: 12),
                  _buildNumberField('Entry Fee Amount (₹)', (v) => setState(() => _entryFeeAmount = int.tryParse(v) ?? 0), '100'),
                  const SizedBox(height: 12),
                  _buildDropdown('Winner Type', _winnerType == 'top3' ? 'Top 3' : _winnerType == 'top5' ? 'Top 5' : _winnerType == 'top10' ? 'Top 10' : 'Custom Winner Count', ['Top 3', 'Top 5', 'Top 10', 'Custom Winner Count'], (val) {
                    setState(() {
                      _winnerType = val == 'Top 3' ? 'top3' : val == 'Top 5' ? 'top5' : val == 'Top 10' ? 'top10' : 'custom';
                    });
                  }),
                  if (_winnerType == 'custom') ...[
                    const SizedBox(height: 10),
                    _buildNumberField('Custom Winner Count', (v) => setState(() {}), '15', controller: _customWinnerController),
                  ],
                  const SizedBox(height: 12),
                  _buildToggleRow('Auto Prize Pool Calculation', _autoPrizeCalculation, (v) => setState(() => _autoPrizeCalculation = v)),
                  const SizedBox(height: 12),
                  _buildToggleRow('Allow Admins & Co-owners to Join', _allowAdminsJoin, (v) => setState(() => _allowAdminsJoin = v)),
                  const SizedBox(height: 12),
                  // Minimum & Maximum users/participants
                  Row(
                    children: [
                      Expanded(
                        child: _buildNumberField('Min Participants', (v) => setState(() => _minSeats = int.tryParse(v) ?? 10), '10'),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildNumberField('Max Participants', (v) => setState(() => _maxSeats = int.tryParse(v) ?? 100), '100'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildNumberField('Min Users limit', (v) => setState(() => _minUsers = int.tryParse(v) ?? 10), '10'),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildNumberField('Max Users limit', (v) => setState(() => _maxUsers = int.tryParse(v) ?? 100), '100'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Payout structure card preview
                  if (_autoPrizeCalculation) _buildPrizeBreakdownCard(),
                ],
              ],
            ),
            const SizedBox(height: 16),

            // ── Section 5: Access & Privacy ───────────────────────────────
            _buildInputSection(
              title: '🔒 Access & Privacy Settings',
              children: [
                _buildToggleRow('Public Event (Visible to all)', _isPublic, (v) => setState(() => _isPublic = v)),
                const SizedBox(height: 10),
                _buildToggleRow('Password Protected Event', _passwordProtected, (v) => setState(() => _passwordProtected = v)),
                if (_passwordProtected) ...[
                  const SizedBox(height: 10),
                  _buildTextField('Event Access Password', _passwordController, 'Enter secure password', (v) => v!.isEmpty ? 'Password required' : null),
                ],
              ],
            ),
            const SizedBox(height: 16),

            // ── Section 6: Video/Audio Rooms & Chat permissions ────────────
            _buildInputSection(
              title: '🎙️ Communications & Media',
              children: [
                _buildToggleRow('Chat Room Enabled', _chatEnabled, (v) => setState(() => _chatEnabled = v)),
                const SizedBox(height: 10),
                _buildToggleRow('Voice Room Room Enabled', _voiceRoomEnabled, (v) => setState(() => _voiceRoomEnabled = v)),
                const SizedBox(height: 10),
                _buildToggleRow('Allow Screen Sharing', _screenShareEnabled, (v) => setState(() => _screenShareEnabled = v)),
                const SizedBox(height: 10),
                _buildToggleRow('Allow Recording Session', _recordingEnabled, (v) => setState(() => _recordingEnabled = v)),
                const SizedBox(height: 10),
                _buildToggleRow('Allow Spectators (Non-participants)', _allowSpectators, (v) => setState(() => _allowSpectators = v)),
                const SizedBox(height: 10),
                _buildToggleRow('Allow Late Join (Join after start)', _allowLateJoin, (v) => setState(() => _allowLateJoin = v)),
              ],
            ),
            const SizedBox(height: 16),

            // ── Section 7: Proctoring & Rules ──────────────────────────────
            _buildInputSection(
              title: '🛡️ Proctoring & Rules config',
              children: [
                _buildToggleRow('AI Screen Proctoring (Tab Switch Monitor)', _screenMonitoring, (v) => setState(() => _screenMonitoring = v)),
                const SizedBox(height: 10),
                _buildToggleRow('Negative Marking (-0.25 on MCQ error)', _negativeMarking, (v) => setState(() => _negativeMarking = v)),
                const SizedBox(height: 10),
                _buildToggleRow('Auto Cancel if Min Seats Not Reached', _autoCancelMinUsers, (v) => setState(() => _autoCancelMinUsers = v)),
                const SizedBox(height: 10),
                _buildToggleRow('Auto Refund Entry Fees on Cancel', _autoRefund, (v) => setState(() => _autoRefund = v)),
              ],
            ),
            const SizedBox(height: 16),

            // ── Section 8: Registration Form Creator ───────────────────────
            _buildInputSection(
              title: '📋 Registrant Form Customization',
              children: [
                const Text(
                  'Select details that participants must provide when registering for your event:',
                  style: TextStyle(color: AppTheme.textTertiary, fontSize: 11),
                ),
                const SizedBox(height: 12),
                _buildToggleRow('Require Full Name', _reqName, (v) => setState(() => _reqName = v)),
                const SizedBox(height: 8),
                _buildToggleRow('Require Phone Number', _reqPhone, (v) => setState(() => _reqPhone = v)),
                const SizedBox(height: 8),
                _buildToggleRow('Require Email Address', _reqEmail, (v) => setState(() => _reqEmail = v)),
                const SizedBox(height: 8),
                _buildToggleRow('Require UPI ID (For payouts)', _reqUpi, (v) => setState(() => _reqUpi = v)),
                const SizedBox(height: 8),
                _buildToggleRow('Require Profile Photo / ID Proof', _reqPhoto, (v) => setState(() => _reqPhoto = v)),
                const SizedBox(height: 12),
                _buildTextField('Custom Event Terms & Conditions (Optional)', _termsController, 'e.g. Host holds rights to disqualify suspicious activities...', null, maxLines: 2),
              ],
            ),
            const SizedBox(height: 32),

            // Submit Button
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _submit,
                icon: const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 20),
                label: const Text(
                  'Publish & Create Event',
                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  // ── HELPER WIDGETS ─────────────────────────────────────────────────────────

  Widget _buildBannerSelector() {
    final imageProvider = _customGalleryBannerPath != null
        ? FileImage(File(_customGalleryBannerPath!)) as ImageProvider
        : NetworkImage(_presetBanners[_currentBannerIndex]) as ImageProvider;

    return Container(
      height: 140,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        image: DecorationImage(
          image: imageProvider,
          fit: BoxFit.cover,
        ),
      ),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                colors: [Colors.black.withOpacity(0.6), Colors.transparent],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              ),
            ),
          ),
          Positioned(
            right: 12,
            bottom: 12,
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      color: Colors.black26,
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        ),
                        onPressed: () {
                          setState(() {
                            _customGalleryBannerPath = null;
                            _currentBannerIndex = (_currentBannerIndex + 1) % _presetBanners.length;
                          });
                        },
                        icon: const Icon(Icons.style_rounded, color: AppTheme.accentColor, size: 14),
                        label: const Text(
                          'Preset Banner',
                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      color: Colors.black26,
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        ),
                        onPressed: () async {
                          final ImagePicker picker = ImagePicker();
                          final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                          if (image != null) {
                            setState(() {
                              _customGalleryBannerPath = image.path;
                            });
                          }
                        },
                        icon: const Icon(Icons.photo_library_rounded, color: AppTheme.primaryColor, size: 14),
                        label: const Text(
                          'Gallery Upload',
                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateTimePickerRow({
    required String label,
    required DateTime dateTime,
    required VoidCallback onDateTap,
    required VoidCallback onTimeTap,
  }) {
    final dateStr = '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    final timeStr = '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: onDateTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  decoration: BoxDecoration(
                    color: AppTheme.bgDark,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded, color: AppTheme.textTertiary, size: 14),
                      const SizedBox(width: 8),
                      Text(dateStr, style: const TextStyle(color: Colors.white, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: onTimeTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  decoration: BoxDecoration(
                    color: AppTheme.bgDark,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time_rounded, color: AppTheme.textTertiary, size: 14),
                      const SizedBox(width: 8),
                      Text(timeStr, style: const TextStyle(color: Colors.white, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPrizeBreakdownCard() {
    final double poolMin = _minSeats * _entryFeeAmount * 0.58;
    final double poolMax = _maxSeats * _entryFeeAmount * 0.58;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.bgDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.analytics_outlined, color: AppTheme.accentColor, size: 16),
              SizedBox(width: 6),
              Text(
                'Auto Prize Calculation Preview',
                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildPreviewRow('Estimated Prize Pool (58%)', '₹${poolMin.toInt()} - ₹${poolMax.toInt()}', isGolden: true),
          _buildPreviewRow('Platform Fee (17%)', '₹${(_minSeats * _entryFeeAmount * 0.17).toInt()} - ₹${(_maxSeats * _entryFeeAmount * 0.17).toInt()}'),
          _buildPreviewRow('Creator Reward (10%)', '₹${(_minSeats * _entryFeeAmount * 0.10).toInt()} - ₹${(_maxSeats * _entryFeeAmount * 0.10).toInt()}'),
          _buildPreviewRow('Co-Owner Reward (5%)', '₹${(_minSeats * _entryFeeAmount * 0.05).toInt()} - ₹${(_maxSeats * _entryFeeAmount * 0.05).toInt()}'),
          _buildPreviewRow('Admin Pool (10%)', '₹${(_minSeats * _entryFeeAmount * 0.10).toInt()} - ₹${(_maxSeats * _entryFeeAmount * 0.10).toInt()}'),
          const Divider(color: AppTheme.borderColor),
          const SizedBox(height: 4),
          const Text(
            'Estimated Winner Payouts:',
            style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          _buildWinnerEstimates(),
        ],
      ),
    );
  }

  Widget _buildInputSection({required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: AppTheme.primaryColor, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, String hint, String? Function(String?)? validator, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          validator: validator,
          maxLines: maxLines,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppTheme.textTertiary, fontSize: 12),
            filled: true,
            fillColor: AppTheme.bgDark,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ],
    );
  }

  Widget _buildNumberField(String label, void Function(String) onChanged, String hint, {TextEditingController? controller}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          onChanged: onChanged,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppTheme.textTertiary, fontSize: 12),
            filled: true,
            fillColor: AppTheme.bgDark,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, void Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppTheme.bgDark,
            borderRadius: BorderRadius.circular(10),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              items: items
                  .map((e) => DropdownMenuItem(
                      value: e,
                      child: Text(e, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13))))
                  .toList(),
              onChanged: onChanged,
              dropdownColor: AppTheme.bgDark,
              isExpanded: true,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToggleRow(String label, bool value, void Function(bool) onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
          ),
        ),
        Switch(
          value: value,
          activeColor: AppTheme.primaryColor,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildPreviewRow(String label, String value, {bool isGolden = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: isGolden ? Colors.white : AppTheme.textTertiary, fontSize: 11, fontWeight: isGolden ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(color: isGolden ? const Color(0xFFFBBF24) : Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildMultiRoundWidget() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(color: AppTheme.borderColor),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '🏁 Round Configurations',
              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
            ),
            if (_configuredRounds.length < 5)
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _configuredRounds.add(RoundConfig(
                      name: 'Round ${_configuredRounds.length + 1}',
                      description: 'Elimination round to filter top participants.',
                      format: 'MCQ Quiz',
                      totalQuestions: 10,
                      marksPerQuestion: 10,
                      negativeMarking: false,
                      timerPerQuestion: 20,
                      qualifyingCriteria: 'Top 50%',
                      breakTimeMinutes: 15,
                      autoStartNextRound: true,
                    ));
                  });
                },
                icon: const Icon(Icons.add_rounded, size: 16, color: AppTheme.primaryColor),
                label: const Text('Add Round', style: TextStyle(color: AppTheme.primaryColor, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (_configuredRounds.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('No rounds configured. At least 1 round is required.', style: TextStyle(color: AppTheme.errorColor, fontSize: 11)),
          )
        else
          ..._configuredRounds.asMap().entries.map((entry) {
            final idx = entry.key;
            final round = entry.value;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.bgDark,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Round ${idx + 1}: ${round.name}',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                        onPressed: () {
                          setState(() {
                            _configuredRounds.removeAt(idx);
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Round Type Selector
                  _buildDropdown('Round Type', round.format, ['MCQ Quiz', 'Coding Challenge', 'Aptitude Test', 'Reasoning Test', 'Mixed Questions'], (v) {
                    setState(() {
                      _configuredRounds[idx] = RoundConfig(
                        name: round.name,
                        description: round.description,
                        format: v!,
                        totalQuestions: round.totalQuestions,
                        marksPerQuestion: round.marksPerQuestion,
                        negativeMarking: round.negativeMarking,
                        timerPerQuestion: round.timerPerQuestion,
                        qualifyingCriteria: round.qualifyingCriteria,
                        breakTimeMinutes: round.breakTimeMinutes,
                        autoStartNextRound: round.autoStartNextRound,
                      );
                    });
                  }),
                  const SizedBox(height: 8),
                  // Total Questions & Timer Row
                  Row(
                    children: [
                      Expanded(
                        child: _buildNumberField('Questions', (v) {
                          setState(() {
                            _configuredRounds[idx] = RoundConfig(
                              name: round.name,
                              description: round.description,
                              format: round.format,
                              totalQuestions: int.tryParse(v) ?? 10,
                              marksPerQuestion: round.marksPerQuestion,
                              negativeMarking: round.negativeMarking,
                              timerPerQuestion: round.timerPerQuestion,
                              qualifyingCriteria: round.qualifyingCriteria,
                              breakTimeMinutes: round.breakTimeMinutes,
                              autoStartNextRound: round.autoStartNextRound,
                            );
                          });
                        }, '${round.totalQuestions}'),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildNumberField('Timer (s)', (v) {
                          setState(() {
                            _configuredRounds[idx] = RoundConfig(
                              name: round.name,
                              description: round.description,
                              format: round.format,
                              totalQuestions: round.totalQuestions,
                              marksPerQuestion: round.marksPerQuestion,
                              negativeMarking: round.negativeMarking,
                              timerPerQuestion: int.tryParse(v) ?? 20,
                              qualifyingCriteria: round.qualifyingCriteria,
                              breakTimeMinutes: round.breakTimeMinutes,
                              autoStartNextRound: round.autoStartNextRound,
                            );
                          });
                        }, '${round.timerPerQuestion}'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Qualification criteria selector & Break Time
                  Row(
                    children: [
                      Expanded(
                        child: _buildDropdown('Qualifying Rules', round.qualifyingCriteria, ['Top 10', 'Top 20', 'Top 50%', 'Top 25%', 'Min Score'], (v) {
                          setState(() {
                            _configuredRounds[idx] = RoundConfig(
                              name: round.name,
                              description: round.description,
                              format: round.format,
                              totalQuestions: round.totalQuestions,
                              marksPerQuestion: round.marksPerQuestion,
                              negativeMarking: round.negativeMarking,
                              timerPerQuestion: round.timerPerQuestion,
                              qualifyingCriteria: v!,
                              breakTimeMinutes: round.breakTimeMinutes,
                              autoStartNextRound: round.autoStartNextRound,
                            );
                          });
                        }),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildNumberField('Break (Mins)', (v) {
                          setState(() {
                            _configuredRounds[idx] = RoundConfig(
                              name: round.name,
                              description: round.description,
                              format: round.format,
                              totalQuestions: round.totalQuestions,
                              marksPerQuestion: round.marksPerQuestion,
                              negativeMarking: round.negativeMarking,
                              timerPerQuestion: round.timerPerQuestion,
                              qualifyingCriteria: round.qualifyingCriteria,
                              breakTimeMinutes: int.tryParse(v) ?? 15,
                              autoStartNextRound: round.autoStartNextRound,
                            );
                          });
                        }, '${round.breakTimeMinutes}'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Round Start Date & Time
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          round.startDate == null
                              ? '📅 Schedule Start: Click to select'
                              : '📅 Schedule: ${round.startDate!.toString().substring(0, 16)}',
                          style: const TextStyle(color: Colors.white70, fontSize: 10),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(40, 20)),
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now().add(const Duration(days: 1)),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 30)),
                          );
                          if (date != null) {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.now(),
                            );
                            if (time != null) {
                              final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                              setState(() {
                                _configuredRounds[idx] = RoundConfig(
                                  name: round.name,
                                  description: round.description,
                                  format: round.format,
                                  totalQuestions: round.totalQuestions,
                                  marksPerQuestion: round.marksPerQuestion,
                                  negativeMarking: round.negativeMarking,
                                  timerPerQuestion: round.timerPerQuestion,
                                  qualifyingCriteria: round.qualifyingCriteria,
                                  breakTimeMinutes: round.breakTimeMinutes,
                                  autoStartNextRound: round.autoStartNextRound,
                                  startDate: dt,
                                  isBuzzerMode: round.isBuzzerMode,
                                );
                              });
                            }
                          }
                        },
                        child: const Text('Pick', style: TextStyle(color: AppTheme.primaryColor, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // KBC Buzzer Mode Switch
                  _buildToggleRow('KBC Buzzer Mode (Fastest finger)', round.isBuzzerMode, (v) {
                    setState(() {
                      _configuredRounds[idx] = RoundConfig(
                        name: round.name,
                        description: round.description,
                        format: round.format,
                        totalQuestions: round.totalQuestions,
                        marksPerQuestion: round.marksPerQuestion,
                        negativeMarking: round.negativeMarking,
                        timerPerQuestion: round.timerPerQuestion,
                        qualifyingCriteria: round.qualifyingCriteria,
                        breakTimeMinutes: round.breakTimeMinutes,
                        autoStartNextRound: round.autoStartNextRound,
                        startDate: round.startDate,
                        isBuzzerMode: v,
                      );
                    });
                  }),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildWinnerEstimates() {
    final double poolMin = _minSeats * _entryFeeAmount * 0.58;
    final double poolMax = _maxSeats * _entryFeeAmount * 0.58;

    final List<double> percentages;
    final List<String> positions;
    
    final int customWinnerCount = int.tryParse(_customWinnerController.text) ?? 5;

    if (_winnerType == 'top5') {
      percentages = [0.40, 0.25, 0.15, 0.12, 0.08];
      positions = ['🥇 1st Place', '🥈 2nd Place', '🥉 3rd Place', '🏅 4th Place', '🏅 5th Place'];
    } else if (_winnerType == 'top10') {
      percentages = [0.30, 0.18, 0.12, 0.10, 0.08, 0.07, 0.06, 0.04, 0.03, 0.02];
      positions = ['🥇 1st', '🥈 2nd', '🥉 3rd', '4th', '5th', '6th', '7th', '8th', '9th', '10th'];
    } else if (_winnerType == 'custom' && customWinnerCount > 0) {
      percentages = List.generate(customWinnerCount, (i) => 1.0 / customWinnerCount);
      positions = List.generate(customWinnerCount, (i) => '${i + 1}th Place');
    } else {
      percentages = [0.50, 0.30, 0.20];
      positions = ['🥇 1st Place', '🥈 2nd Place', '🥉 3rd Place'];
    }

    return Column(
      children: List.generate(percentages.length, (i) {
        final pct = percentages[i];
        final minVal = poolMin * pct;
        final maxVal = poolMax * pct;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(positions[i], style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
              Text('₹${minVal.toInt()} - ₹${maxVal.toInt()}', style: const TextStyle(color: Colors.white70, fontSize: 10)),
            ],
          ),
        );
      }),
    );
  }
}

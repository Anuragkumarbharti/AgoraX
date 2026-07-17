import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io' as io;
import 'package:image_picker/image_picker.dart';
import 'package:creania/core/theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import '../../widgets/custom_image_editor.dart';
import '../../services/room_controller.dart';
import '../../services/user_profile_cache_manager.dart';
import 'voice_room_call_screen.dart';

class CreateRoomScreen extends StatefulWidget {
  const CreateRoomScreen({Key? key}) : super(key: key);

  @override
  State<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  final _formKey = GlobalKey<FormState>();
  final RoomController _controller = RoomController.to;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _rulesController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  String _selectedCategory = 'Social Arena';
  String _selectedCountry = 'India';
  String _selectedLanguage = 'English';
  String _selectedPermission = 'everyone';
  String _creationType = 'level'; // 'level', 'coins', 'ticket'
  final RxInt _ticketCount = 0.obs;
  String? _selectedCoverPhoto = 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=150'; // Default preset
  io.File? _customCoverFile;

  bool _isCheckingUsername = false;
  bool? _isUsernameUnique;
  List<String> _usernameSuggestions = [];
  Timer? _usernameDebounce;

  void _onUsernameChanged(String val) {
    if (_usernameDebounce?.isActive ?? false) _usernameDebounce!.cancel();
    final cleanVal = val.trim().toLowerCase().replaceAll('@', '');
    if (cleanVal.isEmpty) {
      setState(() {
        _isUsernameUnique = null;
        _isCheckingUsername = false;
        _usernameSuggestions.clear();
      });
      return;
    }

    setState(() {
      _isCheckingUsername = true;
      _isUsernameUnique = null;
    });

    _usernameDebounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        final res = await Supabase.instance.client
            .from('rooms')
            .select('id')
            .eq('username', '@$cleanVal')
            .maybeSingle();
        setState(() {
          _isUsernameUnique = res == null;
          _isCheckingUsername = false;
          if (!_isUsernameUnique!) {
            _usernameSuggestions = [
              '${cleanVal}_arena',
              '${cleanVal}_live',
              '${cleanVal}123',
              '${cleanVal}_room'
            ];
          } else {
            _usernameSuggestions.clear();
          }
        });
      } catch (e) {
        setState(() {
          _isUsernameUnique = null;
          _isCheckingUsername = false;
          _usernameSuggestions.clear();
        });
      }
    });
  }

  // 10 Creania Arena Types
  final List<String> _categories = [
    'Social Arena',
    'Debate Arena',
    'Study Arena',
    'Coaching Arena',
    'Family Arena',
    'Music Arena',
    'Gaming Arena',
    'Community Arena',
    'Private Arena',
    'Event Arena'
  ];

  // 19 standard tags
  final List<String> _predefinedTags = [
    'Education', 'Technology', 'Gaming', 'Debate', 'Music', 
    'Singing', 'Poetry', 'Business', 'Startup', 'Sports', 
    'Fitness', 'Movie', 'Anime', 'Food', 'Travel', 
    'Family', 'Comedy', 'Friendship', 'Spiritual'
  ];

  final List<String> _selectedTags = [];

  final List<String> _countries = ['India', 'USA', 'UK', 'Canada', 'Australia', 'Global'];
  final List<String> _languages = ['English', 'Hindi', 'Bengali', 'Spanish', 'French', 'Arabic'];
  final List<String> _permissions = ['everyone', 'followers_only', 'paid_members', 'vip_only', 'password_required'];

  @override
  void initState() {
    super.initState();
    // Default tag for Social Room
    _selectedTags.add('Friendship');
    _loadTicketCount();
  }

  Future<void> _loadTicketCount() async {
    try {
      final res = await Supabase.instance.client
          .from('arena_tickets')
          .select('id')
          .eq('user_id', UserProfileCacheManager.currentUserId)
          .eq('is_consumed', false);
      if (res != null && res is List) {
        _ticketCount.value = res.length;
      }
    } catch (_) {}

    final user = UserProfileCacheManager.currentUser;
    final userLevel = user?.level ?? 1;
    final userCoins = _controller.walletBalance.value;

    if (userLevel >= 15) {
      setState(() => _creationType = 'level');
    } else if (userCoins >= 499) {
      setState(() => _creationType = 'coins');
    } else if (_ticketCount.value >= 1) {
      setState(() => _creationType = 'ticket');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _descriptionController.dispose();
    _rulesController.dispose();
    _passwordController.dispose();
    _usernameDebounce?.cancel();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    final user = UserProfileCacheManager.currentUser;
    final userLevel = user?.level ?? 1;
    final userCoins = _controller.walletBalance.value;

    if (_creationType == 'level' && userLevel < 15) {
      Get.snackbar(
        'Requirement Unmet',
        'You must be at least ID Level 15 to create an Arena via Level. Your current level is $userLevel.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
      return;
    }

    if (_creationType == 'coins' && userCoins < 499) {
      Get.snackbar(
        'Insufficient Balance',
        'You need 499 Gold Coins to create an Arena. Your balance: $userCoins Coins.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
      return;
    }

    if (_creationType == 'ticket' && _ticketCount.value < 1) {
      Get.snackbar(
        'No Creation Ticket',
        'You do not have any Arena Creation Ticket in your inventory.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
      return;
    }

    final name = _nameController.text.trim();
    var rawUsername = _usernameController.text.trim().toLowerCase().replaceAll('@', '');
    if (rawUsername.isEmpty) {
      Get.snackbar(
        'Validation Error',
        'Please enter an Arena Username',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
      return;
    }

    if (_isCheckingUsername) {
      Get.snackbar(
        'Validation Error',
        'Still checking Username availability. Please wait.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
      return;
    }

    if (_isUsernameUnique == false) {
      Get.snackbar(
        'Validation Error',
        'Arena Username is already taken.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
      return;
    }

    final username = '@$rawUsername';
    final description = _descriptionController.text.trim();
    
    // Parse rules (new line separated or fallback)
    final rules = _rulesController.text
        .split('\n')
        .map((r) => r.trim())
        .where((r) => r.isNotEmpty)
        .toList();

    // If private or password required, validate password
    if (_selectedCategory == 'Private Arena' || _selectedPermission == 'password_required') {
      if (_passwordController.text.trim().isEmpty) {
        Get.snackbar(
          'Password Required',
          'Please specify an arena access password.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.redAccent,
          colorText: Colors.white,
        );
        return;
      }
    }

    // Show loading spinner if custom cover needs uploading
    if (_customCoverFile != null) {
      Get.dialog(
        Center(child: CircularProgressIndicator(color: context.primaryColor)),
        barrierDismissible: false,
      );
    }

    String? newRoomId = await _controller.createArenaRoom(
      name: name,
      username: username,
      description: description,
      category: _selectedCategory,
      country: _selectedCountry,
      language: _selectedLanguage,
      tags: _selectedTags,
      rules: rules.isEmpty ? ['Be respectful to others.'] : rules,
      entryPermission: _selectedCategory == 'Private Arena' ? 'password' : _selectedPermission,
      avatar: _selectedCoverPhoto,
      banner: _selectedCoverPhoto,
      creationMethod: _creationType,
    );

    if (newRoomId != null) {
      if (_customCoverFile != null) {
        await _controller.uploadRoomBanner(newRoomId, _customCoverFile!);
        Get.back(); // close loading spinner
      }
      Get.back(); // Pop create screen
      
      final currentUid = UserProfileCacheManager.currentUserId;
      final currentUsername = UserProfileCacheManager.currentUser?.username ?? 'Creania Student';

      // Auto-join the newly created room as host
      Get.to(
        () => VoiceRoomCallScreen(
          roomId: newRoomId!,
          roomName: name,
          userId: currentUid,
          userName: currentUsername,
          isHost: true,
        ),
      );
    } else {
      if (_customCoverFile != null) {
        Get.back(); // close loading spinner if creation failed
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = UserProfileCacheManager.currentUser;
    final userLevel = user?.level ?? 1;

    return Scaffold(
      backgroundColor: context.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: context.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'Create Arena',
          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: context.secondaryBackgroundColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.borderColor),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.monetization_on, color: Colors.amber, size: 16),
                    SizedBox(width: 4),
                    Obx(() => Text(
                          '${_controller.walletBalance.value}',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white),
                        )),
                  ],
                ),
              ),
            ),
          )
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status Info Row
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.secondaryBackgroundColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: context.borderColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _statusItem('Your Level', 'Lv.$userLevel', userLevel >= 15 ? Colors.green : Colors.grey),
                      _verticalDivider(),
                      Obx(() => _statusItem('Coins', '${_controller.walletBalance.value}', _controller.walletBalance.value >= 499 ? Colors.green : Colors.grey)),
                      _verticalDivider(),
                      Obx(() => _statusItem('Tickets', '${_ticketCount.value}', _ticketCount.value >= 1 ? Colors.green : Colors.grey)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Name
                Text('Arena Name', style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  maxLength: 50,
                  style: TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'e.g., Chill Debate Lounge, Code & Coffee',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                    filled: true,
                    fillColor: context.secondaryBackgroundColor,
                    counterText: '',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().length < 3) {
                      return 'Arena name must be at least 3 characters';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),

                // Username
                Text('Arena Username', style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                SizedBox(height: 8),
                TextFormField(
                  controller: _usernameController,
                  style: TextStyle(color: Colors.white),
                  onChanged: _onUsernameChanged,
                  inputFormatters: [
                    TextInputFormatter.withFunction((oldValue, newValue) {
                      if (newValue.text.startsWith('@')) {
                        return TextEditingValue(
                          text: newValue.text.substring(1),
                          selection: TextSelection.collapsed(offset: newValue.selection.end - 1),
                        );
                      }
                      return newValue;
                    }),
                  ],
                  decoration: InputDecoration(
                    prefixText: '@',
                    prefixStyle: TextStyle(color: Colors.white, fontSize: 16),
                    hintText: 'studyhub',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                    filled: true,
                    fillColor: context.secondaryBackgroundColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    suffixIcon: _isCheckingUsername
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: Padding(
                              padding: EdgeInsets.all(12.0),
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blue),
                            ),
                          )
                        : (_isUsernameUnique != null
                            ? Icon(
                                _isUsernameUnique! ? Icons.check_circle_rounded : Icons.cancel_rounded,
                                color: _isUsernameUnique! ? Colors.green : Colors.red,
                              )
                            : null),
                    helperText: _isUsernameUnique == null
                        ? null
                        : (_isUsernameUnique! ? 'Username is available!' : 'Username is already taken!'),
                    helperStyle: TextStyle(
                      color: _isUsernameUnique == null
                          ? Colors.white60
                          : (_isUsernameUnique! ? Colors.green : Colors.red),
                      fontSize: 11,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Username is required';
                    }
                    var trim = value.trim().toLowerCase();
                    if (trim.startsWith('@')) {
                      trim = trim.substring(1);
                    }
                    if (trim.length < 3 || trim.length > 30) {
                      return 'Username must be between 3 and 30 characters';
                    }
                    final regex = RegExp(r'^[a-z0-9_]+$');
                    if (!regex.hasMatch(trim)) {
                      return 'Only letters, numbers, and underscores allowed';
                    }
                    return null;
                  },
                ),
                if (_usernameSuggestions.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Suggestions:', style: TextStyle(color: context.textSecondary, fontSize: 12)),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 38,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _usernameSuggestions.length,
                      itemBuilder: (context, idx) {
                        final suggestion = _usernameSuggestions[idx];
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ActionChip(
                            backgroundColor: context.secondaryBackgroundColor,
                            side: BorderSide(color: context.borderColor),
                            label: Text('@$suggestion', style: TextStyle(color: context.primaryColor, fontSize: 12, fontWeight: FontWeight.bold)),
                            onPressed: () {
                              _usernameController.text = suggestion;
                              _onUsernameChanged(suggestion);
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
                SizedBox(height: 16),

                // Description
                Text('Description', style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                SizedBox(height: 8),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 2,
                  style: TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'What is this arena about? Write a catchy summary...',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                    filled: true,
                    fillColor: context.secondaryBackgroundColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a description';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),

                // Cover Photo Selector
                Text('Arena Cover Photo', style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                SizedBox(height: 8),
                _buildCoverPhotoSelector(),
                SizedBox(height: 16),

                // Category & Permission (Two Column Dropdowns)
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Category Arena', style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                          SizedBox(height: 8),
                          _buildDropdown(_categories, _selectedCategory, (val) {
                            setState(() {
                              _selectedCategory = val!;
                              // Auto add related tag if possible
                              final baseTag = _selectedCategory.split(' ')[0];
                              if (_predefinedTags.contains(baseTag) && !_selectedTags.contains(baseTag)) {
                                _selectedTags.add(baseTag);
                              }
                            });
                          }),
                        ],
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Entry Permission', style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                          SizedBox(height: 8),
                          _buildDropdown(
                            _permissions.map((p) => p.replaceAll('_', ' ').capitalizeFirst!).toList(), 
                            _selectedPermission.replaceAll('_', ' ').capitalizeFirst!, 
                            (val) {
                              setState(() => _selectedPermission = val!.toLowerCase().replaceAll(' ', '_'));
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),

                // Conditional Password Field
                if (_selectedCategory == 'Private Room' || _selectedPermission == 'password_required') ...[
                  Text('Access Password', style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                  SizedBox(height: 8),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Enter access password for private room',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                      filled: true,
                      fillColor: context.secondaryBackgroundColor,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                  SizedBox(height: 16),
                ],

                // Country & Language Dropdowns
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Country', style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                          SizedBox(height: 8),
                          _buildDropdown(_countries, _selectedCountry, (val) {
                            setState(() => _selectedCountry = val!);
                          }),
                        ],
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Language', style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                          SizedBox(height: 8),
                          _buildDropdown(_languages, _selectedLanguage, (val) {
                            setState(() => _selectedLanguage = val!);
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),

                // Premium Predefined Tags Selector
                Text('Select Arena Tags', style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.secondaryBackgroundColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _predefinedTags.map((tag) {
                      final isSelected = _selectedTags.contains(tag);
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedTags.remove(tag);
                            } else {
                              if (_selectedTags.length < 5) {
                                _selectedTags.add(tag);
                              } else {
                                Get.snackbar(
                                  'Max Tags',
                                  'You can select up to 5 tags for your arena.',
                                  snackPosition: SnackPosition.BOTTOM,
                                  backgroundColor: context.warningColor.withOpacity(0.8),
                                  colorText: Colors.white,
                                );
                              }
                            }
                          });
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected ? context.primaryColor : Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected ? context.primaryColor : Colors.white.withOpacity(0.1),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            tag,
                            style: GoogleFonts.poppins(
                              color: isSelected ? Colors.white : Colors.white.withOpacity(0.7),
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                SizedBox(height: 16),

                // Rules
                Text('Arena Rules (one rule per line)', style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                SizedBox(height: 8),
                TextFormField(
                  controller: _rulesController,
                  maxLines: 3,
                  style: TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "1. Be respectful\n2. Wait for turn\n3. Share constructive feedback",
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                    filled: true,
                    fillColor: context.secondaryBackgroundColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
                SizedBox(height: 32),

                // Select Creation Type
                Text(
                  'Choose Creation Method',
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                
                // Level creation card
                _buildTypeCard(
                  type: 'level',
                  title: 'Free via ID Level 15+',
                  description: 'Create Arena for free because your ID Level is 15 or above.',
                  icon: Icons.military_tech_rounded,
                  color: Colors.cyan,
                  disabled: userLevel < 15,
                ),
                const SizedBox(height: 12),

                // Coin creation card
                Obx(() => _buildTypeCard(
                  type: 'coins',
                  title: 'Use 499 Gold Coins',
                  description: 'Create using 499 Gold Coins from your wallet balance.',
                  icon: Icons.monetization_on_rounded,
                  color: Colors.amber,
                  disabled: _controller.walletBalance.value < 499,
                )),
                const SizedBox(height: 12),

                // Ticket creation card
                Obx(() => _buildTypeCard(
                  type: 'ticket',
                  title: 'Use Arena Ticket (${_ticketCount.value} Available)',
                  description: 'Deduct 1 Arena Creation Ticket from your inventory.',
                  icon: Icons.local_activity_rounded,
                  color: Colors.green,
                  disabled: _ticketCount.value < 1,
                )),
                const SizedBox(height: 40),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _submitForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 4,
                    ),
                    child: Text(
                      _creationType == 'level'
                          ? 'Free Create (Level 15+)'
                          : (_creationType == 'coins' ? 'Pay 499 Coins & Create' : 'Use Ticket & Create'),
                      style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusItem(String title, String value, Color color) {
    return Column(
      children: [
        Text(title, style: TextStyle(color: context.caption, fontSize: 11)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _verticalDivider() {
    return Container(width: 1, height: 24, color: context.borderColor.withOpacity(0.3));
  }

  Widget _buildTypeCard({
    required String type,
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    bool disabled = false,
  }) {
    final isSelected = _creationType == type;
    return GestureDetector(
      onTap: disabled ? null : () => setState(() => _creationType = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? context.secondaryBackgroundColor : context.secondaryBackgroundColor.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? context.primaryColor : context.borderColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Opacity(
          opacity: disabled ? 0.4 : 1.0,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: isSelected ? Colors.white : context.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: TextStyle(
                        color: context.caption,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown(List<String> items, String selectedValue, void Function(String?) onChanged) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: context.secondaryBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.borderColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedValue,
          dropdownColor: context.secondaryBackgroundColor,
          icon: Icon(Icons.arrow_drop_down, color: context.caption),
          isExpanded: true,
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 13),
          onChanged: onChanged,
          items: items.map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildCoverPhotoSelector() {
    final presets = [
      'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=150', // Classic Mic
      'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=150', // DJ Mixer
      'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=150', // Concert
      'https://images.unsplash.com/photo-1506157786151-b8491531f063?w=150', // Neon
      'https://images.unsplash.com/photo-1516280440614-37939bbacd6a?w=150', // Acoustic
      'https://images.unsplash.com/photo-1459749411175-04bf5292ceea?w=150', // Stage Lights
    ];

    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.secondaryBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24),
                  image: _customCoverFile != null
                      ? DecorationImage(image: FileImage(_customCoverFile!), fit: BoxFit.cover)
                      : (_selectedCoverPhoto != null
                          ? DecorationImage(image: NetworkImage(_selectedCoverPhoto!), fit: BoxFit.cover)
                          : null),
                ),
                child: (_selectedCoverPhoto == null && _customCoverFile == null)
                    ? Center(child: Icon(Icons.image_outlined, color: Colors.white30))
                    : null,
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _customCoverFile != null ? 'Custom Cover Selected' : 'Preset Cover Selected',
                      style: GoogleFonts.poppins(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    ElevatedButton.icon(
                      onPressed: _pickCustomCover,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white10,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      icon: Icon(Icons.cloud_upload_outlined, size: 16),
                      label: Text('Upload Custom', style: GoogleFonts.poppins(fontSize: 11)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Divider(color: Colors.white10),
          SizedBox(height: 8),
          Text('Select from presets:', style: GoogleFonts.poppins(color: Colors.white60, fontSize: 11)),
          SizedBox(height: 8),
          SizedBox(
            height: 60,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: presets.length,
              itemBuilder: (context, idx) {
                final isSelected = _customCoverFile == null && _selectedCoverPhoto == presets[idx];
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedCoverPhoto = presets[idx];
                      _customCoverFile = null;
                    });
                  },
                  child: Container(
                    margin: EdgeInsets.only(right: 8),
                    width: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? context.primaryColor : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(presets[idx], fit: BoxFit.cover),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickCustomCover() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final editedFile = await CustomImageEditor.editImage(context, io.File(pickedFile.path));
      if (editedFile != null) {
        setState(() {
          _customCoverFile = io.File(editedFile.path);
          _selectedCoverPhoto = null;
        });
      }
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io' as io;
import 'package:image_picker/image_picker.dart';
import '../../core/theme.dart';
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
  bool _isPermanent = false;
  String? _selectedCoverPhoto = 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=150'; // Default preset
  io.File? _customCoverFile;

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
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _descriptionController.dispose();
    _rulesController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    var username = _usernameController.text.trim().toLowerCase();
    if (!username.startsWith('@')) {
      username = '@$username';
    }
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
        const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
        barrierDismissible: false,
      );
    }

    String? newRoomId;

    if (_isPermanent) {
      newRoomId = await _controller.createPermanentRoom(
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
      );
    } else {
      newRoomId = await _controller.createTemporaryRoom(
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
      );
    }

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
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        backgroundColor: AppTheme.bgDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'Create Arena',
          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.bgLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.monetization_on, color: Colors.amber, size: 16),
                    const SizedBox(width: 4),
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
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Arena Type Selector Card
                _buildRoomTypeSelector(),
                const SizedBox(height: 24),

                // Name
                Text('Arena Name', style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  maxLength: 50,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'e.g., Chill Debate Lounge, Code & Coffee',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                    filled: true,
                    fillColor: AppTheme.bgLight,
                    counterText: '',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().length < 3) {
                      return 'Arena name must be at least 3 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Username
                Text('Arena Username', style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _usernameController,
                  style: const TextStyle(color: Colors.white),
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
                    prefixStyle: const TextStyle(color: Colors.white, fontSize: 16),
                    hintText: 'studyhub',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                    filled: true,
                    fillColor: AppTheme.bgLight,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                const SizedBox(height: 16),

                // Description
                Text('Description', style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 2,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'What is this arena about? Write a catchy summary...',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                    filled: true,
                    fillColor: AppTheme.bgLight,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a description';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Cover Photo Selector
                Text('Arena Cover Photo', style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                _buildCoverPhotoSelector(),
                const SizedBox(height: 16),

                // Category & Permission (Two Column Dropdowns)
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Category Arena', style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
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
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Entry Permission', style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
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
                const SizedBox(height: 16),

                // Conditional Password Field
                if (_selectedCategory == 'Private Room' || _selectedPermission == 'password_required') ...[
                  Text('Access Password', style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Enter access password for private room',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                      filled: true,
                      fillColor: AppTheme.bgLight,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Country & Language Dropdowns
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Country', style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          _buildDropdown(_countries, _selectedCountry, (val) {
                            setState(() => _selectedCountry = val!);
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Language', style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          _buildDropdown(_languages, _selectedLanguage, (val) {
                            setState(() => _selectedLanguage = val!);
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Premium Predefined Tags Selector
                Text('Select Arena Tags', style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.bgLight,
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
                                  backgroundColor: AppTheme.warningColor.withOpacity(0.8),
                                  colorText: Colors.white,
                                );
                              }
                            }
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected ? AppTheme.primaryColor : Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected ? AppTheme.primaryColor : Colors.white.withOpacity(0.1),
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
                const SizedBox(height: 16),

                // Rules
                Text('Arena Rules (one rule per line)', style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _rulesController,
                  maxLines: 3,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "1. Be respectful\n2. Wait for turn\n3. Share constructive feedback",
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                    filled: true,
                    fillColor: AppTheme.bgLight,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
                const SizedBox(height: 32),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isPermanent ? Colors.amber : AppTheme.primaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 4,
                    ),
                    child: Text(
                      _isPermanent ? 'Unlock Permanent Arena (599 Coins)' : 'Launch Free Temporary Arena',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: _isPermanent ? Colors.black87 : Colors.white,
                      ),
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

  Widget _buildRoomTypeSelector() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choose Arena Session Duration',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Temporary Room Option
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _isPermanent = false),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: !_isPermanent ? AppTheme.bgLight : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: !_isPermanent ? AppTheme.primaryColor : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          color: !_isPermanent ? AppTheme.primaryColor : AppTheme.textTertiary,
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Temporary',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: !_isPermanent ? Colors.white : AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Free • Auto-deletes when empty',
                          style: GoogleFonts.poppins(fontSize: 9, color: AppTheme.textTertiary),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Permanent Room Option
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _isPermanent = true),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _isPermanent ? Colors.amber.withOpacity(0.05) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _isPermanent ? Colors.amber : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.workspace_premium_outlined,
                          color: _isPermanent ? Colors.amber : AppTheme.textTertiary,
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Permanent',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: _isPermanent ? Colors.amber : AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '599 Coins • Never expires • XP enabled',
                          style: GoogleFonts.poppins(
                            fontSize: 9,
                            color: _isPermanent ? Colors.amber.withOpacity(0.8) : AppTheme.textTertiary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildDropdown(List<String> items, String selectedValue, void Function(String?) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.bgLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedValue,
          dropdownColor: AppTheme.bgLight,
          icon: const Icon(Icons.arrow_drop_down, color: AppTheme.textTertiary),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.bgLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
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
                    ? const Center(child: Icon(Icons.image_outlined, color: Colors.white30))
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _customCoverFile != null ? 'Custom Cover Selected' : 'Preset Cover Selected',
                      style: GoogleFonts.poppins(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    ElevatedButton.icon(
                      onPressed: _pickCustomCover,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white10,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      icon: const Icon(Icons.cloud_upload_outlined, size: 16),
                      label: Text('Upload Custom', style: GoogleFonts.poppins(fontSize: 11)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white10),
          const SizedBox(height: 8),
          Text('Select from presets:', style: GoogleFonts.poppins(color: Colors.white60, fontSize: 11)),
          const SizedBox(height: 8),
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
                    margin: const EdgeInsets.only(right: 8),
                    width: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? AppTheme.primaryColor : Colors.transparent,
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
      setState(() {
        _customCoverFile = io.File(pickedFile.path);
        _selectedCoverPhoto = null;
      });
    }
  }
}

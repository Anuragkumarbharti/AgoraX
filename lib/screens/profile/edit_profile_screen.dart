import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import '../../core/theme.dart';
import '../../models/user_model.dart';
import '../../services/user_profile_cache_manager.dart';
import '../../services/user_progress_sync_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({Key? key}) : super(key: key);

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late User _user;
  bool _isLoading = false;

  // Controllers
  final _displayNameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _languageCtrl = TextEditingController();
  final _occupationCtrl = TextEditingController();
  final _schoolCtrl = TextEditingController();
  final _collegeCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _instagramCtrl = TextEditingController();
  final _youtubeCtrl = TextEditingController();
  final _twitterCtrl = TextEditingController();

  DateTime? _dob;
  int _age = 0;
  String? _selectedGender;
  final Set<String> _selectedInterests = {};
  File? _avatarFile;
  File? _coverFile;

  // Username validation
  bool _usernameChecked = true;
  bool _usernameAvailable = true;
  String? _usernameError;
  List<String> _suggestions = [];

  final List<String> _allInterests = [
    'Knowledge', 'Technology', 'Programming', 'AI', 'Cybersecurity',
    'Business', 'Education', 'Gaming', 'Music', 'Movies', 'Sports',
    'Anime', 'Photography', 'Travel', 'Fashion', 'Science', 'Finance',
    'Startups', 'Books', 'Comedy', 'Art', 'Voice Rooms', 'Communities', 'Events'
  ];

  @override
  void initState() {
    super.initState();
    final cached = UserProfileCacheManager.currentUser;
    if (cached != null) {
      _user = cached;
      _initializeFields();
    } else {
      _fetchUser();
    }
  }

  void _fetchUser() async {
    setState(() => _isLoading = true);
    final user = await UserProfileCacheManager.fetchUserProfile('me');
    setState(() {
      _user = user;
      _initializeFields();
      _isLoading = false;
    });
  }

  void _initializeFields() {
    _displayNameCtrl.text = _user.displayName;
    _usernameCtrl.text = _user.username;
    _bioCtrl.text = _user.bio ?? '';
    _countryCtrl.text = _user.country ?? '';
    _stateCtrl.text = _user.state ?? '';
    _cityCtrl.text = _user.city ?? '';
    _languageCtrl.text = _user.language;
    _occupationCtrl.text = _user.profession ?? '';
    
    // Split education or map it to fields
    _schoolCtrl.text = '';
    _collegeCtrl.text = _user.education ?? '';
    _companyCtrl.text = '';

    _websiteCtrl.text = _user.website ?? '';
    _instagramCtrl.text = _user.instagram ?? '';
    _youtubeCtrl.text = _user.youtube ?? '';
    _twitterCtrl.text = _user.twitter ?? '';
    _dob = _user.dob;
    _age = _user.age;
    _selectedGender = _user.gender;
    _selectedInterests.clear();
    _selectedInterests.addAll(_user.interests);
  }

  @override
  void dispose() {
    _displayNameCtrl.dispose();
    _usernameCtrl.dispose();
    _bioCtrl.dispose();
    _countryCtrl.dispose();
    _stateCtrl.dispose();
    _cityCtrl.dispose();
    _languageCtrl.dispose();
    _occupationCtrl.dispose();
    _schoolCtrl.dispose();
    _collegeCtrl.dispose();
    _companyCtrl.dispose();
    _websiteCtrl.dispose();
    _instagramCtrl.dispose();
    _youtubeCtrl.dispose();
    _twitterCtrl.dispose();
    super.dispose();
  }

  int _calculateCompletion() {
    int percentage = 20; // 20% -> Account Created

    // 40% -> Username + Display Name
    final hasUsername = _usernameCtrl.text.trim().isNotEmpty && !_usernameCtrl.text.trim().startsWith('user_');
    final hasDisplayName = _displayNameCtrl.text.trim().isNotEmpty && _displayNameCtrl.text.trim() != 'Creania Student';
    if (hasUsername && hasDisplayName) {
      percentage += 20;
    }

    // 60% -> Profile Photo + Bio
    final hasAvatar = _avatarFile != null || (_user.avatar != null && _user.avatar!.isNotEmpty);
    final hasBio = _bioCtrl.text.trim().isNotEmpty;
    if (hasAvatar && hasBio) {
      percentage += 20;
    }

    // 80% -> Interests
    final hasInterests = _selectedInterests.length >= 5;
    if (hasInterests) {
      percentage += 20;
    }

    // 100% -> Cover Photo + Location/Social Info Complete
    final hasAdditional = (_coverFile != null || (_user.coverPhoto != null && _user.coverPhoto!.isNotEmpty)) &&
        _countryCtrl.text.trim().isNotEmpty &&
        _selectedGender != null &&
        _occupationCtrl.text.trim().isNotEmpty &&
        _dob != null;
    if (hasAdditional && percentage == 80) {
      percentage += 20;
    }

    return percentage;
  }

  void _checkUsername(String val) async {
    final cleanVal = val.trim().toLowerCase();
    if (cleanVal == _user.username) {
      setState(() {
        _usernameChecked = true;
        _usernameAvailable = true;
        _usernameError = null;
      });
      return;
    }

    if (cleanVal.length < 3 || cleanVal.length > 20) {
      setState(() {
        _usernameError = 'Length must be between 3 and 20 characters';
        _usernameChecked = false;
      });
      return;
    }

    final validCharacters = RegExp(r'^[a-zA-Z0-9_]+$');
    if (!validCharacters.hasMatch(cleanVal)) {
      setState(() {
        _usernameError = 'Only letters, numbers, and underscores allowed';
        _usernameChecked = false;
      });
      return;
    }

    // Profanity Filter
    final profanities = ['admin', 'moderator', 'support', 'creania', 'staff', 'owner'];
    if (profanities.contains(cleanVal)) {
      setState(() {
        _usernameError = 'Reserved username cannot be used';
        _usernameChecked = false;
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      final res = await Supabase.instance.client
          .from('profiles')
          .select('id')
          .eq('username', cleanVal)
          .maybeSingle();

      if (res != null) {
        setState(() {
          _usernameChecked = true;
          _usernameAvailable = false;
          _suggestions = ['${cleanVal}_123', '${cleanVal}_creania', '${cleanVal}_99'];
          _isLoading = false;
        });
      } else {
        setState(() {
          _usernameChecked = true;
          _usernameAvailable = true;
          _usernameError = null;
          _suggestions = [];
          _isLoading = false;
        });
      }
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  void _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1940),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _dob = picked;
        final today = DateTime.now();
        int age = today.year - picked.year;
        if (today.month < picked.month || (today.month == picked.month && today.day < picked.day)) {
          age--;
        }
        _age = age;
      });
    }
  }

  Future<void> _pickImage(bool isAvatar) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile != null) {
      setState(() {
        if (isAvatar) {
          _avatarFile = File(pickedFile.path);
        } else {
          _coverFile = File(pickedFile.path);
        }
      });
    }
  }

  void _saveChanges() async {
    if (!_usernameAvailable) {
      Get.snackbar('Error', 'Please choose an available username');
      return;
    }
    if (_dob != null && _age < 13) {
      Get.snackbar('Error', 'Minimum age requirement is 13');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userId = _user.id;

      // 1. Upload Avatar
      String? avatarUrl = _user.avatar;
      if (_avatarFile != null) {
        debugPrint('[Profile Update] Upload started: Avatar');
        try {
          final path = '$userId/avatar.png';
          await Supabase.instance.client.storage.from('avatars').upload(
            path,
            _avatarFile!,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
          );
          avatarUrl = Supabase.instance.client.storage.from('avatars').getPublicUrl(path);
          debugPrint('[Profile Update] Upload success: Avatar URL = $avatarUrl');
        } catch (e) {
          debugPrint('[Profile Update] Upload failed: Avatar: $e');
          Get.snackbar('Upload Failed ⚠️', 'Failed to upload profile avatar. Please try again.');
          setState(() => _isLoading = false);
          return;
        }
      }

      // 2. Upload Cover
      String? coverUrl = _user.coverPhoto;
      if (_coverFile != null) {
        debugPrint('[Profile Update] Upload started: Cover');
        try {
          final path = '$userId/banner.png';
          await Supabase.instance.client.storage.from('banners').upload(
            path,
            _coverFile!,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
          );
          coverUrl = Supabase.instance.client.storage.from('banners').getPublicUrl(path);
          debugPrint('[Profile Update] Upload success: Cover URL = $coverUrl');
        } catch (e) {
          debugPrint('[Profile Update] Upload failed: Cover: $e');
          Get.snackbar('Upload Failed ⚠️', 'Failed to upload cover photo. Please try again.');
          setState(() => _isLoading = false);
          return;
        }
      }

      final prevPercent = _calculateCompletion(); // Calculate completion before saving changes

      // 3. Update profiles
      final Map<String, dynamic> updatePayload = {
        'display_name': _displayNameCtrl.text.trim(),
        'full_name': _displayNameCtrl.text.trim(),
        'username': _usernameCtrl.text.trim().toLowerCase(),
        'bio': _bioCtrl.text.trim(),
        'profile_photo': avatarUrl,
        'avatar_url': avatarUrl,
        'cover_photo': coverUrl,
        'country': _countryCtrl.text.trim(),
        'state': _stateCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'language': _languageCtrl.text.trim(),
        'profession': _occupationCtrl.text.trim(),
        'education': _collegeCtrl.text.trim().isNotEmpty 
            ? _collegeCtrl.text.trim() 
            : (_schoolCtrl.text.trim().isNotEmpty ? _schoolCtrl.text.trim() : _companyCtrl.text.trim()),
        'website': _websiteCtrl.text.trim(),
        'instagram': _instagramCtrl.text.trim(),
        'youtube': _youtubeCtrl.text.trim(),
        'twitter': _twitterCtrl.text.trim(),
        'dob': _dob?.toIso8601String(),
        'age': _age,
        'gender': _selectedGender,
        'interests': _selectedInterests.toList(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      // If it reached 100% completion now, award 100 coins and badge if not already awarded
      bool didComplete100 = false;
      if (prevPercent == 100 && !_user.badges.contains('Early Explorer')) {
        didComplete100 = true;
        updatePayload['badges'] = [..._user.badges, 'Early Explorer'];
        updatePayload['avatar_frame'] = 'Early Explorer Frame';
      }

      debugPrint('[Profile Update] Database update started');
      try {
        await Supabase.instance.client.from('profiles').update(updatePayload).eq('id', userId);
        debugPrint('[Profile Update] Database update success');
      } catch (dbError) {
        debugPrint('[Profile Update] Database update failed: $dbError');
        rethrow;
      }

      if (didComplete100) {
        // Increment wallet coins
        try {
          final walletRes = await Supabase.instance.client
              .from('wallets')
              .select('coins_balance')
              .eq('id', userId)
              .maybeSingle();
          final currentCoins = walletRes?['coins_balance'] ?? 0;
          await Supabase.instance.client.from('wallets').upsert({
            'id': userId,
            'coins_balance': currentCoins + 100,
            'inr_balance': 0.00,
            'withdrawable_balance': 0.00,
          });
        } catch (_) {}
      }

      // Sync and reload cache
      UserProfileCacheManager.invalidateCache(userId);
      await UserProgressSyncService.syncFromSupabase();

      setState(() => _isLoading = false);

      if (didComplete100) {
        _showCompletionRewardDialog();
      } else {
        Get.back();
        Get.snackbar('Success', 'Profile updated successfully 🎉');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      Get.snackbar('Error', e.toString());
    }
  }

  void _showCompletionRewardDialog() {
    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          backgroundColor: AppTheme.bgLight,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(
            '100% Profile Complete! 🎉',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.accentColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.stars_rounded, color: AppTheme.accentColor, size: 48),
              ),
              const SizedBox(height: 18),
              Text(
                'You have unlocked early explorer status!',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(color: AppTheme.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              _dialogRewardRow('🎖️', 'Early Explorer Badge'),
              _dialogRewardRow('🪙', '100 Gold Coins Added'),
              _dialogRewardRow('✨', '7-Day Avatar Frame Unlocked'),
            ],
          ),
          actions: [
            Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Get.back(); // Go back to profile screen
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Awesome!'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dialogRewardRow(String emoji, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Text(title, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final completionPercent = _calculateCompletion();
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: Text('Edit Profile', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.check, color: AppTheme.primaryColor),
            onPressed: _saveChanges,
          ),
        ],
      ),
      body: _isLoading && UserProfileCacheManager.currentUser == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Completion Tracker Card
                  _buildCompletionCard(completionPercent),
                  const SizedBox(height: 24),

                  // Cover & Avatar Pickers
                  _buildMediaSelector(),
                  const SizedBox(height: 24),

                  _sectionHeader('Basic Identity'),
                  _buildInputField('Display Name', _displayNameCtrl, hint: 'John Doe'),
                  const SizedBox(height: 12),
                  _buildUsernameInput(),
                  const SizedBox(height: 12),
                  _buildInputField('Bio (Max 150 chars)', _bioCtrl, hint: 'Share something about yourself', maxLines: 3),
                  const SizedBox(height: 12),
                  _buildDobSelector(),
                  const SizedBox(height: 12),
                  _buildGenderSelector(),
                  const SizedBox(height: 24),

                  _sectionHeader('Location'),
                  _buildInputField('Country', _countryCtrl, hint: 'India'),
                  const SizedBox(height: 12),
                  _buildInputField('State', _stateCtrl, hint: 'Maharashtra'),
                  const SizedBox(height: 12),
                  _buildInputField('City', _cityCtrl, hint: 'Mumbai'),
                  const SizedBox(height: 12),
                  _buildInputField('Languages', _languageCtrl, hint: 'English, Hindi'),
                  const SizedBox(height: 24),

                  _sectionHeader('Education & Career'),
                  _buildInputField('Occupation', _occupationCtrl, hint: 'Software Engineer'),
                  const SizedBox(height: 12),
                  _buildInputField('School', _schoolCtrl, hint: 'High School Name'),
                  const SizedBox(height: 12),
                  _buildInputField('College', _collegeCtrl, hint: 'IIT Bombay'),
                  const SizedBox(height: 12),
                  _buildInputField('Company', _companyCtrl, hint: 'Google'),
                  const SizedBox(height: 24),

                  _sectionHeader('Social Links & Website'),
                  _buildInputField('Website', _websiteCtrl, hint: 'https://johndoe.com'),
                  const SizedBox(height: 12),
                  _buildInputField('Instagram', _instagramCtrl, hint: 'instagram.com/johndoe'),
                  const SizedBox(height: 12),
                  _buildInputField('YouTube', _youtubeCtrl, hint: 'youtube.com/johndoe'),
                  const SizedBox(height: 12),
                  _buildInputField('X (Twitter)', _twitterCtrl, hint: 'twitter.com/johndoe'),
                  const SizedBox(height: 24),

                  _sectionHeader('Interests'),
                  _buildInterestsGrid(),
                  const SizedBox(height: 48),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _saveChanges,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Save Profile Details', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildCompletionCard(int percentage) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Profile Completion', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              Text('$percentage%', style: GoogleFonts.poppins(color: AppTheme.accentColor, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: percentage / 100,
            backgroundColor: AppTheme.borderColor,
            color: AppTheme.accentColor,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 12),
          Text(
            percentage == 100
                ? '🎉 Congratulations! 100% complete. Early explorer benefits unlocked.'
                : 'Complete your profile to 100% to unlock the "Early Explorer" badge & 100 coins!',
            style: GoogleFonts.poppins(color: AppTheme.textTertiary, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaSelector() {
    return Column(
      children: [
        // Cover picker container
        GestureDetector(
          onTap: () => _pickImage(false),
          child: Container(
            width: double.infinity,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderColor),
              image: _coverFile != null
                  ? DecorationImage(image: FileImage(_coverFile!), fit: BoxFit.cover)
                  : (_user.coverPhoto != null && _user.coverPhoto!.isNotEmpty)
                      ? DecorationImage(image: NetworkImage(_user.coverPhoto!), fit: BoxFit.cover)
                      : null,
            ),
            child: _coverFile == null && (_user.coverPhoto == null || _user.coverPhoto!.isEmpty)
                ? const Center(child: Icon(Icons.add_photo_alternate_rounded, color: Colors.white60, size: 28))
                : null,
          ),
        ),
        const SizedBox(height: 16),

        // Avatar picker
        Center(
          child: Stack(
            children: [
              CircleAvatar(
                radius: 46,
                backgroundColor: AppTheme.primaryColor,
                child: CircleAvatar(
                  radius: 43,
                  backgroundColor: AppTheme.bgDark,
                  backgroundImage: _avatarFile != null
                      ? FileImage(_avatarFile!) as ImageProvider<Object>
                      : (_user.avatar != null && _user.avatar!.isNotEmpty)
                          ? NetworkImage(_user.avatar!) as ImageProvider<Object>
                          : null,
                  child: _avatarFile == null && (_user.avatar == null || _user.avatar!.isEmpty)
                      ? const Icon(Icons.person_rounded, size: 40, color: Colors.white54)
                      : null,
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () => _pickImage(true),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(color: AppTheme.primaryColor, shape: BoxShape.circle),
                    child: const Icon(Icons.edit_rounded, color: Colors.white, size: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Text(
        title,
        style: GoogleFonts.outfit(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 16),
      ),
    );
  }

  Widget _buildInputField(String label, TextEditingController controller, {required String hint, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.poppins(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    );
  }

  Widget _buildUsernameInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Username', style: GoogleFonts.poppins(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: _usernameCtrl,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            prefixText: '@ ',
            prefixStyle: const TextStyle(color: AppTheme.accentColor, fontWeight: FontWeight.bold),
            suffixIcon: !_usernameChecked
                ? null
                : Icon(_usernameAvailable ? Icons.check_circle_outline : Icons.cancel_outlined,
                    color: _usernameAvailable ? AppTheme.successColor : AppTheme.errorColor, size: 18),
          ),
          onChanged: (val) {
            setState(() {
              _usernameChecked = false;
              _usernameAvailable = false;
            });
            _checkUsername(val);
          },
        ),
        if (_usernameError != null) ...[
          const SizedBox(height: 4),
          Text(_usernameError!, style: TextStyle(color: AppTheme.errorColor, fontSize: 11)),
        ],
        if (!_usernameAvailable && _suggestions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: _suggestions.map((sug) => ActionChip(
              label: Text('@$sug'),
              backgroundColor: AppTheme.bgLight,
              onPressed: () {
                _usernameCtrl.text = sug;
                _checkUsername(sug);
              },
            )).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildDobSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Date of Birth *', style: GoogleFonts.poppins(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () => _selectDate(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.bgLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _dob == null ? 'Select Birthday' : DateFormat('dd MMM yyyy').format(_dob!),
                  style: TextStyle(color: _dob == null ? AppTheme.textTertiary : Colors.white, fontSize: 14),
                ),
                const Icon(Icons.calendar_month_rounded, color: AppTheme.textTertiary, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGenderSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Gender', style: GoogleFonts.poppins(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppTheme.bgLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedGender,
              hint: const Text('Select Gender', style: TextStyle(color: AppTheme.textTertiary)),
              dropdownColor: AppTheme.bgLight,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              isExpanded: true,
              items: ['Male', 'Female', 'Non-Binary', 'Prefer not to say']
                  .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                  .toList(),
              onChanged: (val) => setState(() => _selectedGender = val),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInterestsGrid() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _allInterests.map((interest) {
        final isSelected = _selectedInterests.contains(interest);
        return FilterChip(
          label: Text(interest),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              if (selected) {
                _selectedInterests.add(interest);
              } else {
                _selectedInterests.remove(interest);
              }
            });
          },
          selectedColor: AppTheme.primaryColor.withOpacity(0.3),
          checkmarkColor: Colors.white,
          backgroundColor: AppTheme.bgLight,
          labelStyle: TextStyle(color: isSelected ? Colors.white : AppTheme.textSecondary),
        );
      }).toList(),
    );
  }
}

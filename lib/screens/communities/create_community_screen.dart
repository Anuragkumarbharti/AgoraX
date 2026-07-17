import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:creania/core/theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import '../../services/community_controller.dart';
import '../../services/user_profile_cache_manager.dart';

class CreateCommunityScreen extends StatefulWidget {
  const CreateCommunityScreen({Key? key}) : super(key: key);

  @override
  State<CreateCommunityScreen> createState() => _CreateCommunityScreenState();
}

class _CreateCommunityScreenState extends State<CreateCommunityScreen> {
  final _controller = Get.find<CommunityController>();
  
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _descController = TextEditingController();
  final _identityTagController = TextEditingController();

  bool _isCheckingUsername = false;
  bool? _isUsernameUnique;

  bool _isCheckingIdentityTag = false;
  bool? _isIdentityTagUnique;

  Timer? _usernameDebounce;
  Timer? _identityTagDebounce;

  void _onUsernameChanged(String val) {
    if (_usernameDebounce?.isActive ?? false) _usernameDebounce!.cancel();
    final cleanVal = val.trim().toLowerCase().replaceAll('@', '');
    if (cleanVal.isEmpty) {
      setState(() {
        _isUsernameUnique = null;
        _isCheckingUsername = false;
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
            .from('communities')
            .select('id')
            .eq('id', cleanVal)
            .maybeSingle();
        setState(() {
          _isUsernameUnique = res == null;
          _isCheckingUsername = false;
        });
      } catch (e) {
        setState(() {
          _isUsernameUnique = null;
          _isCheckingUsername = false;
        });
      }
    });
  }

  void _onIdentityTagChanged(String val) {
    if (_identityTagDebounce?.isActive ?? false) _identityTagDebounce!.cancel();
    final cleanVal = val.trim().toUpperCase();
    if (cleanVal.isEmpty) {
      setState(() {
        _isIdentityTagUnique = null;
        _isCheckingIdentityTag = false;
      });
      return;
    }

    setState(() {
      _isCheckingIdentityTag = true;
      _isIdentityTagUnique = null;
    });

    _identityTagDebounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        final res = await Supabase.instance.client
            .from('communities')
            .select('id')
            .eq('identity_tag', cleanVal)
            .maybeSingle();
        setState(() {
          _isIdentityTagUnique = res == null;
          _isCheckingIdentityTag = false;
        });
      } catch (e) {
        setState(() {
          _isIdentityTagUnique = null;
          _isCheckingIdentityTag = false;
        });
      }
    });
  }
  
  String _selectedCategory = 'Technology';
  String _creationType = 'level'; // 'level', 'coins' or 'ticket'
  final RxInt _ticketCount = 0.obs;
  
  final List<String> _categories = [
    'Technology',
    'Design',
    'Music',
    'Gaming',
    'Education',
    'Entertainment',
    'Sports',
    'Business'
  ];

  @override
  void initState() {
    super.initState();
    _loadTicketCount();
  }

  Future<void> _loadTicketCount() async {
    try {
      final res = await Supabase.instance.client
          .from('inventory')
          .select('id')
          .eq('user_id', CommunityController.currentUserId)
          .or('asset_id.eq.community_creation_ticket,asset_id.eq.creation_ticket')
          .eq('status', 'Active');
      if (res != null && res is List) {
        _ticketCount.value = res.length;
      }
    } catch (_) {}

    final user = UserProfileCacheManager.currentUser;
    final userLevel = user?.level ?? 1;
    final userCoins = _controller.userCoins.value;

    if (userLevel >= 25) {
      setState(() => _creationType = 'level');
    } else if (userCoins >= 699) {
      setState(() => _creationType = 'coins');
    } else if (_ticketCount.value >= 1) {
      setState(() => _creationType = 'ticket');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _descController.dispose();
    _identityTagController.dispose();
    _usernameDebounce?.cancel();
    _identityTagDebounce?.cancel();
    super.dispose();
  }

  Future<void> _submit() async {
    final user = UserProfileCacheManager.currentUser;
    final userLevel = user?.level ?? 1;
    final userCoins = _controller.userCoins.value;

    if (_creationType == 'level' && userLevel < 25) {
      Get.snackbar(
        'Requirement Unmet',
        'You must be at least ID Level 25 to create a community via Level. Your current level is $userLevel.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
      return;
    }

    if (_creationType == 'coins' && userCoins < 699) {
      Get.snackbar(
        'Insufficient Balance',
        'You need 699 Gold Coins to create a community. Your balance: $userCoins Coins.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
      return;
    }

    if (_creationType == 'ticket' && _ticketCount.value < 1) {
      Get.snackbar(
        'No Creation Ticket',
        'You do not have any community creation ticket in your inventory.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
      return;
    }

    final username = _usernameController.text.trim();
    final identityTag = _identityTagController.text.trim().toUpperCase();
    final desc = _descController.text.trim();

    if (username.isEmpty) {
      Get.snackbar(
        'Validation Error',
        'Please enter a community username',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: context.errorColor.withOpacity(0.9),
        colorText: Colors.white,
      );
      return;
    }

    if (!username.startsWith('@')) {
      Get.snackbar(
        'Validation Error',
        'Username must start with @',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: context.errorColor.withOpacity(0.9),
        colorText: Colors.white,
      );
      return;
    }

    final namePart = username.substring(1);
    if (namePart.length < 3) {
      Get.snackbar(
        'Validation Error',
        'Username must be at least 3 characters after @',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: context.errorColor.withOpacity(0.9),
        colorText: Colors.white,
      );
      return;
    }

    final regex = RegExp(r'^[a-z0-9_]+$');
    if (!regex.hasMatch(namePart)) {
      Get.snackbar(
        'Validation Error',
        'Only lowercase letters, numbers, and underscores allowed',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: context.errorColor.withOpacity(0.9),
        colorText: Colors.white,
      );
      return;
    }

    if (_isCheckingUsername || _isCheckingIdentityTag) {
      Get.snackbar(
        'Validation Error',
        'Still checking availability. Please wait a moment.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: context.errorColor.withOpacity(0.9),
        colorText: Colors.white,
      );
      return;
    }

    if (_isUsernameUnique == false) {
      Get.snackbar(
        'Validation Error',
        'Community Username is already taken',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: context.errorColor.withOpacity(0.9),
        colorText: Colors.white,
      );
      return;
    }

    if (identityTag.isEmpty) {
      Get.snackbar(
        'Validation Error',
        'Please enter an Identity Tag',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: context.errorColor.withOpacity(0.9),
        colorText: Colors.white,
      );
      return;
    }

    if (identityTag.length > 7) {
      Get.snackbar(
        'Validation Error',
        'Identity Tag must be maximum 7 characters long',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: context.errorColor.withOpacity(0.9),
        colorText: Colors.white,
      );
      return;
    }

    if (_isIdentityTagUnique == false) {
      Get.snackbar(
        'Validation Error',
        'Identity Tag is already taken',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: context.errorColor.withOpacity(0.9),
        colorText: Colors.white,
      );
      return;
    }

    final String displayName = namePart.capitalizeFirst ?? namePart;

    final error = await _controller.createCommunity(
      id: namePart,
      name: displayName,
      description: desc.isNotEmpty ? desc : 'A beautiful new community for $displayName enthusiasts.',
      category: _selectedCategory,
      language: 'en',
      country: 'IN',
      rules: 'Be respectful. No spamming or self-promotion.',
      joinMode: 'auto_join',
      minIdLevel: 1,
      preferredLanguages: const [],
      preferredCountries: const [],
      preferredInterests: const [],
      tags: const [],
      visibility: 'public',
      logo: displayName.substring(0, 1).toUpperCase(),
      banner: 'https://images.unsplash.com/photo-1579546929518-9e396f3cc809',
      creationMethod: _creationType,
      identityTag: identityTag,
    );

    if (error != null) {
      Get.snackbar(
        'Creation Failed',
        error,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: context.errorColor.withOpacity(0.9),
        colorText: Colors.white,
      );
    } else {
      Get.back();
      Get.snackbar(
        'Success! 🎉',
        'Community "$displayName" created successfully!',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: context.primaryColor.withOpacity(0.9),
        colorText: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = UserProfileCacheManager.currentUser;
    final userLevel = user?.level ?? 1;

    return Scaffold(
      backgroundColor: context.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Create Community'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Get.back(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
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
                  _statusItem('Your Level', 'Lv.$userLevel', userLevel >= 25 ? Colors.green : Colors.grey),
                  _verticalDivider(),
                  Obx(() => _statusItem('Coins', '${_controller.userCoins.value}', _controller.userCoins.value >= 699 ? Colors.green : Colors.grey)),
                  _verticalDivider(),
                  Obx(() => _statusItem('Tickets', '${_ticketCount.value}', _ticketCount.value >= 1 ? Colors.green : Colors.grey)),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Form inputs
            Text(
              'Community Username',
              style: TextStyle(color: context.textSecondary, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _usernameController,
              style: TextStyle(color: context.textPrimary),
              onChanged: _onUsernameChanged,
              decoration: InputDecoration(
                hintText: 'e.g. @gate2027',
                hintStyle: TextStyle(color: context.caption),
                filled: true,
                fillColor: context.secondaryBackgroundColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
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
                    ? 'This will be the unique URL and ID of the community.'
                    : (_isUsernameUnique! ? 'Username is available!' : 'Username is already taken!'),
                helperStyle: TextStyle(
                  color: _isUsernameUnique == null
                      ? context.caption
                      : (_isUsernameUnique! ? Colors.green : Colors.red),
                  fontSize: 11,
                ),
              ),
            ),
            const SizedBox(height: 20),

            Text(
              'Identity Tag',
              style: TextStyle(color: context.textSecondary, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _identityTagController,
              style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold),
              maxLength: 7,
              onChanged: _onIdentityTagChanged,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: 'e.g. GATE',
                hintStyle: TextStyle(color: context.caption),
                filled: true,
                fillColor: context.secondaryBackgroundColor,
                counterText: '', // Hide default counter to make it premium
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isCheckingIdentityTag)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: Padding(
                          padding: EdgeInsets.all(12.0),
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blue),
                        ),
                      )
                    else if (_isIdentityTagUnique != null)
                      Icon(
                        _isIdentityTagUnique! ? Icons.check_circle_rounded : Icons.cancel_rounded,
                        color: _isIdentityTagUnique! ? Colors.green : Colors.red,
                      ),
                    Padding(
                      padding: const EdgeInsets.only(right: 12, left: 8),
                      child: Text(
                        '${_identityTagController.text.length}/7',
                        style: TextStyle(color: context.caption, fontSize: 11),
                      ),
                    ),
                  ],
                ),
                helperText: _isIdentityTagUnique == null
                    ? 'Unique tag assigned to members when they join (Max 7 characters).'
                    : (_isIdentityTagUnique! ? 'Identity Tag is available!' : 'Identity Tag is already taken!'),
                helperStyle: TextStyle(
                  color: _isIdentityTagUnique == null
                      ? context.caption
                      : (_isIdentityTagUnique! ? Colors.green : Colors.red),
                  fontSize: 11,
                ),
              ),
            ),
            const SizedBox(height: 20),

            Text(
              'Description',
              style: TextStyle(color: context.textSecondary, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descController,
              maxLines: 3,
              style: TextStyle(color: context.textPrimary),
              decoration: InputDecoration(
                hintText: 'What is this community about?',
                hintStyle: TextStyle(color: context.caption),
                filled: true,
                fillColor: context.secondaryBackgroundColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),

            Text(
              'Category',
              style: TextStyle(color: context.textSecondary, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: context.secondaryBackgroundColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCategory,
                  dropdownColor: context.secondaryBackgroundColor,
                  style: TextStyle(color: context.textPrimary),
                  isExpanded: true,
                  icon: Icon(Icons.keyboard_arrow_down_rounded, color: context.textSecondary),
                  items: _categories.map((cat) {
                    return DropdownMenuItem(
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
            const SizedBox(height: 28),

            // Select Creation Type
            Text(
              'Choose Creation Method',
              style: TextStyle(color: context.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            
            // Level creation card
            _buildTypeCard(
              type: 'level',
              title: 'Free via ID Level 25+',
              description: 'Create community for free because your ID Level is 25 or above.',
              icon: Icons.military_tech_rounded,
              color: Colors.cyan,
              disabled: userLevel < 25,
            ),
            const SizedBox(height: 12),

            // Coin creation card
            Obx(() => _buildTypeCard(
              type: 'coins',
              title: 'Use 699 Gold Coins',
              description: 'Create using 699 Gold Coins from your wallet balance.',
              icon: Icons.monetization_on_rounded,
              color: Colors.amber,
              disabled: _controller.userCoins.value < 699,
            )),
            const SizedBox(height: 12),

            // Ticket creation card
            Obx(() => _buildTypeCard(
              type: 'ticket',
              title: 'Use Creation Ticket (${_ticketCount.value} Available)',
              description: 'Deduct 1 Community Creation Ticket from your inventory.',
              icon: Icons.local_activity_rounded,
              color: Colors.green,
              disabled: _ticketCount.value < 1,
            )),
            const SizedBox(height: 40),

            // Create button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 4,
                ),
                child: Text(
                  _creationType == 'level'
                      ? 'Free Create (Level 25+)'
                      : (_creationType == 'coins' ? 'Pay 699 Coins & Create' : 'Use Ticket & Create'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
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
}

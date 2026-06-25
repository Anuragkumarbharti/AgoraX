import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/theme.dart';
import '../../services/room_controller.dart';
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
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();
  final TextEditingController _rulesController = TextEditingController();

  String _selectedCategory = 'Education Room';
  String _selectedCountry = 'India';
  String _selectedLanguage = 'English';
  String _selectedPermission = 'everyone';
  bool _isPermanent = false;

  final List<String> _categories = [
    'Public Room', 'Private Room', 'Community Room', 'Family Room',
    'Gaming Room', 'Education Room', 'Podcast Room', 'Business Room',
    'Fan Club Room', 'Music Room', 'Debate Room', 'Coaching Room'
  ];

  final List<String> _countries = ['India', 'USA', 'UK', 'Canada', 'Australia', 'Global'];
  final List<String> _languages = ['English', 'Hindi', 'Bengali', 'Spanish', 'French', 'Arabic'];
  final List<String> _permissions = ['everyone', 'followers_only', 'paid_members', 'vip_only'];

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    _rulesController.dispose();
    super.dispose();
  }

  void _submitForm() {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();
    
    // Parse tags (comma separated)
    final tags = _tagsController.text
        .split(',')
        .map((t) => t.trim().toLowerCase())
        .where((t) => t.isNotEmpty)
        .toList();

    // Parse rules (new line separated or fallback)
    final rules = _rulesController.text
        .split('\n')
        .map((r) => r.trim())
        .where((r) => r.isNotEmpty)
        .toList();

    bool success = true;
    String newRoomId = '';

    if (_isPermanent) {
      success = _controller.createPermanentRoom(
        name: name,
        description: description,
        category: _selectedCategory,
        country: _selectedCountry,
        language: _selectedLanguage,
        tags: tags,
        rules: rules.isEmpty ? ['Be respectful to others.'] : rules,
        entryPermission: _selectedPermission,
      );
      if (success) {
        newRoomId = _controller.rooms.first.id;
      }
    } else {
      _controller.createTemporaryRoom(
        name: name,
        description: description,
        category: _selectedCategory,
        country: _selectedCountry,
        language: _selectedLanguage,
        tags: tags,
        rules: rules.isEmpty ? ['Be respectful to others.'] : rules,
        entryPermission: _selectedPermission,
      );
      newRoomId = _controller.rooms.first.id;
    }

    if (success) {
      Get.back(); // Pop create screen
      
      // Auto-join the newly created room as host
      Get.to(
        () => VoiceRoomCallScreen(
          roomId: newRoomId,
          roomName: name,
          userId: 'current_user',
          userName: 'Current User',
          isHost: true,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: const Text('Create Voice Room'),
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
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
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
                // Room Type Selector Card
                _buildRoomTypeSelector(),
                const SizedBox(height: 24),

                // Name
                Text('Room Name', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  maxLength: 50,
                  decoration: const InputDecoration(
                    hintText: 'e.g., Coding Hub, Music Lounge',
                    counterText: '',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().length < 3) {
                      return 'Room name must be at least 3 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Description
                Text('Description', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'What is this room about? Write a catchy summary...',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a description';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Category & Permission (Two Column Dropdowns)
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Category', style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 8),
                          _buildDropdown(_categories, _selectedCategory, (val) {
                            setState(() => _selectedCategory = val!);
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Entry Permission', style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 8),
                          _buildDropdown(_permissions.map((p) => p.replaceAll('_', ' ').capitalizeFirst!).toList(), 
                              _selectedPermission.replaceAll('_', ' ').capitalizeFirst!, (val) {
                            setState(() => _selectedPermission = val!.toLowerCase().replaceAll(' ', '_'));
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Country & Language Dropdowns
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Country', style: Theme.of(context).textTheme.titleMedium),
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
                          Text('Language', style: Theme.of(context).textTheme.titleMedium),
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

                // Tags (Comma separated)
                Text('Tags (comma separated)', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _tagsController,
                  decoration: const InputDecoration(
                    hintText: 'e.g., flutter, gaming, debate, news',
                  ),
                ),
                const SizedBox(height: 16),

                // Rules (Newline separated)
                Text('Room Rules (one rule per line)', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _rulesController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: '1. Be respectful\n2. No spam\n3. Wait for your turn to speak',
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
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      _isPermanent ? 'Unlock Permanent Room (599 Coins)' : 'Launch Free Temporary Room',
                      style: TextStyle(
                        fontSize: 16,
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
          const Text(
            'Choose Room Type',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
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
                          Icons.timer,
                          color: !_isPermanent ? AppTheme.primaryColor : AppTheme.textTertiary,
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Temporary',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: !_isPermanent ? Colors.white : AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Free • Auto-deletes when empty',
                          style: TextStyle(fontSize: 10, color: AppTheme.textTertiary),
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
                          Icons.workspace_premium,
                          color: _isPermanent ? Colors.amber : AppTheme.textTertiary,
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Permanent',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _isPermanent ? Colors.amber : AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '599 Coins • Never expires • Level & XP enabled',
                          style: TextStyle(
                            fontSize: 10,
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
          style: const TextStyle(color: Colors.white, fontSize: 14),
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
}

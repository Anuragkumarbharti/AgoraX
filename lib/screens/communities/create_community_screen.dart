import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/theme.dart';
import '../../services/community_controller.dart';

class CreateCommunityScreen extends StatefulWidget {
  const CreateCommunityScreen({Key? key}) : super(key: key);

  @override
  State<CreateCommunityScreen> createState() => _CreateCommunityScreenState();
}

class _CreateCommunityScreenState extends State<CreateCommunityScreen> {
  final _controller = Get.find<CommunityController>();
  
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  
  String _selectedCategory = 'Technology';
  String _creationType = 'coins'; // 'coins' or 'apply'
  
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
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    final desc = _descController.text.trim();

    if (name.isEmpty) {
      Get.snackbar(
        'Validation Error',
        'Please enter a community name',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppTheme.errorColor.withOpacity(0.9),
        colorText: Colors.white,
      );
      return;
    }

    final error = _controller.createCommunity(
      name: name,
      description: desc.isNotEmpty ? desc : 'A beautiful new community for $name enthusiasts.',
      category: _selectedCategory,
      creationType: _creationType,
      logo: name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'C',
    );

    if (error != null) {
      Get.snackbar(
        'Creation Failed',
        error,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppTheme.errorColor.withOpacity(0.9),
        colorText: Colors.white,
      );
    } else {
      Get.back();
      Get.snackbar(
        'Success! 🎉',
        _creationType == 'coins'
            ? 'Community "$name" created successfully!'
            : 'Application submitted! Complete tasks to unlock the logo.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppTheme.primaryColor.withOpacity(0.9),
        colorText: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
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
            // Current Coins Balance
            Obx(() => Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.monetization_on_rounded, color: Colors.yellow, size: 28),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Your Coins Balance',
                        style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        '${_controller.userCoins.value} Coins',
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            )),
            const SizedBox(height: 24),

            // Form inputs
            const Text(
              'Community Name',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'e.g. Flutter Superstars',
                hintStyle: const TextStyle(color: AppTheme.textTertiary),
                filled: true,
                fillColor: AppTheme.bgLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              'Description',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descController,
              maxLines: 3,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'What is this community about?',
                hintStyle: const TextStyle(color: AppTheme.textTertiary),
                filled: true,
                fillColor: AppTheme.bgLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              'Category',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppTheme.bgLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCategory,
                  dropdownColor: AppTheme.bgLight,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.textSecondary),
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
            const Text(
              'Choose Creation Method',
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            
            // Coin creation card
            _buildTypeCard(
              type: 'coins',
              title: 'Instant Creation (10,000 Coins)',
              description: 'Your community is created instantly with fully unlocked verified logo and profile badge.',
              icon: Icons.flash_on_rounded,
              color: Colors.amber,
            ),
            const SizedBox(height: 12),

            // Apply creation card
            _buildTypeCard(
              type: 'apply',
              title: 'Apply & Complete Tasks (Free)',
              description: 'Submit an application. Unlock community logo and profile badge after completing milestones.',
              icon: Icons.assignment_turned_in_rounded,
              color: Colors.green,
            ),
            const SizedBox(height: 40),

            // Create button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 4,
                ),
                child: Text(
                  _creationType == 'coins' ? 'Pay 10,000 Coins & Create' : 'Submit Free Application',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeCard({
    required String type,
    required String title,
    required String description,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _creationType == type;
    return GestureDetector(
      onTap: () => setState(() => _creationType = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.bgLight : AppTheme.bgLight.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor,
            width: isSelected ? 2 : 1,
          ),
        ),
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
                      color: isSelected ? Colors.white : AppTheme.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: const TextStyle(
                      color: AppTheme.textTertiary,
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
    );
  }
}

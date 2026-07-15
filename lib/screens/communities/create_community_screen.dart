import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:creania/core/theme.dart';
import '../../services/community_controller.dart';

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
    _usernameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final username = _usernameController.text.trim();
    final desc = _descController.text.trim();

    if (name.isEmpty) {
      Get.snackbar(
        'Validation Error',
        'Please enter a community name',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: context.errorColor.withOpacity(0.9),
        colorText: Colors.white,
      );
      return;
    }

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

    final error = await _controller.createCommunity(
      name: name,
      username: username,
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
        backgroundColor: context.errorColor.withOpacity(0.9),
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
        backgroundColor: context.primaryColor.withOpacity(0.9),
        colorText: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Create Community'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Get.back(),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current Coins Balance
            Obx(() => Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [context.primaryColor, AppTheme.secondaryColor],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(Icons.monetization_on_rounded, color: Colors.yellow, size: 28),
                  SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Coins Balance',
                        style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        '${_controller.userCoins.value} Coins',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            )),
            SizedBox(height: 24),

            // Form inputs
            Text(
              'Community Name',
              style: TextStyle(color: context.textSecondary, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            TextField(
              controller: _nameController,
              style: TextStyle(color: context.textPrimary),
              decoration: InputDecoration(
                hintText: 'e.g. Flutter Superstars',
                hintStyle: TextStyle(color: context.caption),
                filled: true,
                fillColor: context.secondaryBackgroundColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            SizedBox(height: 20),

            Text(
              'Community Username',
              style: TextStyle(color: context.textSecondary, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            TextField(
              controller: _usernameController,
              style: TextStyle(color: context.textPrimary),
              decoration: InputDecoration(
                hintText: 'e.g. @gate2027',
                hintStyle: TextStyle(color: context.caption),
                filled: true,
                fillColor: context.secondaryBackgroundColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            SizedBox(height: 20),

            Text(
              'Description',
              style: TextStyle(color: context.textSecondary, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
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
            SizedBox(height: 20),

            Text(
              'Category',
              style: TextStyle(color: context.textSecondary, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16),
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
            SizedBox(height: 28),

            // Select Creation Type
            Text(
              'Choose Creation Method',
              style: TextStyle(color: context.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            
            // Coin creation card
            _buildTypeCard(
              type: 'coins',
              title: 'Instant Creation (10,000 Coins)',
              description: 'Your community is created instantly with fully unlocked verified logo and profile badge.',
              icon: Icons.flash_on_rounded,
              color: Colors.amber,
            ),
            SizedBox(height: 12),

            // Apply creation card
            _buildTypeCard(
              type: 'apply',
              title: 'Apply & Complete Tasks (Free)',
              description: 'Submit an application. Unlock community logo and profile badge after completing milestones.',
              icon: Icons.assignment_turned_in_rounded,
              color: Colors.green,
            ),
            SizedBox(height: 40),

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
                  _creationType == 'coins' ? 'Pay 10,000 Coins & Create' : 'Submit Free Application',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? context.secondaryBackgroundColor : context.secondaryBackgroundColor.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? context.primaryColor : context.borderColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            SizedBox(width: 14),
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
                  SizedBox(height: 6),
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
    );
  }
}

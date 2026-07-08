import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/theme.dart';
import '../../services/study_category_controller.dart';
import 'daily_task_screen.dart';

class CategorySelectionScreen extends StatefulWidget {
  final bool canGoBack;
  const CategorySelectionScreen({Key? key, this.canGoBack = false}) : super(key: key);

  @override
  State<CategorySelectionScreen> createState() => _CategorySelectionScreenState();
}

class _CategorySelectionScreenState extends State<CategorySelectionScreen> {
  final StudyCategoryController _controller = Get.find<StudyCategoryController>();
  String? _selectedSubcategory;
  String? _expandedCategoryGroup;

  @override
  void initState() {
    super.initState();
    // Default expanded group is the first one
    _expandedCategoryGroup = _controller.categoriesHierarchy.keys.first;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: widget.canGoBack
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
                onPressed: () => Get.back(),
              ),
              title: const Text('Change Category', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            )
          : null,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              // Header
              Text(
                'Select Your Study Category',
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose your primary study category to receive personalized videos, quizzes, current affairs, and learning tasks.',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              // Important Lock Warning Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock_clock_outlined, color: Color(0xFFEF4444), size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'This category can only be changed once every 30 days. Choose wisely!',
                        style: TextStyle(
                          color: const Color(0xFFEF4444).withOpacity(0.95),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // Hierarchical list of categories
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  children: _controller.categoriesHierarchy.entries.map((entry) {
                    final groupName = entry.key;
                    final subcategories = entry.value;
                    final isExpanded = _expandedCategoryGroup == groupName;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.cardBg,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isExpanded
                              ? AppTheme.primaryColor.withOpacity(0.5)
                              : AppTheme.borderColor.withOpacity(0.5),
                        ),
                      ),
                      child: Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          key: PageStorageKey<String>(groupName),
                          initiallyExpanded: isExpanded,
                          title: Row(
                            children: [
                              Text(
                                _getCategoryEmoji(groupName),
                                style: const TextStyle(fontSize: 20),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                groupName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          iconColor: AppTheme.primaryColor,
                          collapsedIconColor: AppTheme.textTertiary,
                          onExpansionChanged: (expanded) {
                            setState(() {
                              _expandedCategoryGroup = expanded ? groupName : null;
                            });
                          },
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: subcategories.map((sub) {
                                  final isSelected = _selectedSubcategory == sub;
                                  return GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _selectedSubcategory = sub;
                                      });
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppTheme.primaryColor.withOpacity(0.12)
                                            : AppTheme.bgDark.withOpacity(0.6),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isSelected
                                              ? AppTheme.primaryColor
                                              : AppTheme.borderColor.withOpacity(0.4),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (isSelected) ...[
                                            const Icon(Icons.check_circle, color: AppTheme.primaryColor, size: 14),
                                            const SizedBox(width: 6),
                                          ],
                                          Text(
                                            sub,
                                            style: TextStyle(
                                              color: isSelected ? Colors.white : AppTheme.textSecondary,
                                              fontSize: 12,
                                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              
              const SizedBox(height: 16),
              // Action Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedSubcategory != null ? AppTheme.primaryColor : AppTheme.cardBg,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  onPressed: _selectedSubcategory != null
                      ? () => _confirmCategorySelection()
                      : null,
                  child: Text(
                    'Choose Category',
                    style: TextStyle(
                      color: _selectedSubcategory != null ? Colors.white : AppTheme.textTertiary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Display custom emojis for root category groups
  String _getCategoryEmoji(String groupName) {
    switch (groupName) {
      case 'Engineering':
        return '💻';
      case 'Medical':
        return '🏥';
      case 'Management':
        return '💼';
      case 'Government Exams':
        return '🏛️';
      case 'Entrance Exams':
        return '🎓';
      case 'Coding & Technology':
        return '⚡';
      case 'School':
        return '🏫';
      case 'General Learning':
        return '🧠';
      default:
        return '📚';
    }
  }

  // Show a final warning sheet to confirm 30-day lock
  void _confirmCategorySelection() {
    if (_selectedSubcategory == null) return;

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppTheme.bgLight,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.borderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Color(0xFFFBBF24), size: 28),
                SizedBox(width: 12),
                Text(
                  'Confirm Category Lock',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            RichText(
              text: TextSpan(
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.6),
                children: [
                  const TextSpan(text: 'You are selecting '),
                  TextSpan(
                    text: _selectedSubcategory,
                    style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(text: ' as your study path.\n\nThis will lock your choice for '),
                  const TextSpan(
                    text: '30 Days',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(text: '. You cannot change this selection or switch to another category to farm rewards, even by reinstalling the app.'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppTheme.borderColor),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Get.back(),
                      child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        Get.back(); // close sheet
                        await _controller.selectCategoryAndLock(_selectedSubcategory!);
                        Get.snackbar(
                          '🎉 Category Locked!',
                          'Your study category is set to $_selectedSubcategory',
                          snackPosition: SnackPosition.BOTTOM,
                          backgroundColor: AppTheme.accentColor.withOpacity(0.9),
                          colorText: Colors.white,
                        );
                        if (widget.canGoBack) {
                          Get.back(); // Pop Category Selection Screen
                        } else {
                          Get.off(() => DailyTaskScreen());
                        }
                      },
                      child: const Text('Lock Selection', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

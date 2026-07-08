import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/theme.dart';
import '../../models/career_dna_model.dart';

class SkillTreeScreen extends StatefulWidget {
  const SkillTreeScreen({Key? key}) : super(key: key);

  @override
  State<SkillTreeScreen> createState() => _SkillTreeScreenState();
}

class _SkillTreeScreenState extends State<SkillTreeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _sparkController;
  final List<SkillTree> _trees = SkillTree.mockTrees();
  int _selectedTreeIndex = 0;

  SkillTree get _currentTree => _trees[_selectedTreeIndex];

  @override
  void initState() {
    super.initState();
    _sparkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _sparkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        backgroundColor: AppTheme.bgDark,
        elevation: 0,
        leading: IconButton(
          icon:
              const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        title: const Text(
          'AI Skill Tree',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Column(
        children: [
          _buildTreeSelector(),
          _buildTreeStats(),
          Expanded(child: _buildSkillTree()),
        ],
      ),
    );
  }

  Widget _buildTreeSelector() {
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _trees.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (ctx, i) {
          final tree = _trees[i];
          final isSelected = _selectedTreeIndex == i;
          return GestureDetector(
            onTap: () => setState(() => _selectedTreeIndex = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? LinearGradient(
                        colors: [
                          tree.color,
                          tree.color.withOpacity(0.7),
                        ],
                      )
                    : null,
                color: isSelected ? null : AppTheme.bgLight,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color:
                      isSelected ? Colors.transparent : AppTheme.borderColor,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: tree.color.withOpacity(0.35),
                          blurRadius: 8,
                        )
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(tree.emoji, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                  Text(
                    tree.name,
                    style: TextStyle(
                      color: isSelected ? Colors.white : AppTheme.textTertiary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTreeStats() {
    final nodes = _currentTree.roots;
    final completed = nodes.where((n) => n.status == SkillNodeStatus.completed).length;
    final inProgress = nodes.where((n) => n.status == SkillNodeStatus.inProgress).length;
    final totalXp = nodes.fold(0, (s, n) => s + n.xpReward);
    final earnedXp = nodes
        .where((n) => n.status == SkillNodeStatus.completed)
        .fold(0, (s, n) => s + n.xpReward);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _currentTree.color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _currentTree.color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _treeStat('✅ $completed', 'Completed', AppTheme.accentColor),
          _treeStat('⚡ $inProgress', 'In Progress', _currentTree.color),
          _treeStat('🔒 ${nodes.length - completed - inProgress}', 'Locked',
              AppTheme.textTertiary),
          _treeStat('⚡$earnedXp/$totalXp', 'XP', const Color(0xFFFBBF24)),
        ],
      ),
    );
  }

  Widget _treeStat(String value, String label, Color color) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                color: color, fontSize: 13, fontWeight: FontWeight.w800)),
        Text(label,
            style: const TextStyle(
                color: AppTheme.textTertiary, fontSize: 10)),
      ],
    );
  }

  Widget _buildSkillTree() {
    final nodes = _currentTree.roots;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Tree title
        Row(
          children: [
            Text(_currentTree.emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 10),
            Text(
              '${_currentTree.name} Skill Tree',
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Nodes as a vertical tree with connectors
        ...nodes.asMap().entries.map((e) {
          return Column(
            children: [
              _buildNodeCard(e.value, e.key),
              if (e.key < nodes.length - 1) _buildConnector(e.value.status),
            ],
          );
        }),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildConnector(SkillNodeStatus status) {
    final isUnlocked = status == SkillNodeStatus.completed;
    return Container(
      width: 2,
      height: 32,
      margin: const EdgeInsets.only(left: 37),
      decoration: BoxDecoration(
        gradient: isUnlocked
            ? LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  _currentTree.color,
                  _currentTree.color.withOpacity(0.3),
                ],
              )
            : null,
        color: isUnlocked ? null : AppTheme.borderColor,
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }

  Widget _buildNodeCard(SkillNode node, int index) {
    final isCompleted = node.status == SkillNodeStatus.completed;
    final isInProgress = node.status == SkillNodeStatus.inProgress;
    final isLocked = node.status == SkillNodeStatus.locked;
    final color = _currentTree.color;

    return GestureDetector(
      onTap: () => _showNodeDetail(node),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isCompleted
              ? color.withOpacity(0.1)
              : isInProgress
                  ? AppTheme.cardBg
                  : AppTheme.bgLight.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCompleted
                ? color.withOpacity(0.4)
                : isInProgress
                    ? color.withOpacity(0.3)
                    : AppTheme.borderColor.withOpacity(0.3),
            width: isInProgress ? 1.5 : 1,
          ),
          boxShadow: isInProgress
              ? [BoxShadow(color: color.withOpacity(0.15), blurRadius: 8)]
              : null,
        ),
        child: Row(
          children: [
            // Node icon
            AnimatedBuilder(
              animation: _sparkController,
              builder: (ctx, _) => Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isLocked
                      ? AppTheme.bgLight
                      : color.withOpacity(
                          isInProgress
                              ? 0.15 + 0.1 * _sparkController.value
                              : 0.15),
                  border: Border.all(
                    color: isCompleted
                        ? color
                        : isInProgress
                            ? color.withOpacity(
                                0.5 + 0.3 * _sparkController.value)
                            : AppTheme.borderColor,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: isLocked
                      ? const Text('🔒', style: TextStyle(fontSize: 20))
                      : isCompleted
                          ? const Icon(Icons.check_circle_rounded,
                              color: Colors.white, size: 26)
                          : Text(node.icon,
                              style: TextStyle(
                                  fontSize: node.icon.length > 2 ? 12 : 20,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900)),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        node.name,
                        style: TextStyle(
                          color: isLocked
                              ? AppTheme.textTertiary
                              : AppTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (isCompleted)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.accentColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            '✅ Done',
                            style: TextStyle(
                              color: AppTheme.accentColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )
                      else if (isInProgress)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '⚡ In Progress',
                            style: TextStyle(
                              color: color,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (node.description.isNotEmpty)
                    Text(
                      node.description,
                      style: const TextStyle(
                          color: AppTheme.textTertiary, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (isInProgress) ...[
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: node.progress,
                        minHeight: 5,
                        backgroundColor: AppTheme.borderColor,
                        valueColor: AlwaysStoppedAnimation(color),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${node.tasksCompleted}/${node.tasksRequired} tasks',
                      style: TextStyle(
                          color: color, fontSize: 10, fontWeight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '⚡${node.xpReward}',
                  style: const TextStyle(
                    color: Color(0xFFFBBF24),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                if (!isLocked)
                  Icon(Icons.chevron_right_rounded,
                      color: color, size: 20)
                else
                  const Icon(Icons.lock_rounded,
                      color: AppTheme.textTertiary, size: 16),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showNodeDetail(SkillNode node) {
    final color = _currentTree.color;
    final isLocked = node.status == SkillNodeStatus.locked;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bgLight,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.borderColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.15),
                border: Border.all(color: color.withOpacity(0.4), width: 2),
              ),
              child: Center(
                child: Text(
                  isLocked ? '🔒' : node.icon,
                  style: TextStyle(
                    fontSize: isLocked ? 28 : (node.icon.length > 2 ? 18 : 32),
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(node.name,
                style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            if (node.description.isNotEmpty)
              Text(
                node.description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppTheme.textTertiary, fontSize: 13),
              ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _nodeChip('⚡ +${node.xpReward} XP', const Color(0xFFFBBF24)),
                const SizedBox(width: 10),
                _nodeChip(
                    '${node.tasksRequired} Tasks Required', color),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isLocked ? AppTheme.borderColor : color,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: isLocked
                    ? null
                    : () {
                        Navigator.pop(ctx);
                        if (node.status == SkillNodeStatus.inProgress) {
                          setState(() {
                            node.tasksCompleted =
                                (node.tasksCompleted + 1)
                                    .clamp(0, node.tasksRequired);
                            if (node.tasksCompleted == node.tasksRequired) {
                              node.status = SkillNodeStatus.completed;
                            }
                          });
                        }
                        Get.snackbar(
                          '⚡ Task Started!',
                          'Complete ${node.name} tasks to unlock this node',
                          snackPosition: SnackPosition.BOTTOM,
                          backgroundColor: color.withOpacity(0.9),
                          colorText: Colors.white,
                        );
                      },
                child: Text(
                  isLocked
                      ? '🔒 Complete Previous Nodes First'
                      : node.status == SkillNodeStatus.completed
                          ? '✅ Completed — View Certificate'
                          : '▶️ Continue Learning',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _nodeChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

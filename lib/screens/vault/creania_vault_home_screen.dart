// lib/screens/vault/creania_vault_home_screen.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/vault_controller.dart';
import '../../models/vault_models.dart';

class CreaniaVaultHomeScreen extends StatefulWidget {
  const CreaniaVaultHomeScreen({Key? key}) : super(key: key);

  @override
  State<CreaniaVaultHomeScreen> createState() => _CreaniaVaultHomeScreenState();
}

class _CreaniaVaultHomeScreenState extends State<CreaniaVaultHomeScreen> with SingleTickerProviderStateMixin {
  late VaultController _ctrl;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _ctrl = Get.put(VaultController());
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1017),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'CREANIA VAULT',
          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 0.5),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: () => _ctrl.refreshAll(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF8B5CF6),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white38,
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(text: '🎒 Inventory'),
            Tab(text: '📜 History Logs'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildInventoryTab(),
          _buildHistoryTab(),
        ],
      ),
    );
  }

  // =========================================================================
  // 1. INVENTORY TAB
  // =========================================================================
  Widget _buildInventoryTab() {
    return Column(
      children: [
        // Search & Controls Header
        _buildControlsHeader(),
        
        // Category Pills Selector
        _buildCategoryPills(),

        // Vault items grid or list
        Expanded(
          child: Obx(() {
            if (_ctrl.isLoading.value && _ctrl.vaultItems.isEmpty) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
              );
            }

            final items = _ctrl.filteredItems;

            if (items.isEmpty) {
              return _buildEmptyState();
            }

            return RefreshIndicator(
              color: const Color(0xFF8B5CF6),
              onRefresh: () => _ctrl.refreshAll(),
              child: _ctrl.isGridView.value
                  ? GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.85,
                      ),
                      itemCount: items.length,
                      itemBuilder: (context, index) => _buildGridCard(items[index]),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: items.length,
                      itemBuilder: (context, index) => _buildListCard(items[index]),
                    ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildControlsHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          // Search input field
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: TextField(
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search digital assets...',
                  hintStyle: GoogleFonts.inter(color: Colors.white30, fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded, color: Colors.white30, size: 18),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onChanged: (val) => _ctrl.searchQuery.value = val,
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Sort dropdown
          Obx(() => Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    dropdownColor: const Color(0xFF161824),
                    value: _ctrl.sortBy.value,
                    icon: const Icon(Icons.swap_vert_rounded, color: Colors.white54, size: 18),
                    items: ['Recently Acquired', 'Rarity', 'Quantity', 'Name'].map((String val) {
                      return DropdownMenuItem<String>(
                        value: val,
                        child: Text(
                          val,
                          style: GoogleFonts.inter(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      );
                    }).toList(),
                    onChanged: (newVal) {
                      if (newVal != null) _ctrl.sortBy.value = newVal;
                    },
                  ),
                ),
              )),
          const SizedBox(width: 10),

          // Layout toggle
          Obx(() => GestureDetector(
                onTap: () => _ctrl.isGridView.value = !_ctrl.isGridView.value,
                child: Container(
                  height: 40,
                  width: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Icon(
                    _ctrl.isGridView.value ? Icons.view_list_rounded : Icons.grid_view_rounded,
                    color: Colors.white70,
                    size: 18,
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildCategoryPills() {
    return SizedBox(
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _ctrl.categories.length,
        itemBuilder: (context, index) {
          final cat = _ctrl.categories[index];
          return Obx(() {
            final isSelected = _ctrl.selectedCategory.value == cat;
            return GestureDetector(
              onTap: () => _ctrl.selectedCategory.value = cat,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF8B5CF6) : Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? const Color(0xFFA78BFA) : Colors.white.withOpacity(0.06),
                  ),
                ),
                child: Center(
                  child: Text(
                    cat,
                    style: GoogleFonts.poppins(
                      color: isSelected ? Colors.white : Colors.white60,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            );
          });
        },
      ),
    );
  }

  // Rarity styling helpers
  Color _getRarityColor(String rarity) {
    switch (rarity) {
      case 'Mythic':
        return const Color(0xFFEF4444); // Neon Red
      case 'Legendary':
        return const Color(0xFFFFD700); // Gold
      case 'Epic':
        return const Color(0xFF8B5CF6); // Purple
      case 'Rare':
        return const Color(0xFF3B82F6); // Blue
      default:
        return const Color(0xFF94A3B8); // Slate Grey
    }
  }

  Widget _buildGridCard(VaultItem item) {
    final rColor = _getRarityColor(item.rarity);
    return GestureDetector(
      onTap: () => _showItemDetailSheet(item),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.02),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: rColor.withOpacity(0.25), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: rColor.withOpacity(0.05),
              blurRadius: 8,
              spreadRadius: 0.5,
            )
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Card Content
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Thumbnail Image
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: rColor.withOpacity(0.06),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: item.thumbnailUrl != null
                            ? Image.network(
                                item.thumbnailUrl!,
                                fit: BoxFit.contain,
                                errorBuilder: (c, e, s) => Text(
                                  item.category == 'Premium' ? '👑' : '🎒',
                                  style: const TextStyle(fontSize: 22),
                                ),
                              )
                            : Text(
                                item.category == 'Premium' ? '👑' : '🎒',
                                style: const TextStyle(fontSize: 22),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Item Name
                  Text(
                    item.displayName,
                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  // Rarity tag text
                  Text(
                    item.rarity.toUpperCase(),
                    style: GoogleFonts.inter(color: rColor, fontSize: 7, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                  ),
                ],
              ),
            ),
            
            // Equipped Dot Indicator
            if (item.isEquipped)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Color(0xFF10B981), blurRadius: 4)],
                  ),
                ),
              ),

            // Quantity Stack Badge
            if (item.quantity > 1)
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white24, width: 0.5),
                  ),
                  child: Text(
                    'x${item.quantity}',
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildListCard(VaultItem item) {
    final rColor = _getRarityColor(item.rarity);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: rColor.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          // Icon Box
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: rColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: item.thumbnailUrl != null
                  ? Image.network(item.thumbnailUrl!, width: 28, height: 28, fit: BoxFit.contain)
                  : Text(item.category == 'Premium' ? '👑' : '🎒', style: const TextStyle(fontSize: 18)),
            ),
          ),
          const SizedBox(width: 14),

          // Texts
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.displayName,
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  item.shortDescription ?? 'Digital asset collected inside Creania Vault',
                  style: GoogleFonts.inter(color: Colors.white38, fontSize: 10),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Rarity & Quantity
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: rColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                child: Text(
                  item.rarity,
                  style: GoogleFonts.inter(color: rColor, fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Qty: ${item.quantity}',
                style: GoogleFonts.inter(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(width: 10),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white30, size: 14),
            onPressed: () => _showItemDetailSheet(item),
          )
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.02),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.backpack_outlined, color: Colors.white24, size: 36),
          ),
          const SizedBox(height: 16),
          Text(
            'Your Vault is Empty',
            style: GoogleFonts.poppins(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Complete progression milestones, purchase\nassets, or win lucky spins to earn items!',
            style: GoogleFonts.inter(color: Colors.white30, fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 2. DETAILED PREVIEW & ACTION SHEET
  // =========================================================================
  void _showItemDetailSheet(VaultItem item) {
    final rColor = _getRarityColor(item.rarity);
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        decoration: const BoxDecoration(
          color: Color(0xFF11131C),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: Colors.white10)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pull Bar
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white30,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Rarity Badge tag
              Container(
                decoration: BoxDecoration(
                  color: rColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: rColor.withOpacity(0.4)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: Text(
                  item.rarity.toUpperCase(),
                  style: GoogleFonts.inter(color: rColor, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                ),
              ),
              const SizedBox(height: 12),

              // Title
              Text(
                item.displayName,
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Preview Section (Frames/Bubbles gets a custom visual preview mock!)
              _buildLivePreviewWidget(item),
              const SizedBox(height: 20),

              // Description Info
              Text(
                item.longDescription ?? item.shortDescription ?? 'This digital item is collected inside Creania Vault. You can equip, activate, or gift this asset directly from the backend settings.',
                style: GoogleFonts.inter(color: Colors.white70, fontSize: 12, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Stats Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _detailStat('Quantity', '${item.quantity}'),
                  _detailStat('Stackable', item.stackable ? 'Yes' : 'No'),
                  _detailStat('Duration', item.permanent ? 'Permanent' : 'Rental'),
                ],
              ),
              const SizedBox(height: 24),

              // Expiry countdown if applicable
              if (!item.permanent && item.expiresAt != null) ...[
                Text(
                  'EXPIRES AT: ${item.expiresAt!.toLocal().toString().substring(0, 16)}',
                  style: GoogleFonts.inter(color: Colors.orangeAccent, fontSize: 11, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
              ],

              // Actions Rows
              Row(
                children: [
                  // Activate / Equip Button
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: item.isEquipped ? Colors.redAccent : const Color(0xFF8B5CF6),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        Get.back();
                        final res = await _ctrl.activateOrEquipItem(item);
                        if (res['success'] == true) {
                          Get.snackbar(
                            'Action Complete! 🎉',
                            res['benefit'] ?? 'Your Vault asset was successfully updated.',
                            backgroundColor: const Color(0xFF10B981).withOpacity(0.8),
                            colorText: Colors.white,
                          );
                        } else {
                          Get.snackbar(
                            'Action Failed',
                            res['reason'] ?? 'Failed to activate vault item.',
                            backgroundColor: Colors.redAccent.withOpacity(0.8),
                            colorText: Colors.white,
                          );
                        }
                      },
                      child: Text(
                        item.category == 'Cosmetics' || item.category == 'Effects'
                            ? (item.isEquipped ? 'Unequip' : 'Equip Asset')
                            : 'Activate Voucher',
                        style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ),

                  // Gift Button if applicable
                  if (item.giftable) ...[
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.05),
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Colors.white10),
                        ),
                      ),
                      onPressed: () {
                        Get.back();
                        _showGiftingDialog(item);
                      },
                      child: const Icon(Icons.card_giftcard_rounded, color: Color(0xFFFFDB3C)),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  Widget _detailStat(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.inter(color: Colors.white30, fontSize: 10, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildLivePreviewWidget(VaultItem item) {
    // If avatar frame, show mock avatar with frame
    if (item.subCategory == 'avatar_frame' && item.previewUrl != null) {
      return Container(
        width: 120,
        height: 120,
        alignment: Alignment.center,
        child: Stack(
          alignment: Alignment.center,
          children: [
            const CircleAvatar(
              radius: 44,
              backgroundImage: NetworkImage('https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150'),
            ),
            Image.network(
              item.previewUrl!,
              width: 112,
              height: 112,
              fit: BoxFit.cover,
              errorBuilder: (c, e, s) => const SizedBox.shrink(),
            ),
          ],
        ),
      );
    }

    // If chat bubble, show bubble preview
    if (item.subCategory == 'chat_bubble') {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.02),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.04)),
        ),
        child: Column(
          children: [
            Text('CHAT BUBBLE PREVIEW', style: GoogleFonts.inter(color: Colors.white24, fontSize: 8, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.3)),
              ),
              child: Text(
                'Hello! Check out my premium bubble! 🚀',
                style: GoogleFonts.inter(color: Colors.white, fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }

    // Default icon preview
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Center(
        child: item.thumbnailUrl != null
            ? Image.network(item.thumbnailUrl!, width: 56, height: 56, fit: BoxFit.contain)
            : Text(item.category == 'Premium' ? '👑' : '🎒', style: const TextStyle(fontSize: 36)),
      ),
    );
  }

  // Gifting Dialog
  void _showGiftingDialog(VaultItem item) {
    final TextEditingController receiverCtrl = TextEditingController();
    Get.dialog(
      BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          backgroundColor: const Color(0xFF161824),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.white10)),
          title: Text(
            'Gift Asset 🎁',
            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter the receiver UUID key below. The asset will be deducted from your inventory and added to their vault.',
                style: GoogleFonts.inter(color: Colors.white54, fontSize: 11, height: 1.4),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: TextField(
                  controller: receiverCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Receiver UUID...',
                    hintStyle: GoogleFonts.inter(color: Colors.white24, fontSize: 13),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.white38)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6)),
              onPressed: () async {
                final recId = receiverCtrl.text.trim();
                if (recId.isEmpty) return;
                Get.back();
                final res = await _ctrl.giftItem(item, recId);
                if (res['success'] == true) {
                  Get.snackbar(
                    'Gift Sent! 🎁',
                    'Your asset was successfully sent to the recipient.',
                    backgroundColor: const Color(0xFF10B981).withOpacity(0.8),
                    colorText: Colors.white,
                  );
                } else {
                  Get.snackbar(
                    'Gift Failed',
                    res['reason'] ?? 'Could not transfer asset.',
                    backgroundColor: Colors.redAccent.withOpacity(0.8),
                    colorText: Colors.white,
                  );
                }
              },
              child: Text('Send Gift', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // 3. HISTORY LOGS TAB
  // =========================================================================
  Widget _buildHistoryTab() {
    return Obx(() {
      if (_ctrl.isHistoryLoading.value && _ctrl.historyEntries.isEmpty) {
        return const Center(
          child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
        );
      }

      final logs = _ctrl.historyEntries;

      if (logs.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.history_edu_rounded, color: Colors.white24, size: 36),
              const SizedBox(height: 12),
              Text(
                'No Transaction History',
                style: GoogleFonts.poppins(color: Colors.white38, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        );
      }

      return RefreshIndicator(
        color: const Color(0xFF8B5CF6),
        onRefresh: () => _ctrl.fetchVaultHistory(),
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: logs.length,
          itemBuilder: (context, index) {
            final entry = logs[index];
            final Color rColor = _getRarityColor(entry.rarity);
            
            IconData actionIcon = Icons.info_outline;
            Color actionColor = Colors.grey;

            switch (entry.actionType) {
              case 'Received':
                actionIcon = Icons.add_circle_outline_rounded;
                actionColor = const Color(0xFF10B981);
                break;
              case 'Activated':
              case 'Equipped':
                actionIcon = Icons.check_circle_outline_rounded;
                actionColor = const Color(0xFF8B5CF6);
                break;
              case 'Unequipped':
                actionIcon = Icons.remove_circle_outline_rounded;
                actionColor = Colors.white54;
                break;
              case 'Expired':
                actionIcon = Icons.hourglass_empty_rounded;
                actionColor = Colors.orangeAccent;
                break;
              case 'Consumed':
                actionIcon = Icons.local_fire_department_rounded;
                actionColor = Colors.amber;
                break;
              case 'Gifted':
                actionIcon = Icons.card_giftcard_rounded;
                actionColor = const Color(0xFFFFDB3C);
                break;
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.01),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.03)),
              ),
              child: Row(
                children: [
                  // Action Icon
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: actionColor.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(actionIcon, color: actionColor, size: 16),
                  ),
                  const SizedBox(width: 12),

                  // Texts
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          text: TextSpan(
                            text: '${entry.actionType} ',
                            style: GoogleFonts.inter(color: actionColor, fontSize: 12, fontWeight: FontWeight.bold),
                            children: [
                              TextSpan(
                                text: entry.assetName,
                                style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
                              )
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          entry.createdAt.toLocal().toString().substring(0, 16),
                          style: GoogleFonts.inter(color: Colors.white38, fontSize: 9),
                        ),
                      ],
                    ),
                  ),

                  // Quantity
                  Text(
                    'x${entry.quantity}',
                    style: GoogleFonts.inter(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            );
          },
        ),
      );
    });
  }
}

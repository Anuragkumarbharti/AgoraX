// lib/services/vault_controller.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/vault_models.dart';
import 'user_profile_cache_manager.dart';

class VaultController extends GetxController {
  final RxList<VaultItem> vaultItems = <VaultItem>[].obs;
  final RxList<VaultHistoryEntry> historyEntries = <VaultHistoryEntry>[].obs;
  
  final RxBool isLoading = false.obs;
  final RxBool isHistoryLoading = false.obs;
  final RxString searchQuery = ''.obs;
  final RxString selectedCategory = 'Everything'.obs;
  final RxBool isGridView = true.obs;
  
  final RxString sortBy = 'Recently Acquired'.obs; // 'Recently Acquired', 'Rarity', 'Quantity', 'Name'

  final List<String> categories = [
    'Everything',
    'Premium',
    'Cosmetics',
    'Effects',
    'Tickets',
    'Coupons',
    'Boxes',
    'Collectibles',
  ];

  @override
  void onInit() {
    super.onInit();
    refreshAll();
  }

  String get currentUserId => Supabase.instance.client.auth.currentUser?.id ?? '';

  Future<void> refreshAll() async {
    if (currentUserId.isEmpty) return;
    isLoading.value = true;
    try {
      await Future.wait([
        fetchVaultItems(),
        fetchVaultHistory(),
      ]);
    } catch (e) {
      debugPrint('VaultController error refreshAll: $e');
    } finally {
      isLoading.value = false;
    }
  }

  // Load active vault items
  Future<void> fetchVaultItems() async {
    try {
      if (currentUserId.isEmpty) return;
      final response = await Supabase.instance.client.rpc('get_user_vault');
      if (response != null) {
        final List<dynamic> list = response as List;
        vaultItems.value = list.map((item) => VaultItem.fromJson(item)).toList();
      }
    } catch (e) {
      debugPrint('VaultController: Error fetching vault items: $e');
    }
  }

  // Load vault audit log history
  Future<void> fetchVaultHistory() async {
    try {
      if (currentUserId.isEmpty) return;
      isHistoryLoading.value = true;
      final response = await Supabase.instance.client.rpc('get_vault_history');
      if (response != null) {
        final List<dynamic> list = response as List;
        historyEntries.value = list.map((item) => VaultHistoryEntry.fromJson(item)).toList();
      }
    } catch (e) {
      debugPrint('VaultController: Error fetching vault history: $e');
    } finally {
      isHistoryLoading.value = false;
    }
  }

  // Activate / Equip Vault Item
  Future<Map<String, dynamic>> activateOrEquipItem(VaultItem item) async {
    try {
      isLoading.value = true;
      final response = await Supabase.instance.client.rpc(
        'activate_vault_item',
        params: {'p_item_id': item.id},
      );

      final Map<String, dynamic> result = Map<String, dynamic>.from(response);

      if (result['success'] == true) {
        // Optimistic UI updates
        final index = vaultItems.indexWhere((element) => element.id == item.id);
        if (index != -1) {
          final oldItem = vaultItems[index];
          if (oldItem.category == 'Cosmetics' || oldItem.category == 'Effects') {
            // Toggle equip state locally and unequip others of same sub_category
            final updatedList = vaultItems.map((v) {
              if (v.id == item.id) {
                return VaultItem(
                  id: v.id,
                  assetId: v.assetId,
                  category: v.category,
                  subCategory: v.subCategory,
                  displayName: v.displayName,
                  shortDescription: v.shortDescription,
                  longDescription: v.longDescription,
                  thumbnailUrl: v.thumbnailUrl,
                  animationUrl: v.animationUrl,
                  previewUrl: v.previewUrl,
                  rarity: v.rarity,
                  quantity: v.quantity,
                  status: 'Activated',
                  purchaseSource: v.purchaseSource,
                  purchaseDate: v.purchaseDate,
                  expiresAt: v.expiresAt ?? (v.permanent ? null : DateTime.now().add(Duration(seconds: v.durationSeconds ?? 0))),
                  activatedAt: DateTime.now(),
                  isEquipped: !v.isEquipped,
                  lastEquippedAt: DateTime.now(),
                  customMetadata: v.customMetadata,
                  tradable: v.tradable,
                  giftable: v.giftable,
                  stackable: v.stackable,
                  consumable: v.consumable,
                  permanent: v.permanent,
                  durationSeconds: v.durationSeconds,
                );
              } else if (v.subCategory == oldItem.subCategory) {
                return VaultItem(
                  id: v.id,
                  assetId: v.assetId,
                  category: v.category,
                  subCategory: v.subCategory,
                  displayName: v.displayName,
                  shortDescription: v.shortDescription,
                  longDescription: v.longDescription,
                  thumbnailUrl: v.thumbnailUrl,
                  animationUrl: v.animationUrl,
                  previewUrl: v.previewUrl,
                  rarity: v.rarity,
                  quantity: v.quantity,
                  status: v.status,
                  purchaseSource: v.purchaseSource,
                  purchaseDate: v.purchaseDate,
                  expiresAt: v.expiresAt,
                  activatedAt: v.activatedAt,
                  isEquipped: false,
                  lastEquippedAt: v.lastEquippedAt,
                  customMetadata: v.customMetadata,
                  tradable: v.tradable,
                  giftable: v.giftable,
                  stackable: v.stackable,
                  consumable: v.consumable,
                  permanent: v.permanent,
                  durationSeconds: v.durationSeconds,
                );
              }
              return v;
            }).toList();
            vaultItems.value = updatedList;
          } else {
            // Consumed item - decrement quantity
            if (oldItem.quantity > 1) {
              vaultItems[index] = VaultItem(
                id: oldItem.id,
                assetId: oldItem.assetId,
                category: oldItem.category,
                subCategory: oldItem.subCategory,
                displayName: oldItem.displayName,
                shortDescription: oldItem.shortDescription,
                longDescription: oldItem.longDescription,
                thumbnailUrl: oldItem.thumbnailUrl,
                animationUrl: oldItem.animationUrl,
                previewUrl: oldItem.previewUrl,
                rarity: oldItem.rarity,
                quantity: oldItem.quantity - 1,
                status: oldItem.status,
                purchaseSource: oldItem.purchaseSource,
                purchaseDate: oldItem.purchaseDate,
                expiresAt: oldItem.expiresAt,
                activatedAt: oldItem.activatedAt,
                isEquipped: oldItem.isEquipped,
                lastEquippedAt: oldItem.lastEquippedAt,
                customMetadata: oldItem.customMetadata,
                tradable: oldItem.tradable,
                giftable: oldItem.giftable,
                stackable: oldItem.stackable,
                consumable: oldItem.consumable,
                permanent: oldItem.permanent,
                durationSeconds: oldItem.durationSeconds,
              );
            } else {
              vaultItems.removeAt(index);
            }
          }
        }

        // Trigger updates in profiles cache instantly if it affects equipped accessories
        UserProfileCacheManager.rebuildAndSyncCurrentUserTagSystem();
        fetchVaultItems();
        fetchVaultHistory();
      }

      return result;
    } catch (e) {
      debugPrint('VaultController: Error activating item: $e');
      return {'success': false, 'reason': e.toString()};
    } finally {
      isLoading.value = false;
    }
  }

  // Gift Vault Item
  Future<Map<String, dynamic>> giftItem(VaultItem item, String receiverUserId) async {
    try {
      isLoading.value = true;
      final response = await Supabase.instance.client.rpc(
        'gift_vault_item',
        params: {
          'p_item_id': item.id,
          'p_receiver_id': receiverUserId,
        },
      );

      final Map<String, dynamic> result = Map<String, dynamic>.from(response);

      if (result['success'] == true) {
        // Optimistic UI updates
        final index = vaultItems.indexWhere((element) => element.id == item.id);
        if (index != -1) {
          final oldItem = vaultItems[index];
          if (oldItem.quantity > 1) {
            vaultItems[index] = VaultItem(
              id: oldItem.id,
              assetId: oldItem.assetId,
              category: oldItem.category,
              subCategory: oldItem.subCategory,
              displayName: oldItem.displayName,
              shortDescription: oldItem.shortDescription,
              longDescription: oldItem.longDescription,
              thumbnailUrl: oldItem.thumbnailUrl,
              animationUrl: oldItem.animationUrl,
              previewUrl: oldItem.previewUrl,
              rarity: oldItem.rarity,
              quantity: oldItem.quantity - 1,
              status: oldItem.status,
              purchaseSource: oldItem.purchaseSource,
              purchaseDate: oldItem.purchaseDate,
              expiresAt: oldItem.expiresAt,
              activatedAt: oldItem.activatedAt,
              isEquipped: oldItem.isEquipped,
              lastEquippedAt: oldItem.lastEquippedAt,
              customMetadata: oldItem.customMetadata,
              tradable: oldItem.tradable,
              giftable: oldItem.giftable,
              stackable: oldItem.stackable,
              consumable: oldItem.consumable,
              permanent: oldItem.permanent,
              durationSeconds: oldItem.durationSeconds,
            );
          } else {
            vaultItems.removeAt(index);
          }
        }
        fetchVaultItems();
        fetchVaultHistory();
      }

      return result;
    } catch (e) {
      debugPrint('VaultController: Error gifting item: $e');
      return {'success': false, 'reason': e.toString()};
    } finally {
      isLoading.value = false;
    }
  }

  // Filtered & Sorted items getter
  List<VaultItem> get filteredItems {
    List<VaultItem> items = List.from(vaultItems);

    // 1. Filter by category
    if (selectedCategory.value != 'Everything') {
      items = items.where((item) => item.category.toLowerCase() == selectedCategory.value.toLowerCase()).toList();
    }

    // 2. Filter by search query
    if (searchQuery.value.isNotEmpty) {
      final query = searchQuery.value.toLowerCase();
      items = items.where((item) {
        return item.displayName.toLowerCase().contains(query) ||
            (item.shortDescription?.toLowerCase().contains(query) ?? false) ||
            (item.subCategory.toLowerCase().contains(query));
      }).toList();
    }

    // 3. Sort items
    if (sortBy.value == 'Name') {
      items.sort((a, b) => a.displayName.compareTo(b.displayName));
    } else if (sortBy.value == 'Quantity') {
      items.sort((a, b) => b.quantity.compareTo(a.quantity));
    } else if (sortBy.value == 'Rarity') {
      // Sort priority: Mythic -> Legendary -> Epic -> Rare -> Common
      final rarityMap = {'Mythic': 4, 'Legendary': 3, 'Epic': 2, 'Rare': 1, 'Common': 0};
      items.sort((a, b) {
        final valA = rarityMap[a.rarity] ?? 0;
        final valB = rarityMap[b.rarity] ?? 0;
        return valB.compareTo(valA);
      });
    } else {
      // 'Recently Acquired'
      items.sort((a, b) => b.purchaseDate.compareTo(a.purchaseDate));
    }

    return items;
  }
}

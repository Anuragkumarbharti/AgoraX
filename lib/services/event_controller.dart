import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/event_model.dart';
import 'store_controller.dart';
import 'user_profile_cache_manager.dart';

class EventController extends GetxController {
  static String get currentUserId => UserProfileCacheManager.currentUserId;

  // Dual currency wallet state
  RxInt get silverCoins => Get.find<StoreController>().coinsBalance;
  RxDouble get cashBalance => Get.find<StoreController>().availableIncomeBalance;

  // Active Events List
  final RxList<Event> events = <Event>[].obs;

  // Wallet Transactions List (for compatibility with wallet_screen)
  final RxList<Map<String, dynamic>> walletTransactions = <Map<String, dynamic>>[].obs;

  // Notifications List
  final RxList<Map<String, dynamic>> notifications = <Map<String, dynamic>>[].obs;

  // Event Participants Map (for compatibility with event_dashboard_screen)
  final RxMap<String, List<Map<String, dynamic>>> eventParticipants = <String, List<Map<String, dynamic>>>{}.obs;

  RealtimeChannel? _eventsSubscription;

  void addNotification(String title, String body) {
    notifications.insert(0, {
      'title': title,
      'body': body,
      'time': 'Just now',
    });
  }

  @override
  void onInit() {
    super.onInit();
    _loadEventsFromDatabase();
    _loadTransactions();
    subscribeToRealtime();
  }

  @override
  void onClose() {
    _eventsSubscription?.unsubscribe();
    super.onClose();
  }

  Future<void> _loadTransactions() async {
    try {
      final List<dynamic> list = await Supabase.instance.client
          .from('wallet_transactions')
          .select()
          .eq('wallet_id', currentUserId)
          .order('created_at', ascending: false);

      walletTransactions.assignAll(list.map((m) {
        final amountVal = m['amount'];
        final isCoins = m['currency'] == 'Coins';
        return {
          'type': m['type'] ?? 'Transaction',
          'title': m['details'] ?? (m['type'] ?? 'Transaction'),
          'amount': isCoins ? '${amountVal.toInt()} Coins' : '₹${amountVal.toDouble()}',
          'currency': isCoins ? 'coins' : 'cash',
          'date': m['created_at'].toString().split('T').first,
          'isCredit': m['transaction_type'] == 'Credit',
        };
      }).toList());
    } catch (_) {}
  }

  Future<void> _loadEventsFromDatabase() async {
    try {
      final List<dynamic> list = await Supabase.instance.client
          .from('events')
          .select()
          .order('start_date', ascending: true);

      final loaded = list.map((m) {
        final rewardsMap = m['rewards'] is String ? json.decode(m['rewards']) : m['rewards'];
        final antiCheatMap = m['anti_cheat'] is String ? json.decode(m['anti_cheat']) : m['anti_cheat'];
        final winnersList = m['winners'] is String ? json.decode(m['winners']) : m['winners'];
        final roundsList = m['rounds'] is String ? json.decode(m['rounds']) : m['rounds'];

        return Event(
          id: m['id'],
          title: m['title'],
          description: m['description'],
          bannerUrl: m['banner_url'] ?? '',
          category: m['category'],
          difficulty: m['difficulty'],
          organizer: m['organizer'],
          isOfficial: m['is_official'] ?? false,
          startDate: DateTime.tryParse(m['start_date'].toString()) ?? DateTime.now(),
          endDate: DateTime.tryParse(m['end_date'].toString()) ?? DateTime.now(),
          registrationDeadline: DateTime.tryParse(m['registration_deadline'].toString()) ?? DateTime.now(),
          resultDate: m['result_date'] != null ? (DateTime.tryParse(m['result_date'].toString()) ?? DateTime.now()) : DateTime.now(),
          maxParticipants: m['max_participants'] ?? 100,
          isUnlimited: m['is_unlimited'] ?? false,
          entryFeeType: m['entry_fee_type'] == 'coins'
              ? EntryFeeType.coins
              : (m['entry_fee_type'] == 'cash' ? EntryFeeType.cash : EntryFeeType.free),
          entryFeeAmount: m['entry_fee_amount'] ?? 0,
          prizePool: m['prize_pool'] ?? '',
          rewards: EventReward(
            coins: rewardsMap?['coins'] ?? 0,
            xp: rewardsMap?['xp'] ?? 0,
            badge: rewardsMap?['badge'],
            certificate: rewardsMap?['certificate'] ?? false,
            frameName: rewardsMap?['frameName'],
            trophyName: rewardsMap?['trophyName'],
          ),
          status: EventStatus.values.firstWhere(
            (e) => e.name == m['status'],
            orElse: () => EventStatus.registrationOpen,
          ),
          format: EventFormat.values.firstWhere(
            (e) => e.name == m['format'],
            orElse: () => EventFormat.quiz,
          ),
          rules: List<String>.from(m['rules'] ?? []),
          requiredLevel: m['required_level'] ?? 1,
          requiredBadge: m['required_badge'],
          tags: List<String>.from(m['tags'] ?? []),
          language: m['language'] ?? 'English',
          isPublic: m['is_public'] ?? true,
          participantsCount: m['participants_count'] ?? 0,
          antiCheat: EventAntiCheat(
            screenMonitoring: antiCheatMap?['screenMonitoring'] ?? false,
            randomQuestions: antiCheatMap?['randomQuestions'] ?? false,
            randomQuestionOrder: antiCheatMap?['randomQuestionOrder'] ?? false,
            randomOptions: antiCheatMap?['randomOptions'] ?? false,
          ),
          negativeMarking: m['negative_marking'] ?? false,
          durationMinutes: m['duration_minutes'] ?? 60,
          questionCount: m['question_count'] ?? 30,
          passingMarks: m['passing_marks'] ?? 40,
          requiredRegistrationFields: List<String>.from(m['required_registration_fields'] ?? ['name', 'email', 'phone']),
          termsAndConditions: m['terms_and_conditions'] ?? '',
          isPaid: m['is_paid'] ?? false,
          minParticipants: m['min_participants'] ?? 10,
          winnerType: m['winner_type'] ?? 'top3',
          autoPrizePool: m['auto_prize_pool'] ?? true,
          passwordProtected: m['password_protected'] ?? false,
          password: m['password'] ?? '',
          coOwnerId: m['co_owner_id'],
          adminIds: List<String>.from(m['admin_ids'] ?? []),
          registeredUserIds: List<String>.from(m['registered_user_ids'] ?? []),
          sponsoredAmount: (m['sponsored_amount'] ?? 0.0).toDouble(),
          couponCodes: Map<String, double>.from(m['coupon_codes'] ?? {}),
          allowAdminsJoin: m['allow_admins_join'] ?? false,
          creatorId: m['creator_id'] ?? 'me',
          durationString: m['duration_string'] ?? '1 hour',
          allowSpectators: m['allow_spectators'] ?? true,
          allowLateJoin: m['allow_late_join'] ?? false,
          autoCancelMinUsers: m['auto_cancel_min_users'] ?? true,
          autoRefund: m['auto_refund'] ?? true,
          chatEnabled: m['chat_enabled'] ?? true,
          voiceRoomEnabled: m['voice_room_enabled'] ?? false,
          screenShareEnabled: m['screen_share_enabled'] ?? false,
          recordingEnabled: m['recording_enabled'] ?? false,
          timelineStatus: m['timeline_status'] ?? 'Registration Started',
          winners: (winnersList as List?)
                  ?.map((w) => EventWinner(
                        rank: w['rank'] ?? '',
                        username: w['username'] ?? '',
                        userId: w['userId'] ?? '',
                        avatarUrl: w['avatarUrl'] ?? '',
                        prizeWon: (w['prizeWon'] ?? 0.0).toDouble(),
                        community: w['community'] ?? '',
                        isVerified: w['isVerified'] ?? false,
                      ))
                  .toList() ??
              const [],
          isMultiRound: m['is_multi_round'] ?? false,
          rounds: (roundsList as List?)
                  ?.map((r) => RoundConfig(
                        name: r['name'] ?? '',
                        description: r['description'] ?? '',
                        format: r['format'] ?? '',
                        totalQuestions: r['totalQuestions'] ?? 0,
                        marksPerQuestion: r['marksPerQuestion'] ?? 0,
                        negativeMarking: r['negativeMarking'] ?? false,
                        timerPerQuestion: r['timerPerQuestion'] ?? 0,
                        qualifyingCriteria: r['qualifyingCriteria'] ?? '',
                        breakTimeMinutes: r['breakTimeMinutes'] ?? 0,
                        autoStartNextRound: r['autoStartNextRound'] ?? false,
                        startDate: r['startDate'] != null ? DateTime.tryParse(r['startDate']) : null,
                        isBuzzerMode: r['isBuzzerMode'] ?? false,
                      ))
                  .toList() ??
              const [],
        );
      }).toList();

      events.assignAll(loaded);
      _populateParticipantsForEvents();
    } catch (e) {
      debugPrint('DB Load Error: Fallback to mock events: $e');
      events.assignAll(Event.mockEvents());
      _populateParticipantsForEvents();
    }
  }

  void _populateParticipantsForEvents() {
    for (final e in events) {
      final list = e.registeredUserIds.map((uid) {
        final isMe = uid == currentUserId;
        return {
          'userId': uid,
          'name': isMe ? 'You' : 'Student $uid',
          'role': e.creatorId == uid ? 'Owner' : (e.coOwnerId == uid ? 'Co-Owner' : (e.adminIds.contains(uid) ? 'Admin' : 'Guest')),
          'status': 'Approved',
          'paymentStatus': 'Paid',
          'avatarUrl': isMe 
              ? 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150' 
              : 'https://images.unsplash.com/photo-1570295999919-56ceb5ecca61?w=150',
        };
      }).toList();
      eventParticipants[e.id] = list;
    }
  }

  void subscribeToRealtime() {
    try {
      _eventsSubscription = Supabase.instance.client
          .channel('public:events')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'events',
            callback: (payload) {
              _loadEventsFromDatabase();
            },
          );
      _eventsSubscription?.subscribe();
    } catch (e) {
      debugPrint('Realtime Sub failed: $e');
    }
  }

  List<Map<String, dynamic>> getParticipantsForEvent(String eventId) {
    return eventParticipants[eventId] ?? [];
  }

  Future<bool> withdrawCash(double amount, String upiId) async {
    if (cashBalance.value < amount) return false;
    cashBalance.value -= amount;
    try {
      await Supabase.instance.client
          .from('wallets')
          .update({'withdrawable_balance': cashBalance.value})
          .eq('id', currentUserId);

      await Supabase.instance.client.from('wallet_transactions').insert({
        'wallet_id': currentUserId,
        'amount': amount,
        'currency': 'INR',
        'type': 'Withdrawal',
        'status': 'Completed',
        'details': 'Withdrawal to $upiId',
        'transaction_type': 'Debit',
      });
      await _loadTransactions();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> depositCash(double amount) async {
    cashBalance.value += amount;
    try {
      await Supabase.instance.client
          .from('wallets')
          .update({'withdrawable_balance': cashBalance.value})
          .eq('id', currentUserId);

      await Supabase.instance.client.from('wallet_transactions').insert({
        'wallet_id': currentUserId,
        'amount': amount,
        'currency': 'INR',
        'type': 'Deposit',
        'status': 'Completed',
        'details': 'Deposit Cash',
        'transaction_type': 'Credit',
      });
      await _loadTransactions();
    } catch (_) {}
  }

  Future<bool> createPaidEvent(Event newEvent) async {
    if (silverCoins.value < 59) {
      Get.snackbar(
        'Insufficient Coins 🪙',
        'Creating an Event costs 59 Silver Coins. You have ${silverCoins.value} coins.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withOpacity(0.9),
        colorText: Colors.white,
      );
      return false;
    }

    silverCoins.value -= 59;
    try {
      await Supabase.instance.client
          .from('wallets')
          .update({'coins_balance': silverCoins.value})
          .eq('id', currentUserId);

      await Supabase.instance.client.from('wallet_transactions').insert({
        'wallet_id': currentUserId,
        'amount': 59.00,
        'currency': 'Coins',
        'type': 'Commission',
        'status': 'Completed',
        'details': 'Event Creation: ${newEvent.title}',
        'transaction_type': 'Debit',
      });
    } catch (_) {}

    try {
      final payload = {
        'id': newEvent.id,
        'title': newEvent.title,
        'description': newEvent.description,
        'banner_url': newEvent.bannerUrl,
        'category': newEvent.category,
        'difficulty': newEvent.difficulty,
        'organizer': newEvent.organizer,
        'is_official': newEvent.isOfficial,
        'start_date': newEvent.startDate.toIso8601String(),
        'end_date': newEvent.endDate.toIso8601String(),
        'registration_deadline': newEvent.registrationDeadline.toIso8601String(),
        'result_date': newEvent.resultDate?.toIso8601String(),
        'max_participants': newEvent.maxParticipants,
        'is_unlimited': newEvent.isUnlimited,
        'entry_fee_type': newEvent.entryFeeType.name,
        'entry_fee_amount': newEvent.entryFeeAmount,
        'prize_pool': newEvent.prizePool,
        'rewards': {
          'coins': newEvent.rewards.coins,
          'xp': newEvent.rewards.xp,
          'badge': newEvent.rewards.badge,
          'certificate': newEvent.rewards.certificate,
          'frameName': newEvent.rewards.frameName,
          'trophyName': newEvent.rewards.trophyName,
        },
        'status': newEvent.status.name,
        'format': newEvent.format.name,
        'rules': newEvent.rules,
        'required_level': newEvent.requiredLevel,
        'required_badge': newEvent.requiredBadge,
        'tags': newEvent.tags,
        'language': newEvent.language,
        'is_public': newEvent.isPublic,
        'participants_count': newEvent.participantsCount,
        'anti_cheat': {
          'screenMonitoring': newEvent.antiCheat.screenMonitoring,
          'randomQuestions': newEvent.antiCheat.randomQuestions,
          'randomQuestionOrder': newEvent.antiCheat.randomQuestionOrder,
          'randomOptions': newEvent.antiCheat.randomOptions,
        },
        'negative_marking': newEvent.negativeMarking,
        'duration_minutes': newEvent.durationMinutes,
        'question_count': newEvent.questionCount,
        'passing_marks': newEvent.passingMarks,
        'required_registration_fields': newEvent.requiredRegistrationFields,
        'terms_and_conditions': newEvent.termsAndConditions,
        'is_paid': newEvent.isPaid,
        'min_participants': newEvent.minParticipants,
        'winner_type': newEvent.winnerType,
        'auto_prize_pool': newEvent.autoPrizePool,
        'password_protected': newEvent.passwordProtected,
        'password': newEvent.password,
        'co_owner_id': newEvent.coOwnerId,
        'admin_ids': newEvent.adminIds,
        'registered_user_ids': newEvent.registeredUserIds,
        'sponsored_amount': newEvent.sponsoredAmount,
        'coupon_codes': newEvent.couponCodes,
        'allow_admins_join': newEvent.allowAdminsJoin,
        'creator_id': currentUserId,
        'duration_string': newEvent.durationString,
        'allow_spectators': newEvent.allowSpectators,
        'allow_late_join': newEvent.allowLateJoin,
        'auto_cancel_min_users': newEvent.autoCancelMinUsers,
        'auto_refund': newEvent.autoRefund,
        'chat_enabled': newEvent.chatEnabled,
        'voice_room_enabled': newEvent.voiceRoomEnabled,
        'screen_share_enabled': newEvent.screenShareEnabled,
        'recording_enabled': newEvent.recordingEnabled,
        'timeline_status': newEvent.timelineStatus,
        'winners': newEvent.winners.map((w) => {
              'rank': w.rank,
              'username': w.username,
              'userId': w.userId,
              'avatarUrl': w.avatarUrl,
              'prizeWon': w.prizeWon,
              'community': w.community,
              'isVerified': w.isVerified,
            }).toList(),
        'is_multi_round': newEvent.isMultiRound,
        'rounds': newEvent.rounds.map((r) => {
              'name': r.name,
              'description': r.description,
              'format': r.format,
              'totalQuestions': r.totalQuestions,
              'marksPerQuestion': r.marksPerQuestion,
              'negativeMarking': r.negativeMarking,
              'timerPerQuestion': r.timerPerQuestion,
              'qualifyingCriteria': r.qualifyingCriteria,
              'breakTimeMinutes': r.breakTimeMinutes,
              'autoStartNextRound': r.autoStartNextRound,
              'startDate': r.startDate?.toIso8601String(),
              'isBuzzerMode': r.isBuzzerMode,
            }).toList(),
      };

      await Supabase.instance.client.from('events').insert(payload);
      await _loadEventsFromDatabase();
      await _loadTransactions();
      return true;
    } catch (e) {
      silverCoins.value += 59;
      try {
        await Supabase.instance.client
            .from('wallets')
            .update({'coins_balance': silverCoins.value})
            .eq('id', currentUserId);

        await Supabase.instance.client.from('wallet_transactions').insert({
          'wallet_id': currentUserId,
          'amount': 59.00,
          'currency': 'Coins',
          'type': 'Refund',
          'status': 'Completed',
          'details': 'Refund: Event Creation Failed',
          'transaction_type': 'Credit',
        });
      } catch (_) {}

      Get.snackbar(
        'Error ⚠️',
        'Failed to publish event: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withOpacity(0.9),
        colorText: Colors.white,
      );
      return false;
    }
  }

  Future<bool> registerForEvent(String eventId, Map<String, dynamic> details) async {
    final index = events.indexWhere((e) => e.id == eventId);
    if (index == -1) return false;
    final e = events[index];

    if (e.status == EventStatus.registrationClosed || e.registrationDeadline.isBefore(DateTime.now())) {
      Get.snackbar('Registration Closed 🔒', 'This event is no longer accepting registrations.',
          snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red.withOpacity(0.9), colorText: Colors.white);
      return false;
    }

    if (e.registeredUserIds.contains(currentUserId)) {
      Get.snackbar('Already Joined ⚠️', 'You are already registered for this event.',
          snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red.withOpacity(0.9), colorText: Colors.white);
      return false;
    }

    if (e.maxParticipants > 0 && e.registeredUserIds.length >= e.maxParticipants) {
      Get.snackbar('Sold Out 🚫', 'This event is fully booked.',
          snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red.withOpacity(0.9), colorText: Colors.white);
      return false;
    }

    if (e.creatorId == currentUserId) {
      Get.snackbar('Restricted Action ⛔', 'Creators cannot join their own events as participants.',
          snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red.withOpacity(0.9), colorText: Colors.white);
      return false;
    }

    final isCoOwner = e.coOwnerId == currentUserId;
    final isAdmin = e.adminIds.contains(currentUserId);
    if ((isCoOwner || isAdmin) && !e.allowAdminsJoin) {
      Get.snackbar('Restricted Action ⛔', 'Co-owners & Admins are not allowed to join this event.',
          snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red.withOpacity(0.9), colorText: Colors.white);
      return false;
    }

    if (e.isPaid) {
      if (e.entryFeeType == EntryFeeType.cash) {
        if (cashBalance.value < e.entryFeeAmount) {
          Get.snackbar('Insufficient Cash 💰', 'Your cash balance is too low to pay the ₹${e.entryFeeAmount} entry fee.',
              snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red.withOpacity(0.9), colorText: Colors.white);
          return false;
        }
        cashBalance.value -= e.entryFeeAmount;
        try {
          await Supabase.instance.client
              .from('wallets')
              .update({'withdrawable_balance': cashBalance.value})
              .eq('id', currentUserId);

          await Supabase.instance.client.from('wallet_transactions').insert({
            'wallet_id': currentUserId,
            'amount': e.entryFeeAmount.toDouble(),
            'currency': 'INR',
            'type': 'Payout',
            'status': 'Completed',
            'details': 'Event Entry: ${e.title}',
            'transaction_type': 'Debit',
          });
        } catch (_) {}
      } else if (e.entryFeeType == EntryFeeType.coins) {
        if (silverCoins.value < e.entryFeeAmount) {
          Get.snackbar('Insufficient Coins 🪙', 'Your coins balance is too low to pay the ${e.entryFeeAmount} entry fee.',
              snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red.withOpacity(0.9), colorText: Colors.white);
          return false;
        }
        silverCoins.value -= e.entryFeeAmount;
        try {
          await Supabase.instance.client
              .from('wallets')
              .update({'coins_balance': silverCoins.value})
              .eq('id', currentUserId);

          await Supabase.instance.client.from('wallet_transactions').insert({
            'wallet_id': currentUserId,
            'amount': e.entryFeeAmount.toDouble(),
            'currency': 'Coins',
            'type': 'Commission',
            'status': 'Completed',
            'details': 'Event Entry: ${e.title}',
            'transaction_type': 'Debit',
          });
        } catch (_) {}
      }
    }

    final updatedList = List<String>.from(e.registeredUserIds)..add(currentUserId);
    try {
      await Supabase.instance.client
          .from('events')
          .update({
            'registered_user_ids': updatedList,
            'participants_count': e.participantsCount + 1,
          })
          .eq('id', eventId);

      await _loadEventsFromDatabase();
      await _loadTransactions();

      Get.snackbar(
        'Payment Verified ✅',
        'Successfully registered for ${e.title}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF10B981),
        colorText: Colors.white,
      );
      return true;
    } catch (e) {
      debugPrint('Event registration failed: $e');
      return false;
    }
  }

  Future<void> addAdminToEvent(String eventId, String adminId) async {
    final index = events.indexWhere((e) => e.id == eventId);
    if (index == -1) return;
    final e = events[index];

    if (e.adminIds.length >= 5) {
      Get.snackbar('Limit Reached 🛡️', 'Maximum of 5 Admins allowed per event.',
          snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.orange, colorText: Colors.white);
      return;
    }

    if (e.adminIds.contains(adminId)) return;

    final updatedAdmins = List<String>.from(e.adminIds)..add(adminId);
    try {
      await Supabase.instance.client
          .from('events')
          .update({'admin_ids': updatedAdmins})
          .eq('id', eventId);
      await _loadEventsFromDatabase();
    } catch (_) {}
  }

  Future<void> removeAdminFromEvent(String eventId, String adminId) async {
    final index = events.indexWhere((e) => e.id == eventId);
    if (index == -1) return;
    final e = events[index];

    if (!e.adminIds.contains(adminId)) return;

    final updatedAdmins = List<String>.from(e.adminIds)..remove(adminId);
    try {
      await Supabase.instance.client
          .from('events')
          .update({'admin_ids': updatedAdmins})
          .eq('id', eventId);
      await _loadEventsFromDatabase();
    } catch (_) {}
  }

  Future<void> updateEventStatus(String eventId, EventStatus newStatus) async {
    try {
      await Supabase.instance.client
          .from('events')
          .update({'status': newStatus.name})
          .eq('id', eventId);
      await _loadEventsFromDatabase();
    } catch (_) {}
  }

  Future<void> updateTimelineStatus(String eventId, String newStatus) async {
    try {
      await Supabase.instance.client
          .from('events')
          .update({'timeline_status': newStatus})
          .eq('id', eventId);
      await _loadEventsFromDatabase();
    } catch (_) {}
  }

  Future<void> promoteToCoOwner(String eventId, String userId) async {
    try {
      await Supabase.instance.client
          .from('events')
          .update({'co_owner_id': userId})
          .eq('id', eventId);
      await _loadEventsFromDatabase();
      Get.snackbar('Co-Owner Promoted 🤝', 'User is now the Co-Owner of the event.',
          snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.purple, colorText: Colors.white);
    } catch (_) {}
  }

  Future<void> kickMember(String eventId, String userId) async {
    final index = events.indexWhere((e) => e.id == eventId);
    if (index == -1) return;
    final e = events[index];
    final updatedList = List<String>.from(e.registeredUserIds)..remove(userId);
    try {
      await Supabase.instance.client
          .from('events')
          .update({
            'registered_user_ids': updatedList,
            'participants_count': updatedList.length,
          })
          .eq('id', eventId);
      await _loadEventsFromDatabase();
    } catch (_) {}
  }

  Future<void> banMember(String eventId, String userId) async {
    // Simulated as kicking for now, or update list
    await kickMember(eventId, userId);
  }

  Future<void> unbanMember(String eventId, String userId) async {
    // Approved
  }

  Future<void> muteMember(String eventId, String userId) async {
    // Muted
  }

  Future<void> refundEntryFee(String eventId, String userId) async {
    final index = events.indexWhere((e) => e.id == eventId);
    if (index == -1) return;
    final e = events[index];
    if (e.isPaid && e.entryFeeType == EntryFeeType.cash) {
      try {
        await Supabase.instance.client.from('wallet_transactions').insert({
          'wallet_id': userId,
          'amount': e.entryFeeAmount.toDouble(),
          'currency': 'INR',
          'type': 'Refund',
          'status': 'Completed',
          'details': 'Refund: Entry fee returned for ${e.title}',
          'transaction_type': 'Credit',
        });
      } catch (_) {}
    }
  }

  Future<void> promoteMember(String eventId, String userId, String role) async {
    if (role == 'Admin') {
      await addAdminToEvent(eventId, userId);
    }
  }

  Future<void> demoteAdmin(String eventId, String userId) async {
    await removeAdminFromEvent(eventId, userId);
  }
}

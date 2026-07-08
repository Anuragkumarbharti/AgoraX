import 'package:get/get.dart';
import 'package:flutter/material.dart';
import '../models/event_model.dart';
import 'store_controller.dart';

class EventController extends GetxController {
  // Current logged in user
  static const String currentUserId = 'me';

  // Dual currency wallet state
  RxInt get silverCoins => Get.find<StoreController>().silverCoinsBalance;
  RxDouble get cashBalance => Get.find<StoreController>().availableIncomeBalance;

  // Transactions log
  final RxList<Map<String, dynamic>> walletTransactions = <Map<String, dynamic>>[
    {
      'type': 'Deposit',
      'title': 'Initial Deposit',
      'amount': '₹2,500.00',
      'currency': 'cash',
      'date': '2026-07-05 14:30',
      'isCredit': true,
    },
    {
      'type': 'Refund Received',
      'title': 'Refund: UPSC Preparation Contest',
      'amount': '₹200.00',
      'currency': 'cash',
      'date': '2026-07-06 09:15',
      'isCredit': true,
    },
    {
      'type': 'Entry Fee Paid',
      'title': 'Entry: Physics Mock Test',
      'amount': '100 Coins',
      'currency': 'coins',
      'date': '2026-07-06 10:00',
      'isCredit': false,
    }
  ].obs;

  // Active Events List
  final RxList<Event> events = <Event>[].obs;

  // Notifications List
  final RxList<Map<String, dynamic>> notifications = <Map<String, dynamic>>[
    {
      'title': 'Event Created',
      'body': 'Weekly Coding Challenge has been published successfully.',
      'time': '10m ago',
    },
    {
      'title': 'Registration Started',
      'body': 'GK current affairs championship is now open for registration.',
      'time': '1h ago',
    }
  ].obs;

  void addNotification(String title, String body) {
    notifications.insert(0, {
      'title': title,
      'body': body,
      'time': 'Just now',
    });
  }

  // Participants registry mapping eventId -> List of user details
  final RxMap<String, List<Map<String, dynamic>>> eventParticipants = <String, List<Map<String, dynamic>>>{}.obs;

  List<Map<String, dynamic>> getParticipantsForEvent(String eventId) {
    if (!eventParticipants.containsKey(eventId)) {
      eventParticipants[eventId] = [
        {
          'userId': 'user_gk_10',
          'name': 'Vikram Singh',
          'avatar': 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e',
          'role': 'Moderator',
          'status': 'Approved',
          'joinTime': '2026-07-06 12:00',
          'paymentStatus': 'Paid',
          'online': true,
        },
        {
          'userId': 'user_gk_11',
          'name': 'Ananya Sen',
          'avatar': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb',
          'role': 'Co-Owner',
          'status': 'Approved',
          'joinTime': '2026-07-06 12:15',
          'paymentStatus': 'Paid',
          'online': true,
        },
        {
          'userId': 'user_gk_12',
          'name': 'Rohan Das',
          'avatar': 'https://images.unsplash.com/photo-1522075469751-3a6694fb2f61',
          'role': 'Guest',
          'status': 'Pending Approval',
          'joinTime': '2026-07-06 13:02',
          'paymentStatus': 'Pending',
          'online': false,
        },
        {
          'userId': 'user_bgmi_1',
          'name': 'Meera Nair',
          'avatar': 'https://images.unsplash.com/photo-1544005313-94ddf0286df2',
          'role': 'Guest',
          'status': 'Approved',
          'joinTime': '2026-07-06 14:10',
          'paymentStatus': 'Paid',
          'online': true,
        },
      ];
    }
    return eventParticipants[eventId]!;
  }

  @override
  void onInit() {
    super.onInit();
    _loadInitialEvents();
  }

  void _loadInitialEvents() {
    final List<Event> mock = Event.mockEvents();
    
    // Convert mock events to support paid features to display initially
    final List<Event> enriched = mock.map((e) {
      if (e.id == 'comm_jee_1') {
        // Make resonance test a paid event to show calculations
        return Event(
          id: e.id,
          title: e.title,
          description: e.description,
          bannerUrl: e.bannerUrl,
          category: e.category,
          difficulty: e.difficulty,
          organizer: e.organizer,
          isOfficial: e.isOfficial,
          startDate: e.startDate,
          endDate: e.endDate,
          registrationDeadline: e.registrationDeadline,
          resultDate: e.resultDate,
          maxParticipants: 200,
          isUnlimited: e.isUnlimited,
          entryFeeType: EntryFeeType.cash,
          entryFeeAmount: 100, // ₹100 entry fee
          prizePool: '₹2,900 - ₹11,600',
          rewards: e.rewards,
          status: EventStatus.registrationOpen,
          format: e.format,
          rules: e.rules,
          requiredLevel: e.requiredLevel,
          requiredBadge: e.requiredBadge,
          tags: e.tags,
          language: e.language,
          isPublic: e.isPublic,
          participantsCount: 82, // Starts with 82 participants
          antiCheat: e.antiCheat,
          negativeMarking: e.negativeMarking,
          durationMinutes: e.durationMinutes,
          questionCount: e.questionCount,
          passingMarks: e.passingMarks,
          requiredRegistrationFields: e.requiredRegistrationFields,
          termsAndConditions: e.termsAndConditions,
          isPaid: true,
          minParticipants: 50,
          winnerType: 'top3',
          autoPrizePool: true,
          passwordProtected: false,
          password: '',
          coOwnerId: 'u3', // Rahul is Co-Owner
          adminIds: ['u4', 'u5'], // 2 admins initial
          registeredUserIds: List.generate(82, (index) => 'user_$index'),
          creatorId: 'u2', // Priya is Owner, not me, so I can join
        );
      } else if (e.id == 'official_gk_1') {
        // Enrich official event to be live now and pre-registered for the user
        return Event(
          id: e.id,
          title: e.title,
          description: e.description,
          bannerUrl: e.bannerUrl,
          category: e.category,
          difficulty: e.difficulty,
          organizer: e.organizer,
          isOfficial: true, // Official event created by apk admins
          startDate: DateTime.now().add(const Duration(seconds: 15)), // Starting in 15 seconds!
          endDate: DateTime.now().add(const Duration(hours: 2)),
          registrationDeadline: DateTime.now().subtract(const Duration(hours: 2)), // Ended
          resultDate: DateTime.now().add(const Duration(hours: 3)),
          maxParticipants: 1000,
          isUnlimited: true,
          entryFeeType: EntryFeeType.coins,
          entryFeeAmount: 50,
          prizePool: '🪙 10,000 Coins Pool',
          rewards: e.rewards,
          status: EventStatus.live, // Live status
          format: e.format,
          rules: e.rules,
          requiredLevel: e.requiredLevel,
          requiredBadge: e.requiredBadge,
          tags: e.tags,
          language: e.language,
          isPublic: e.isPublic,
          participantsCount: 420,
          antiCheat: e.antiCheat,
          negativeMarking: e.negativeMarking,
          durationMinutes: e.durationMinutes,
          questionCount: e.questionCount,
          passingMarks: e.passingMarks,
          requiredRegistrationFields: e.requiredRegistrationFields,
          termsAndConditions: e.termsAndConditions,
          isPaid: true,
          minParticipants: 100,
          winnerType: e.winnerType,
          autoPrizePool: e.autoPrizePool,
          passwordProtected: false,
          password: '',
          registeredUserIds: ['user_1', 'user_2', 'me'], // Current user 'me' is pre-registered!
          creatorId: 'apk_admin_999', // Created by apk admins
          isMultiRound: true, // Multi-round event
          rounds: const [
            RoundConfig(
              name: 'Round 1: Qualifying Quiz',
              description: 'General Aptitude MCQ round.',
              format: 'MCQ Quiz',
              totalQuestions: 4,
              marksPerQuestion: 10,
              negativeMarking: false,
              timerPerQuestion: 15,
              qualifyingCriteria: 'Top 50%',
              breakTimeMinutes: 10,
              autoStartNextRound: true,
            ),
            RoundConfig(
              name: 'Round 2: Subject Final',
              description: 'Harder subject wise test.',
              format: 'Aptitude Test',
              totalQuestions: 4,
              marksPerQuestion: 20,
              negativeMarking: true,
              timerPerQuestion: 25,
              qualifyingCriteria: 'Top 3 Winners',
              breakTimeMinutes: 0,
              autoStartNextRound: false,
            ),
          ],
        );
      }
      return e;
    }).toList();

    // Add another paid tournament: BGMI Solo Tournament
    enriched.add(
      Event(
        id: 'bgmi_solo_paid',
        title: 'BGMI Solo Esports Tournament',
        description: 'Premium Esports Solo Showdown. Erangel map. Screen monitoring and anti-cheat active.',
        bannerUrl: 'https://images.unsplash.com/photo-1542751371-adc38448a05e',
        category: 'Computer Science', // fits category filter
        difficulty: 'Hard',
        organizer: 'Esports India Club',
        isOfficial: false,
        startDate: DateTime.now().add(const Duration(days: 3)),
        endDate: DateTime.now().add(const Duration(days: 3, hours: 4)),
        registrationDeadline: DateTime.now().add(const Duration(days: 2)),
        resultDate: DateTime.now().add(const Duration(days: 3, hours: 5)),
        maxParticipants: 100,
        isUnlimited: false,
        entryFeeType: EntryFeeType.cash,
        entryFeeAmount: 150,
        prizePool: '₹4,350 - ₹8,700',
        rewards: const EventReward(coins: 1000, xp: 800, certificate: true),
        status: EventStatus.registrationOpen,
        format: EventFormat.hackathon,
        rules: [
          'Hack & Emulator strictly prohibited.',
          'Screenshots of results must be uploaded.',
          'Agree to anti-cheat recording.'
        ],
        isPaid: true,
        minParticipants: 30,
        winnerType: 'top5',
        autoPrizePool: true,
        registeredUserIds: List.generate(45, (index) => 'user_$index'),
        participantsCount: 45,
        creatorId: 'u3', // Co-Owner or another creator
        coOwnerId: 'me', // I am the Co-Owner!
        adminIds: ['u2', 'u4', 'u5'], // 3 admins
      ),
    );

    // Seed Organizer simulator test event (Owner is "me")
    enriched.add(
      Event(
        id: 'organizer_test_event',
        title: '🔑 Organizer Test Championship',
        description: 'Complete organizer simulator. Manage schedules, edit question bank, and toggle next round delay times live.',
        bannerUrl: 'https://images.unsplash.com/photo-1511512578047-dfb367046420',
        category: 'Study Battle',
        difficulty: 'Medium',
        organizer: 'My Custom Community',
        isOfficial: false,
        startDate: DateTime.now().add(const Duration(seconds: 10)),
        endDate: DateTime.now().add(const Duration(hours: 2)),
        registrationDeadline: DateTime.now().subtract(const Duration(hours: 1)),
        resultDate: DateTime.now().add(const Duration(hours: 3)),
        maxParticipants: 150,
        isUnlimited: false,
        entryFeeType: EntryFeeType.coins,
        entryFeeAmount: 20,
        prizePool: '🪙 5,000 Coins',
        rewards: const EventReward(coins: 300, xp: 200, certificate: true),
        status: EventStatus.live,
        format: EventFormat.quiz,
        rules: const ['Follow fair play rules.', 'Organizer controls active.'],
        isPaid: true,
        minParticipants: 10,
        winnerType: 'top3',
        autoPrizePool: true,
        passwordProtected: false,
        password: '',
        registeredUserIds: const ['user_gk_10', 'user_gk_11', 'user_gk_12', 'user_bgmi_1', 'me'],
        creatorId: 'me', // Current logged-in user is Creator/Owner!
        isMultiRound: true,
        rounds: const [
          RoundConfig(
            name: 'Screening Round (KBC Buzzer)',
            description: 'Fastest finger round.',
            format: 'MCQ Quiz',
            totalQuestions: 4,
            marksPerQuestion: 10,
            negativeMarking: false,
            timerPerQuestion: 15,
            qualifyingCriteria: 'Top 50%',
            breakTimeMinutes: 10,
            autoStartNextRound: true,
            isBuzzerMode: true, // Buzzer mode is active
          ),
          RoundConfig(
            name: 'Grand Finale Round',
            description: 'Final subject wise battle.',
            format: 'Aptitude Test',
            totalQuestions: 4,
            marksPerQuestion: 20,
            negativeMarking: true,
            timerPerQuestion: 30,
            qualifyingCriteria: 'Top 3',
            breakTimeMinutes: 0,
            autoStartNextRound: false,
            isBuzzerMode: false,
          ),
        ],
      ),
    );

    events.assignAll(enriched);
  }

  // Create Paid Event Action
  bool createPaidEvent(Event newEvent) {
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
    
    // Deduct Coins immediately
    silverCoins.value -= 59;
    walletTransactions.insert(0, {
      'type': 'Host Fee Paid',
      'title': 'Event Creation: ${newEvent.title}',
      'amount': '59 Coins',
      'currency': 'coins',
      'date': _formattedNow(),
      'isCredit': false,
    });

    // Try adding to the list (Mocking success)
    try {
      events.add(newEvent);
      return true;
    } catch (e) {
      // Automatic Refund on failure
      silverCoins.value += 59;
      walletTransactions.insert(0, {
        'type': 'Refund Received',
        'title': 'Refund: Event Creation Failed',
        'amount': '59 Coins',
        'currency': 'coins',
        'date': _formattedNow(),
        'isCredit': true,
      });
      Get.snackbar(
        'Error ⚠️',
        'Failed to publish event. Creation cost refunded.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withOpacity(0.9),
        colorText: Colors.white,
      );
      return false;
    }
  }

  // Register user for paid event
  bool registerForEvent(String eventId, Map<String, dynamic> details) {
    final index = events.indexWhere((e) => e.id == eventId);
    if (index == -1) return false;
    final e = events[index];

    // 1. Validation Rules
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

    // 2. Financial Verification
    if (e.isPaid) {
      if (e.entryFeeType == EntryFeeType.cash) {
        if (cashBalance.value < e.entryFeeAmount) {
          Get.snackbar('Insufficient Cash 💰', 'Your cash balance is too low to pay the ₹${e.entryFeeAmount} entry fee.',
              snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red.withOpacity(0.9), colorText: Colors.white);
          return false;
        }
        // Deduct balance
        cashBalance.value -= e.entryFeeAmount;
        walletTransactions.insert(0, {
          'type': 'Entry Fee Paid',
          'title': 'Entry: ${e.title}',
          'amount': '₹${e.entryFeeAmount.toDouble()}',
          'currency': 'cash',
          'date': _formattedNow(),
          'isCredit': false,
        });
      } else if (e.entryFeeType == EntryFeeType.coins) {
        if (silverCoins.value < e.entryFeeAmount) {
          Get.snackbar('Insufficient Coins 🪙', 'Your coins balance is too low to pay the ${e.entryFeeAmount} entry fee.',
              snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red.withOpacity(0.9), colorText: Colors.white);
          return false;
        }
        // Deduct balance
        silverCoins.value -= e.entryFeeAmount;
        walletTransactions.insert(0, {
          'type': 'Entry Fee Paid',
          'title': 'Entry: ${e.title}',
          'amount': '${e.entryFeeAmount} Coins',
          'currency': 'coins',
          'date': _formattedNow(),
          'isCredit': false,
        });
      }
    }

    // 3. Register user
    final updatedList = List<String>.from(e.registeredUserIds)..add(currentUserId);
    final updatedEvent = Event(
      id: e.id,
      title: e.title,
      description: e.description,
      bannerUrl: e.bannerUrl,
      category: e.category,
      difficulty: e.difficulty,
      organizer: e.organizer,
      isOfficial: e.isOfficial,
      startDate: e.startDate,
      endDate: e.endDate,
      registrationDeadline: e.registrationDeadline,
      resultDate: e.resultDate,
      maxParticipants: e.maxParticipants,
      isUnlimited: e.isUnlimited,
      entryFeeType: e.entryFeeType,
      entryFeeAmount: e.entryFeeAmount,
      prizePool: e.prizePool,
      rewards: e.rewards,
      status: e.status,
      format: e.format,
      rules: e.rules,
      requiredLevel: e.requiredLevel,
      requiredBadge: e.requiredBadge,
      tags: e.tags,
      language: e.language,
      isPublic: e.isPublic,
      participantsCount: e.participantsCount + 1,
      antiCheat: e.antiCheat,
      negativeMarking: e.negativeMarking,
      durationMinutes: e.durationMinutes,
      questionCount: e.questionCount,
      passingMarks: e.passingMarks,
      requiredRegistrationFields: e.requiredRegistrationFields,
      termsAndConditions: e.termsAndConditions,
      isPaid: e.isPaid,
      minParticipants: e.minParticipants,
      winnerType: e.winnerType,
      autoPrizePool: e.autoPrizePool,
      passwordProtected: e.passwordProtected,
      password: e.password,
      creatorId: e.creatorId,
      coOwnerId: e.coOwnerId,
      adminIds: e.adminIds,
      registeredUserIds: updatedList,
      sponsoredAmount: e.sponsoredAmount,
      couponCodes: e.couponCodes,
      allowAdminsJoin: e.allowAdminsJoin,
    );

    events[index] = updatedEvent;
    
    Get.snackbar(
      'Payment Verified ✅',
      'Successfully registered for ${e.title}',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFF10B981),
      colorText: Colors.white,
    );
    return true;
  }

  // Manage Admins list dynamically
  void addAdminToEvent(String eventId, String adminId) {
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
    _updateEventAdmins(index, e, updatedAdmins);
    Get.snackbar('Admin Added 🛡️', 'Admin pool split updated automatically.',
        snackPosition: SnackPosition.BOTTOM, backgroundColor: const Color(0xFF6366F1), colorText: Colors.white);
  }

  void removeAdminFromEvent(String eventId, String adminId) {
    final index = events.indexWhere((e) => e.id == eventId);
    if (index == -1) return;
    final e = events[index];

    final updatedAdmins = List<String>.from(e.adminIds)..remove(adminId);
    _updateEventAdmins(index, e, updatedAdmins);
    Get.snackbar('Admin Removed 🛡️', 'Admin pool split updated automatically.',
        snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red, colorText: Colors.white);
  }

  void _updateEventAdmins(int index, Event e, List<String> updatedAdmins) {
    events[index] = Event(
      id: e.id,
      title: e.title,
      description: e.description,
      bannerUrl: e.bannerUrl,
      category: e.category,
      difficulty: e.difficulty,
      organizer: e.organizer,
      isOfficial: e.isOfficial,
      startDate: e.startDate,
      endDate: e.endDate,
      registrationDeadline: e.registrationDeadline,
      resultDate: e.resultDate,
      maxParticipants: e.maxParticipants,
      isUnlimited: e.isUnlimited,
      entryFeeType: e.entryFeeType,
      entryFeeAmount: e.entryFeeAmount,
      prizePool: e.prizePool,
      rewards: e.rewards,
      status: e.status,
      format: e.format,
      rules: e.rules,
      requiredLevel: e.requiredLevel,
      requiredBadge: e.requiredBadge,
      tags: e.tags,
      language: e.language,
      isPublic: e.isPublic,
      participantsCount: e.participantsCount,
      antiCheat: e.antiCheat,
      negativeMarking: e.negativeMarking,
      durationMinutes: e.durationMinutes,
      questionCount: e.questionCount,
      passingMarks: e.passingMarks,
      requiredRegistrationFields: e.requiredRegistrationFields,
      termsAndConditions: e.termsAndConditions,
      isPaid: e.isPaid,
      minParticipants: e.minParticipants,
      winnerType: e.winnerType,
      autoPrizePool: e.autoPrizePool,
      passwordProtected: e.passwordProtected,
      password: e.password,
      creatorId: e.creatorId,
      coOwnerId: e.coOwnerId,
      adminIds: updatedAdmins,
      registeredUserIds: e.registeredUserIds,
      sponsoredAmount: e.sponsoredAmount,
      couponCodes: e.couponCodes,
      allowAdminsJoin: e.allowAdminsJoin,
    );
  }

  // Automatic Cancellation Check & Process
  void triggerAutoCancellation(String eventId) {
    final index = events.indexWhere((e) => e.id == eventId);
    if (index == -1) return;
    final e = events[index];

    if (e.registeredUserIds.length < e.minParticipants) {
      // Cancel & refund
      for (final userId in e.registeredUserIds) {
        if (userId == currentUserId) {
          // Refund cash/wallet to current user
          if (e.isPaid) {
            if (e.entryFeeType == EntryFeeType.cash) {
              cashBalance.value += e.entryFeeAmount;
              walletTransactions.insert(0, {
                'type': 'Refund Received',
                'title': 'Refund: Minimum participants not met for ${e.title}',
                'amount': '₹${e.entryFeeAmount.toDouble()}',
                'currency': 'cash',
                'date': _formattedNow(),
                'isCredit': true,
              });
            } else if (e.entryFeeType == EntryFeeType.coins) {
              silverCoins.value += e.entryFeeAmount;
              walletTransactions.insert(0, {
                'type': 'Refund Received',
                'title': 'Refund: Minimum participants not met for ${e.title}',
                'amount': '${e.entryFeeAmount} Coins',
                'currency': 'coins',
                'date': _formattedNow(),
                'isCredit': true,
              });
            }
          }
        }
      }

      // Host creation fee is never refunded on cancellation. We do not refund creator coins here.

      events[index] = _changeEventStatus(e, EventStatus.archived); // mock cancel/archive
      Get.dialog(
        AlertDialog(
          title: const Text('Event Cancelled Automatically', style: TextStyle(color: Colors.white)),
          backgroundColor: const Color(0xFF1E293B),
          content: Text('"${e.title}" did not reach the minimum of ${e.minParticipants} participants. All users have been refunded.'),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: const Text('OK', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }
  }

  // Add mock transaction
  void depositCash(double amount) {
    cashBalance.value += amount;
    walletTransactions.insert(0, {
      'type': 'Deposit',
      'title': 'Deposited Cash via Gateway',
      'amount': '₹${amount.toStringAsFixed(2)}',
      'currency': 'cash',
      'date': _formattedNow(),
      'isCredit': true,
    });
  }

  bool withdrawCash(double amount, String upiId) {
    if (cashBalance.value < amount) return false;
    cashBalance.value -= amount;
    walletTransactions.insert(0, {
      'type': 'Withdrawal',
      'title': 'Withdrawal to $upiId',
      'amount': '₹${amount.toStringAsFixed(2)}',
      'currency': 'cash',
      'date': _formattedNow(),
      'isCredit': false,
    });
    return true;
  }

  Event _changeEventStatus(Event e, EventStatus status) {
    return Event(
      id: e.id,
      title: e.title,
      description: e.description,
      bannerUrl: e.bannerUrl,
      category: e.category,
      difficulty: e.difficulty,
      organizer: e.organizer,
      isOfficial: e.isOfficial,
      startDate: e.startDate,
      endDate: e.endDate,
      registrationDeadline: e.registrationDeadline,
      resultDate: e.resultDate,
      maxParticipants: e.maxParticipants,
      isUnlimited: e.isUnlimited,
      entryFeeType: e.entryFeeType,
      entryFeeAmount: e.entryFeeAmount,
      prizePool: e.prizePool,
      rewards: e.rewards,
      status: status,
      format: e.format,
      rules: e.rules,
      requiredLevel: e.requiredLevel,
      requiredBadge: e.requiredBadge,
      tags: e.tags,
      language: e.language,
      isPublic: e.isPublic,
      participantsCount: e.participantsCount,
      antiCheat: e.antiCheat,
      negativeMarking: e.negativeMarking,
      durationMinutes: e.durationMinutes,
      questionCount: e.questionCount,
      passingMarks: e.passingMarks,
      requiredRegistrationFields: e.requiredRegistrationFields,
      termsAndConditions: e.termsAndConditions,
      isPaid: e.isPaid,
      minParticipants: e.minParticipants,
      winnerType: e.winnerType,
      autoPrizePool: e.autoPrizePool,
      passwordProtected: e.passwordProtected,
      password: e.password,
      creatorId: e.creatorId,
      coOwnerId: e.coOwnerId,
      adminIds: e.adminIds,
      registeredUserIds: e.registeredUserIds,
      sponsoredAmount: e.sponsoredAmount,
      couponCodes: e.couponCodes,
      allowAdminsJoin: e.allowAdminsJoin,
    );
  }

  void kickMember(String eventId, String userId) {
    final list = getParticipantsForEvent(eventId);
    final idx = list.indexWhere((p) => p['userId'] == userId);
    if (idx != -1) {
      final name = list[idx]['name'];
      list.removeAt(idx);
      eventParticipants[eventId] = List.from(list);
      addNotification('Member Kicked', '$name was kicked from event.');
      Get.snackbar('Kicked 🥾', '$name was removed from the event.',
          snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.orange, colorText: Colors.white);
    }
  }

  void banMember(String eventId, String userId) {
    final list = getParticipantsForEvent(eventId);
    final idx = list.indexWhere((p) => p['userId'] == userId);
    if (idx != -1) {
      list[idx]['status'] = 'Banned';
      eventParticipants[eventId] = List.from(list);
      final name = list[idx]['name'];
      addNotification('Member Banned 🚫', '$name has been banned.');
      Get.snackbar('Banned 🚫', '$name has been banned from the event.',
          snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  void unbanMember(String eventId, String userId) {
    final list = getParticipantsForEvent(eventId);
    final idx = list.indexWhere((p) => p['userId'] == userId);
    if (idx != -1) {
      list[idx]['status'] = 'Approved';
      eventParticipants[eventId] = List.from(list);
      final name = list[idx]['name'];
      addNotification('Member Unbanned 🟢', '$name has been unbanned.');
      Get.snackbar('Unbanned 🟢', '$name is now unbanned.',
          snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.green, colorText: Colors.white);
    }
  }

  void muteMember(String eventId, String userId) {
    final list = getParticipantsForEvent(eventId);
    final idx = list.indexWhere((p) => p['userId'] == userId);
    if (idx != -1) {
      list[idx]['status'] = 'Muted';
      eventParticipants[eventId] = List.from(list);
      final name = list[idx]['name'];
      addNotification('Member Muted 🔇', '$name is muted in chat.');
      Get.snackbar('Muted 🔇', '$name has been muted in chat.',
          snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.orange, colorText: Colors.white);
    }
  }

  void refundEntryFee(String eventId, String userId) {
    final list = getParticipantsForEvent(eventId);
    final idx = list.indexWhere((p) => p['userId'] == userId);
    if (idx != -1) {
      list[idx]['paymentStatus'] = 'Refunded';
      eventParticipants[eventId] = List.from(list);
      final name = list[idx]['name'];

      final index = events.indexWhere((e) => e.id == eventId);
      if (index != -1) {
        final e = events[index];
        if (e.isPaid && e.entryFeeType == EntryFeeType.cash) {
          if (userId == currentUserId) {
            cashBalance.value += e.entryFeeAmount;
          }
          walletTransactions.insert(0, {
            'type': 'Refund Received',
            'title': 'Refund: Organizer returned entry for ${e.title}',
            'amount': '₹${e.entryFeeAmount.toDouble()}',
            'currency': 'cash',
            'date': _formattedNow(),
            'isCredit': true,
          });
        }
      }
      addNotification('Refund Processed 💰', 'Refund issued to $name.');
      Get.snackbar('Refunded 💰', 'Refund of entry fee processed successfully for $name.',
          snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.green, colorText: Colors.white);
    }
  }

  void promoteMember(String eventId, String userId, String newRole) {
    final list = getParticipantsForEvent(eventId);
    final idx = list.indexWhere((p) => p['userId'] == userId);
    if (idx != -1) {
      list[idx]['role'] = newRole;
      eventParticipants[eventId] = List.from(list);
      final name = list[idx]['name'];
      
      if (newRole == 'Admin') {
        final index = events.indexWhere((e) => e.id == eventId);
        if (index != -1) {
          final e = events[index];
          if (!e.adminIds.contains(userId)) {
            final updatedAdmins = List<String>.from(e.adminIds)..add(userId);
            _updateEventAdmins(index, e, updatedAdmins);
          }
        }
      }
      
      addNotification('Role Promoted 🛡️', '$name promoted to $newRole.');
      Get.snackbar('Promoted 🛡️', '$name is now a $newRole.',
          snackPosition: SnackPosition.BOTTOM, backgroundColor: const Color(0xFF6366F1), colorText: Colors.white);
    }
  }

  void demoteAdmin(String eventId, String userId) {
    final list = getParticipantsForEvent(eventId);
    final idx = list.indexWhere((p) => p['userId'] == userId);
    if (idx != -1) {
      list[idx]['role'] = 'Guest';
      eventParticipants[eventId] = List.from(list);
      final name = list[idx]['name'];

      final index = events.indexWhere((e) => e.id == eventId);
      if (index != -1) {
        final e = events[index];
        if (e.adminIds.contains(userId)) {
          final updatedAdmins = List<String>.from(e.adminIds)..remove(userId);
          _updateEventAdmins(index, e, updatedAdmins);
        }
      }

      addNotification('Admin Demoted 👤', '$name demoted to Guest.');
      Get.snackbar('Demoted 👤', '$name demoted to Guest.',
          snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  void promoteToCoOwner(String eventId, String userId) {
    final list = getParticipantsForEvent(eventId);
    final idx = list.indexWhere((p) => p['userId'] == userId);
    if (idx != -1) {
      list[idx]['role'] = 'Co-Owner';
      eventParticipants[eventId] = List.from(list);
      final name = list[idx]['name'];
      
      final index = events.indexWhere((e) => e.id == eventId);
      if (index != -1) {
        final e = events[index];
        events[index] = Event(
          id: e.id,
          title: e.title,
          description: e.description,
          bannerUrl: e.bannerUrl,
          category: e.category,
          difficulty: e.difficulty,
          organizer: e.organizer,
          isOfficial: e.isOfficial,
          startDate: e.startDate,
          endDate: e.endDate,
          registrationDeadline: e.registrationDeadline,
          resultDate: e.resultDate,
          maxParticipants: e.maxParticipants,
          isUnlimited: e.isUnlimited,
          entryFeeType: e.entryFeeType,
          entryFeeAmount: e.entryFeeAmount,
          prizePool: e.prizePool,
          rewards: e.rewards,
          status: e.status,
          format: e.format,
          rules: e.rules,
          requiredLevel: e.requiredLevel,
          requiredBadge: e.requiredBadge,
          tags: e.tags,
          language: e.language,
          isPublic: e.isPublic,
          participantsCount: e.participantsCount,
          antiCheat: e.antiCheat,
          negativeMarking: e.negativeMarking,
          durationMinutes: e.durationMinutes,
          questionCount: e.questionCount,
          passingMarks: e.passingMarks,
          requiredRegistrationFields: e.requiredRegistrationFields,
          termsAndConditions: e.termsAndConditions,
          isPaid: e.isPaid,
          minParticipants: e.minParticipants,
          winnerType: e.winnerType,
          autoPrizePool: e.autoPrizePool,
          passwordProtected: e.passwordProtected,
          password: e.password,
          creatorId: e.creatorId,
          coOwnerId: userId, // Set new Co-Owner!
          adminIds: e.adminIds,
          registeredUserIds: e.registeredUserIds,
          sponsoredAmount: e.sponsoredAmount,
          couponCodes: e.couponCodes,
          allowAdminsJoin: e.allowAdminsJoin,
          durationString: e.durationString,
          allowSpectators: e.allowSpectators,
          allowLateJoin: e.allowLateJoin,
          autoCancelMinUsers: e.autoCancelMinUsers,
          autoRefund: e.autoRefund,
          chatEnabled: e.chatEnabled,
          voiceRoomEnabled: e.voiceRoomEnabled,
          screenShareEnabled: e.screenShareEnabled,
          recordingEnabled: e.recordingEnabled,
          timelineStatus: e.timelineStatus,
          winners: e.winners,
          isMultiRound: e.isMultiRound,
          rounds: e.rounds,
        );
      }
      
      addNotification('Co-Owner Promoted 🤝', '$name is now the Co-Owner.');
      Get.snackbar('Co-Owner Promoted 🤝', '$name is now the Co-Owner of the event.',
          snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.purple, colorText: Colors.white);
    }
  }

  String _formattedNow() {
    final now = DateTime.now();
    return '${now.year}-${_pad(now.month)}-${_pad(now.day)} ${_pad(now.hour)}:${_pad(now.minute)}';
  }

  String _pad(int n) => n.toString().padLeft(2, '0');
}

enum EventStatus {
  draft,
  published,
  registrationOpen,
  registrationClosed,
  startingSoon,
  live,
  completed,
  resultPublished,
  archived
}

enum EventFormat {
  quiz,
  codingContest,
  debate,
  mockInterview,
  liveTest,
  mcqExam,
  aptitudeTest,
  puzzleChallenge,
  hackathon,
  assignment,
  voiceDebate
}

enum EntryFeeType { free, coins, cash }

class EventReward {
  const EventReward({
    this.coins = 0,
    this.xp = 0,
    this.badge,
    this.certificate = false,
    this.frameName,
    this.trophyName,
  });

  final int coins;
  final int xp;
  final String? badge;
  final bool certificate;
  final String? frameName;
  final String? trophyName;
}

class EventAntiCheat {
  const EventAntiCheat({
    this.screenMonitoring = false,
    this.randomQuestions = false,
    this.randomQuestionOrder = false,
    this.randomOptions = false,
  });

  final bool screenMonitoring;
  final bool randomQuestions;
  final bool randomQuestionOrder;
  final bool randomOptions;
}

class EventWinner {
  final String rank;
  final String username;
  final String userId;
  final String avatarUrl;
  final double prizeWon;
  final String community;
  final bool isVerified;

  const EventWinner({
    required this.rank,
    required this.username,
    required this.userId,
    required this.avatarUrl,
    required this.prizeWon,
    required this.community,
    this.isVerified = false,
  });
}

class Event {
  Event({
    required this.id,
    required this.title,
    required this.description,
    required this.bannerUrl,
    required this.category,
    required this.difficulty,
    required this.organizer,
    required this.isOfficial,
    required this.startDate,
    required this.endDate,
    required this.registrationDeadline,
    required this.resultDate,
    required this.maxParticipants,
    required this.isUnlimited,
    required this.entryFeeType,
    required this.entryFeeAmount,
    required this.prizePool,
    required this.rewards,
    required this.status,
    required this.format,
    required this.rules,
    this.requiredLevel = 1,
    this.requiredBadge,
    this.tags = const [],
    this.language = 'English',
    this.isPublic = true,
    this.participantsCount = 0,
    this.antiCheat = const EventAntiCheat(),
    this.negativeMarking = false,
    this.durationMinutes = 60,
    this.questionCount = 30,
    this.passingMarks = 40,
    this.requiredRegistrationFields = const ['name', 'email', 'phone'],
    this.termsAndConditions = 'I agree to participate with honesty and adhere to the proctoring rules of this competition.',
    this.isPaid = false,
    this.minParticipants = 10,
    this.winnerType = 'top3',
    this.autoPrizePool = true,
    this.passwordProtected = false,
    this.password = '',
    this.coOwnerId,
    this.adminIds = const [],
    this.registeredUserIds = const [],
    this.sponsoredAmount = 0.0,
    this.couponCodes = const {},
    this.allowAdminsJoin = false,
    this.creatorId = 'me',
    this.durationString = '1 hour',
    this.allowSpectators = true,
    this.allowLateJoin = false,
    this.autoCancelMinUsers = true,
    this.autoRefund = true,
    this.chatEnabled = true,
    this.voiceRoomEnabled = false,
    this.screenShareEnabled = false,
    this.recordingEnabled = false,
    this.timelineStatus = 'Registration Started',
    this.winners = const [],
    this.isMultiRound = false,
    this.rounds = const [],
  });

  final String id;
  final String title;
  final String description;
  final String bannerUrl;
  final String category;
  final String difficulty;
  final String organizer;
  final bool isOfficial;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime registrationDeadline;
  final DateTime resultDate;
  final int maxParticipants;
  final bool isUnlimited;
  final EntryFeeType entryFeeType;
  final int entryFeeAmount;
  final String prizePool;
  final EventReward rewards;
  EventStatus status;
  final EventFormat format;
  final List<String> rules;
  final int requiredLevel;
  final String? requiredBadge;
  final List<String> tags;
  final String language;
  final bool isPublic;
  int participantsCount;
  final EventAntiCheat antiCheat;
  final bool negativeMarking;
  final int durationMinutes;
  final int questionCount;
  final int passingMarks;
  final List<String> requiredRegistrationFields;
  final String termsAndConditions;

  // Paid event properties
  final bool isPaid;
  final int minParticipants;
  final String winnerType;
  final bool autoPrizePool;
  final bool passwordProtected;
  final String password;
  final String? coOwnerId;
  final List<String> adminIds;
  final List<String> registeredUserIds;
  final double sponsoredAmount;
  final Map<String, double> couponCodes;
  final bool allowAdminsJoin;
  final String creatorId;
  final String durationString;
  final bool allowSpectators;
  final bool allowLateJoin;
  final bool autoCancelMinUsers;
  final bool autoRefund;
  final bool chatEnabled;
  final bool voiceRoomEnabled;
  final bool screenShareEnabled;
  final bool recordingEnabled;
  final String timelineStatus;
  final List<EventWinner> winners;
  final bool isMultiRound;
  final List<RoundConfig> rounds;

  // Calculations
  double get currentCollection => registeredUserIds.length * entryFeeAmount.toDouble();
  double get minCollection => minParticipants * entryFeeAmount.toDouble();
  double get maxCollection => maxParticipants * entryFeeAmount.toDouble();
  double get minPrizePool => minCollection * 0.58;
  double get maxPrizePool => maxCollection * 0.58;
  double get currentPrizePool => currentCollection * 0.58;

  double get currentPlatformFee => currentCollection * 0.17;
  double get currentCreatorReward => currentCollection * 0.10;
  double get currentCoOwnerReward => currentCollection * 0.05;
  double get currentAdminRewardPool => currentCollection * 0.10;

  Map<String, List<double>> get winnerRanges {
    final List<double> percentages;
    if (winnerType == 'top5') {
      percentages = [0.40, 0.25, 0.15, 0.12, 0.08];
    } else if (winnerType == 'top10') {
      percentages = [0.30, 0.18, 0.12, 0.10, 0.08, 0.07, 0.06, 0.04, 0.03, 0.02];
    } else {
      percentages = [0.50, 0.30, 0.20]; // Default top 3
    }

    final Map<String, List<double>> ranges = {};
    for (int i = 0; i < percentages.length; i++) {
      final pct = percentages[i];
      final minVal = minPrizePool * pct;
      final maxVal = maxPrizePool * pct;
      final currVal = currentPrizePool * pct;
      final ordinal = '${i + 1}${_getOrdinalSuffix(i + 1)}';
      ranges[ordinal] = [minVal, maxVal, currVal];
    }
    return ranges;
  }

  static String _getOrdinalSuffix(int value) {
    if (value >= 11 && value <= 13) return 'th';
    switch (value % 10) {
      case 1: return 'st';
      case 2: return 'nd';
      case 3: return 'rd';
      default: return 'th';
    }
  }

  String get formatString {
    switch (format) {
      case EventFormat.quiz:
        return 'Quiz';
      case EventFormat.codingContest:
        return 'Coding';
      case EventFormat.debate:
        return 'Debate';
      case EventFormat.mockInterview:
        return 'Mock Interview';
      case EventFormat.liveTest:
        return 'Live Test';
      case EventFormat.mcqExam:
        return 'MCQ Exam';
      case EventFormat.aptitudeTest:
        return 'Aptitude Test';
      case EventFormat.puzzleChallenge:
        return 'Puzzle';
      case EventFormat.hackathon:
        return 'Hackathon';
      case EventFormat.assignment:
        return 'Assignment';
      case EventFormat.voiceDebate:
        return 'Voice Debate';
    }
  }

  static List<Event> mockEvents() => [
        Event(
          id: 'official_coding_1',
          title: 'Weekly Coding Challenge',
          description:
              'Compete with top engineers to solve 3 algorithmic problems in 30 minutes. Real-time test cases & cheat prevention active.',
          bannerUrl: 'https://images.unsplash.com/photo-1517694712202-14dd9538aa97',
          category: 'Computer Science',
          difficulty: 'Hard',
          organizer: 'AgoraX Official',
          isOfficial: true,
          startDate: DateTime.now().add(const Duration(hours: 4)),
          endDate: DateTime.now().add(const Duration(hours: 6)),
          registrationDeadline: DateTime.now().add(const Duration(hours: 3)),
          resultDate: DateTime.now().add(const Duration(hours: 7)),
          maxParticipants: 500,
          isUnlimited: false,
          entryFeeType: EntryFeeType.free,
          entryFeeAmount: 0,
          prizePool: '₹15,000 + 👑 Pro Badge',
          rewards: const EventReward(
            coins: 200,
            xp: 500,
            badge: 'badge_top_contrib',
            certificate: true,
          ),
          status: EventStatus.registrationOpen,
          format: EventFormat.codingContest,
          rules: [
            'Each user gets 3 randomized algorithmic questions.',
            'Plagiarism checking is strictly active.',
            'Screen monitoring will report any tab changes.',
          ],
          requiredLevel: 5,
          tags: ['Algorithms', 'DSA', 'Contest'],
          participantsCount: 342,
          antiCheat: const EventAntiCheat(
            screenMonitoring: true,
            randomQuestions: true,
            randomQuestionOrder: true,
          ),
        ),
        Event(
          id: 'official_gk_1',
          title: 'Current Affairs Championship',
          description:
              'Test your weekly knowledge of national and international current affairs. Best for UPSC & SSC preparation.',
          bannerUrl: 'https://images.unsplash.com/photo-1506784983877-45594efa4cbe',
          category: 'Government Exams',
          difficulty: 'Medium',
          organizer: 'AgoraX Official',
          isOfficial: true,
          startDate: DateTime.now().add(const Duration(days: 1)),
          endDate: DateTime.now().add(const Duration(days: 1, hours: 2)),
          registrationDeadline: DateTime.now().add(const Duration(hours: 18)),
          resultDate: DateTime.now().add(const Duration(days: 1, hours: 3)),
          maxParticipants: 1000,
          isUnlimited: true,
          entryFeeType: EntryFeeType.coins,
          entryFeeAmount: 50,
          prizePool: '🪙 10,000 Coins Pool',
          rewards: const EventReward(
            coins: 300,
            xp: 300,
            certificate: true,
          ),
          status: EventStatus.registrationOpen,
          format: EventFormat.quiz,
          rules: [
            '50 Multiple Choice Questions.',
            'Time limit: 20 minutes.',
            'Negative marking: -0.25 for incorrect answers.',
          ],
          requiredLevel: 2,
          tags: ['GK', 'UPSC', 'SSC'],
          participantsCount: 780,
          negativeMarking: true,
        ),
        Event(
          id: 'comm_jee_1',
          title: 'IIT Physics Mock Test',
          description:
              'A mock test strictly based on JEE Advanced pattern compiled by resonance physics experts.',
          bannerUrl: 'https://images.unsplash.com/photo-1635070041078-e363dbe005cb',
          category: 'JEE/NEET Prep',
          difficulty: 'Hard',
          organizer: 'Resonance Institute',
          isOfficial: false,
          startDate: DateTime.now().add(const Duration(days: 2)),
          endDate: DateTime.now().add(const Duration(days: 2, hours: 3)),
          registrationDeadline: DateTime.now().add(const Duration(days: 1)),
          resultDate: DateTime.now().add(const Duration(days: 2, hours: 5)),
          maxParticipants: 300,
          isUnlimited: false,
          entryFeeType: EntryFeeType.coins,
          entryFeeAmount: 100,
          prizePool: '🏆 Resonance Star Medal + 🪙 5,000',
          rewards: const EventReward(
            coins: 500,
            xp: 400,
            badge: 'badge_problem_solver',
            certificate: true,
          ),
          status: EventStatus.registrationOpen,
          format: EventFormat.mcqExam,
          rules: [
            'Full syllabus physics.',
            '30 Single Choice and Multi-Choice questions.',
            'Maintain focus inside the application.',
          ],
          requiredLevel: 1,
          tags: ['JEE', 'Physics', 'Mock Test'],
          participantsCount: 120,
        ),
        Event(
          id: 'past_official_1',
          title: 'Past UPSC Quiz Battle #10',
          description: 'A completed GK Battle covering History, Geography, and Polity.',
          bannerUrl: 'https://images.unsplash.com/photo-1506784983877-45594efa4cbe',
          category: 'Government Exams',
          difficulty: 'Hard',
          organizer: 'AgoraX Official',
          isOfficial: true,
          startDate: DateTime.now().subtract(const Duration(days: 3)),
          endDate: DateTime.now().subtract(const Duration(days: 3, hours: 2)),
          registrationDeadline: DateTime.now().subtract(const Duration(days: 4)),
          resultDate: DateTime.now().subtract(const Duration(days: 3, hours: 1)),
          maxParticipants: 500,
          isUnlimited: false,
          entryFeeType: EntryFeeType.cash,
          entryFeeAmount: 100,
          prizePool: '₹29,000 - ₹116,000',
          rewards: const EventReward(coins: 100, xp: 200),
          status: EventStatus.completed,
          format: EventFormat.quiz,
          rules: ['Rule 1', 'Rule 2'],
          participantsCount: 200,
          isPaid: true,
          winnerType: 'top3',
          winners: const [
            EventWinner(rank: '1st', username: 'UPSC_Champ', userId: 'user_gk_10', avatarUrl: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde', prizeWon: 5800, community: 'Govt Aspirants'),
            EventWinner(rank: '2nd', username: 'PolityKing', userId: 'user_gk_11', avatarUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330', prizeWon: 3480, community: 'Govt Aspirants'),
            EventWinner(rank: '3rd', username: 'IAS_Dreamer', userId: 'user_gk_12', avatarUrl: 'https://images.unsplash.com/photo-1570295999919-56ceb5ecca61', prizeWon: 2320, community: 'Govt Aspirants'),
          ],
        ),
        Event(
          id: 'past_comm_1',
          title: 'Past BGMI Tournament',
          description: 'Custom community BGMI battle organized by esports club.',
          bannerUrl: 'https://images.unsplash.com/photo-1542751371-adc38448a05e',
          category: 'Computer Science',
          difficulty: 'Medium',
          organizer: 'Esports Club',
          isOfficial: false,
          startDate: DateTime.now().subtract(const Duration(days: 2)),
          endDate: DateTime.now().subtract(const Duration(days: 2, hours: 3)),
          registrationDeadline: DateTime.now().subtract(const Duration(days: 3)),
          resultDate: DateTime.now().subtract(const Duration(days: 2, hours: 2)),
          maxParticipants: 100,
          isUnlimited: false,
          entryFeeType: EntryFeeType.cash,
          entryFeeAmount: 50,
          prizePool: '₹2,900 - ₹11,600',
          rewards: const EventReward(coins: 50, xp: 100),
          status: EventStatus.completed,
          format: EventFormat.codingContest,
          rules: ['Rule 1', 'Rule 2'],
          participantsCount: 80,
          isPaid: true,
          winnerType: 'top3',
          winners: const [
            EventWinner(rank: '1st', username: 'Mortal_Pro', userId: 'user_bgmi_1', avatarUrl: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde', prizeWon: 2320, community: 'BGMI Clan'),
            EventWinner(rank: '2nd', username: 'Jonathan_Fan', userId: 'user_bgmi_2', avatarUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330', prizeWon: 1392, community: 'BGMI Clan'),
            EventWinner(rank: '3rd', username: 'Scout_Jr', userId: 'user_bgmi_3', avatarUrl: 'https://images.unsplash.com/photo-1570295999919-56ceb5ecca61', prizeWon: 928, community: 'BGMI Clan'),
          ],
        ),
        Event(
          id: 'my_managed_event_1',
          title: 'Custom Paid Coding Battle',
          description: 'A custom coding event managed by me with full settings, dynamic prize calculations, and timeline tracking.',
          bannerUrl: 'https://images.unsplash.com/photo-1542751371-adc38448a05e',
          category: 'Computer Science',
          difficulty: 'Medium',
          organizer: 'My Custom Community',
          isOfficial: false,
          startDate: DateTime.now().add(const Duration(days: 2)),
          endDate: DateTime.now().add(const Duration(days: 2, hours: 2)),
          registrationDeadline: DateTime.now().add(const Duration(days: 1)),
          resultDate: DateTime.now().add(const Duration(days: 2, hours: 3)),
          maxParticipants: 100,
          isUnlimited: false,
          entryFeeType: EntryFeeType.cash,
          entryFeeAmount: 200,
          prizePool: '₹11,600 - ₹23,200',
          rewards: const EventReward(coins: 100, xp: 200),
          status: EventStatus.registrationOpen,
          format: EventFormat.codingContest,
          rules: ['Rule 1', 'Rule 2'],
          participantsCount: 15,
          isPaid: true,
          winnerType: 'top3',
          creatorId: 'me',
          registeredUserIds: const ['user_gk_10', 'user_gk_11', 'user_gk_12', 'user_bgmi_1'],
        ),
      ];
}

class RoundConfig {
  final String name;
  final String description;
  final String format; // MCQ Quiz, Coding Challenge, Aptitude Test, etc.
  final int totalQuestions;
  final int marksPerQuestion;
  final bool negativeMarking;
  final int timerPerQuestion;
  final String qualifyingCriteria; // Top 10, Top 20, Top 50%, Min Score, etc.
  final int breakTimeMinutes;
  final bool autoStartNextRound;
  final DateTime? startDate;
  final bool isBuzzerMode;

  const RoundConfig({
    required this.name,
    required this.description,
    required this.format,
    required this.totalQuestions,
    required this.marksPerQuestion,
    required this.negativeMarking,
    required this.timerPerQuestion,
    required this.qualifyingCriteria,
    required this.breakTimeMinutes,
    required this.autoStartNextRound,
    this.startDate,
    this.isBuzzerMode = false,
  });
}

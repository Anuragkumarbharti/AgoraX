import 'package:flutter/material.dart';

// ─── Badge Model ──────────────────────────────────────────────────────────────

class StudyBadge {
  const StudyBadge({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
    this.isUnlocked = false,
    this.unlocksAtLevel = 1,
  });

  final String id;
  final String label;
  final String icon;
  final Color color;
  final bool isUnlocked;
  final int unlocksAtLevel;
}

// ─── Daily Task Model ─────────────────────────────────────────────────────────

class DailyTask {
  const DailyTask({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.xpReward,
    required this.coinReward,
    this.isCompleted = false,
    this.timeLimit,
  });

  final String id;
  final DailyTaskType type;
  final String title;
  final String description;
  final int xpReward;
  final int coinReward;
  final bool isCompleted;
  final int? timeLimit; // in minutes

  DailyTask copyWith({bool? isCompleted}) => DailyTask(
        id: id,
        type: type,
        title: title,
        description: description,
        xpReward: xpReward,
        coinReward: coinReward,
        isCompleted: isCompleted ?? this.isCompleted,
        timeLimit: timeLimit,
      );
}

enum DailyTaskType {
  quiz,
  puzzle,
  codingProblem,
  mockTest,
  interviewQuestion,
  flashcard,
  assignment,
  caseStudy,
  logicalReasoning,
  weeklyChallenge,
  monthlyGrandChallenge,
}

extension DailyTaskTypeExt on DailyTaskType {
  String get label {
    switch (this) {
      case DailyTaskType.quiz:
        return 'Daily Quiz';
      case DailyTaskType.puzzle:
        return 'Daily Puzzle';
      case DailyTaskType.codingProblem:
        return 'Coding Problem';
      case DailyTaskType.mockTest:
        return 'Mock Test';
      case DailyTaskType.interviewQuestion:
        return 'Interview Questions';
      case DailyTaskType.flashcard:
        return 'Flashcards';
      case DailyTaskType.assignment:
        return 'Assignment';
      case DailyTaskType.caseStudy:
        return 'Case Study';
      case DailyTaskType.logicalReasoning:
        return 'Logical Reasoning';
      case DailyTaskType.weeklyChallenge:
        return 'Weekly Challenge';
      case DailyTaskType.monthlyGrandChallenge:
        return 'Monthly Grand Challenge';
    }
  }

  IconData get icon {
    switch (this) {
      case DailyTaskType.quiz:
        return Icons.quiz_outlined;
      case DailyTaskType.puzzle:
        return Icons.extension_outlined;
      case DailyTaskType.codingProblem:
        return Icons.code_outlined;
      case DailyTaskType.mockTest:
        return Icons.assignment_outlined;
      case DailyTaskType.interviewQuestion:
        return Icons.question_answer_outlined;
      case DailyTaskType.flashcard:
        return Icons.style_outlined;
      case DailyTaskType.assignment:
        return Icons.task_alt_outlined;
      case DailyTaskType.caseStudy:
        return Icons.cases_outlined;
      case DailyTaskType.logicalReasoning:
        return Icons.psychology_outlined;
      case DailyTaskType.weeklyChallenge:
        return Icons.emoji_events_outlined;
      case DailyTaskType.monthlyGrandChallenge:
        return Icons.military_tech_outlined;
    }
  }

  Color get color {
    switch (this) {
      case DailyTaskType.quiz:
        return const Color(0xFF6366F1);
      case DailyTaskType.puzzle:
        return const Color(0xFF8B5CF6);
      case DailyTaskType.codingProblem:
        return const Color(0xFF10B981);
      case DailyTaskType.mockTest:
        return const Color(0xFFF59E0B);
      case DailyTaskType.interviewQuestion:
        return const Color(0xFF3B82F6);
      case DailyTaskType.flashcard:
        return const Color(0xFFEC4899);
      case DailyTaskType.assignment:
        return const Color(0xFF14B8A6);
      case DailyTaskType.caseStudy:
        return const Color(0xFFF97316);
      case DailyTaskType.logicalReasoning:
        return const Color(0xFFA78BFA);
      case DailyTaskType.weeklyChallenge:
        return const Color(0xFFFBBF24);
      case DailyTaskType.monthlyGrandChallenge:
        return const Color(0xFFEF4444);
    }
  }
}

// ─── Study Level Title ────────────────────────────────────────────────────────

class LevelTitle {
  const LevelTitle({required this.minLevel, required this.title, required this.icon});
  final int minLevel;
  final String title;
  final String icon;
}

// ─── Study Category Model ─────────────────────────────────────────────────────

class StudyCategory {
  StudyCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.emoji,
    required this.color,
    required this.gradientColors,
    required this.description,
    required this.tags,
    required this.levelTitles,
    required this.badges,
    this.level = 1,
    this.xp = 0,
    this.totalXpForNextLevel = 1000,
    this.coins = 0,
    this.rank = 0,
    this.hiringScore = 0,
    this.isSelected = false,
    this.dailyTasks = const [],
    this.streak = 0,
  });

  final String id;
  final String name;
  final String icon;
  final String emoji;
  final Color color;
  final List<Color> gradientColors;
  final String description;
  final List<String> tags;
  final List<LevelTitle> levelTitles;
  final List<StudyBadge> badges;

  int level;
  int xp;
  int totalXpForNextLevel;
  int coins;
  int rank;
  int hiringScore;
  bool isSelected;
  List<DailyTask> dailyTasks;
  int streak;

  String get currentTitle {
    final applicable = levelTitles.where((t) => t.minLevel <= level).toList();
    if (applicable.isEmpty) return levelTitles.first.title;
    return applicable.last.title;
  }

  String get currentTitleIcon {
    final applicable = levelTitles.where((t) => t.minLevel <= level).toList();
    if (applicable.isEmpty) return levelTitles.first.icon;
    return applicable.last.icon;
  }

  double get xpProgress => xp / totalXpForNextLevel;

  List<StudyBadge> get unlockedBadges => badges.where((b) => b.isUnlocked || b.unlocksAtLevel <= level).toList();
}

// ─── Static Data ─────────────────────────────────────────────────────────────

class StudyCategoryData {
  static final List<StudyCategory> allCategories = [
    // 1. Engineering & CS
    StudyCategory(
      id: 'engineering_cs',
      name: 'Engineering & CS',
      icon: 'code',
      emoji: '💻',
      color: const Color(0xFF6366F1),
      gradientColors: [const Color(0xFF6366F1), const Color(0xFF4F46E5)],
      description: 'Software Engineering, DSA, System Design & more',
      tags: [
        'Software Engineer', 'Frontend Developer', 'Backend Developer',
        'Full Stack Developer', 'Python Developer', 'Java Developer',
        'JavaScript Developer', 'React Developer', 'Next.js Developer',
        'Flutter Developer', 'Android Developer', 'iOS Developer',
        'Node.js Developer', 'DevOps Engineer', 'Cloud Engineer',
        'AI Engineer', 'ML Engineer', 'Data Scientist',
        'Cyber Security Expert', 'Blockchain Developer',
        'System Designer', 'Software Architect', 'Competitive Programmer',
      ],
      levelTitles: [
        const LevelTitle(minLevel: 1, title: 'Code Learner', icon: '🌱'),
        const LevelTitle(minLevel: 3, title: 'Junior Coder', icon: '💡'),
        const LevelTitle(minLevel: 6, title: 'Problem Solver', icon: '🔧'),
        const LevelTitle(minLevel: 10, title: 'Competitive Coder', icon: '⚡'),
        const LevelTitle(minLevel: 15, title: 'Software Engineer', icon: '🛠️'),
        const LevelTitle(minLevel: 20, title: 'Senior Developer', icon: '🚀'),
        const LevelTitle(minLevel: 30, title: 'Code Master', icon: '🏆'),
        const LevelTitle(minLevel: 40, title: 'Grandmaster Programmer', icon: '👑'),
        const LevelTitle(minLevel: 50, title: 'Legendary Architect', icon: '⭐'),
      ],
      badges: [
        const StudyBadge(id: 'first_code', label: 'First Code', icon: '🌱', color: Color(0xFF10B981), unlocksAtLevel: 1),
        const StudyBadge(id: 'bug_hunter', label: 'Bug Hunter', icon: '🐛', color: Color(0xFFF59E0B), unlocksAtLevel: 5),
        const StudyBadge(id: 'algo_master', label: 'Algo Master', icon: '⚡', color: Color(0xFF6366F1), unlocksAtLevel: 10),
        const StudyBadge(id: 'open_source', label: 'Open Source', icon: '🌍', color: Color(0xFF3B82F6), unlocksAtLevel: 15),
        const StudyBadge(id: 'system_wizard', label: 'System Wizard', icon: '🔮', color: Color(0xFF8B5CF6), unlocksAtLevel: 25),
      ],
      level: 7, xp: 3450, totalXpForNextLevel: 5000, coins: 890, rank: 142, hiringScore: 72, isSelected: true, streak: 12,
      dailyTasks: [
        const DailyTask(id: 't1', type: DailyTaskType.quiz, title: 'Data Structures Quiz', description: 'Test your knowledge of Arrays, Trees & Graphs with 10 MCQs', xpReward: 50, coinReward: 10),
        const DailyTask(id: 't2', type: DailyTaskType.codingProblem, title: 'Two Sum Problem', description: 'Solve the classic Two Sum problem optimally in O(n) time', xpReward: 100, coinReward: 20, timeLimit: 30),
        const DailyTask(id: 't3', type: DailyTaskType.interviewQuestion, title: 'System Design: URL Shortener', description: 'Design a scalable URL shortener like bit.ly. Explain your approach.', xpReward: 80, coinReward: 15),
        const DailyTask(id: 't4', type: DailyTaskType.flashcard, title: 'OOP Concepts', description: 'Review 15 flashcards on SOLID principles & design patterns', xpReward: 30, coinReward: 5),
        const DailyTask(id: 't5', type: DailyTaskType.puzzle, title: 'Algorithm Puzzle', description: 'Find the missing number in an array of size n using XOR trick', xpReward: 60, coinReward: 12, isCompleted: true),
      ],
    ),

    // 2. Government Exam
    StudyCategory(
      id: 'government_exam',
      name: 'Government Exam',
      icon: 'school',
      emoji: '🏛️',
      color: const Color(0xFFF59E0B),
      gradientColors: [const Color(0xFFF59E0B), const Color(0xFFD97706)],
      description: 'UPSC, SSC, Banking, Railway & State Exams',
      tags: [
        'UPSC', 'SSC CGL', 'SSC CHSL', 'Railway RRB NTPC', 'Bank PO',
        'Bank Clerk', 'IBPS', 'SBI', 'RBI', 'NDA', 'CDS',
        'State PCS', 'CTET', 'UGC NET', 'GATE', 'Police Sub Inspector',
        'LIC', 'CAPF', 'Judiciary',
      ],
      levelTitles: [
        const LevelTitle(minLevel: 1, title: 'Aspirant', icon: '📚'),
        const LevelTitle(minLevel: 3, title: 'Dedicated Learner', icon: '✏️'),
        const LevelTitle(minLevel: 6, title: 'Reasoning Expert', icon: '🧩'),
        const LevelTitle(minLevel: 10, title: 'Math Master', icon: '📐'),
        const LevelTitle(minLevel: 15, title: 'GK Champion', icon: '🌍'),
        const LevelTitle(minLevel: 20, title: 'Exam Warrior', icon: '⚔️'),
        const LevelTitle(minLevel: 30, title: 'Top Performer', icon: '🏆'),
        const LevelTitle(minLevel: 40, title: 'Elite Aspirant', icon: '👑'),
        const LevelTitle(minLevel: 50, title: 'Civil Services Legend', icon: '⭐'),
      ],
      badges: [
        const StudyBadge(id: 'daily_gk', label: 'GK Streak', icon: '🌏', color: Color(0xFFF59E0B), unlocksAtLevel: 1),
        const StudyBadge(id: 'math_wizard', label: 'Math Wizard', icon: '🔢', color: Color(0xFFEF4444), unlocksAtLevel: 5),
        const StudyBadge(id: 'reasoning_pro', label: 'Reasoning Pro', icon: '🧩', color: Color(0xFF8B5CF6), unlocksAtLevel: 10),
        const StudyBadge(id: 'mock_king', label: 'Mock King', icon: '📝', color: Color(0xFF3B82F6), unlocksAtLevel: 15),
      ],
      level: 4, xp: 1200, totalXpForNextLevel: 2000, coins: 340, rank: 891, hiringScore: 45, isSelected: false, streak: 5,
      dailyTasks: [
        const DailyTask(id: 'g1', type: DailyTaskType.quiz, title: 'Current Affairs Quiz', description: '10 questions on latest national & international events', xpReward: 50, coinReward: 10),
        const DailyTask(id: 'g2', type: DailyTaskType.mockTest, title: 'SSC CGL Mock Test', description: '25 questions — Quantitative Aptitude section. 30 min timer.', xpReward: 120, coinReward: 25, timeLimit: 30),
        const DailyTask(id: 'g3', type: DailyTaskType.puzzle, title: 'Seating Arrangement', description: 'Solve a circular seating arrangement puzzle (8 people)', xpReward: 60, coinReward: 12),
        const DailyTask(id: 'g4', type: DailyTaskType.flashcard, title: 'Indian Constitution', description: 'Review 20 fundamental rights, DPSP & articles flashcards', xpReward: 30, coinReward: 5),
        const DailyTask(id: 'g5', type: DailyTaskType.logicalReasoning, title: 'Blood Relation + Direction', description: 'Mixed set of 15 reasoning questions', xpReward: 70, coinReward: 14),
      ],
    ),

    // 3. Medical
    StudyCategory(
      id: 'medical',
      name: 'Medical',
      icon: 'medical_services',
      emoji: '🏥',
      color: const Color(0xFFEF4444),
      gradientColors: [const Color(0xFFEF4444), const Color(0xFFDC2626)],
      description: 'MBBS, NEET, Healthcare & Medical Research',
      tags: [
        'MBBS', 'BDS', 'BAMS', 'BHMS', 'Nursing', 'Pharmacy',
        'Physiotherapy', 'Radiology', 'Medical Lab', 'Veterinary',
        'Medical Research', 'Healthcare Management', 'NEET Preparation',
      ],
      levelTitles: [
        const LevelTitle(minLevel: 1, title: 'Medical Learner', icon: '🌱'),
        const LevelTitle(minLevel: 5, title: 'Clinical Expert', icon: '🩺'),
        const LevelTitle(minLevel: 10, title: 'Healthcare Professional', icon: '🏥'),
        const LevelTitle(minLevel: 20, title: 'Medical Scholar', icon: '📖'),
        const LevelTitle(minLevel: 30, title: 'Research Specialist', icon: '🔬'),
        const LevelTitle(minLevel: 50, title: 'Medical Legend', icon: '⭐'),
      ],
      badges: [
        const StudyBadge(id: 'anatomy_ace', label: 'Anatomy Ace', icon: '🦴', color: Color(0xFFEF4444), unlocksAtLevel: 1),
        const StudyBadge(id: 'neet_warrior', label: 'NEET Warrior', icon: '⚔️', color: Color(0xFFF59E0B), unlocksAtLevel: 5),
        const StudyBadge(id: 'bio_master', label: 'Bio Master', icon: '🧬', color: Color(0xFF10B981), unlocksAtLevel: 10),
      ],
      level: 2, xp: 480, totalXpForNextLevel: 1000, coins: 120, rank: 2341, hiringScore: 30, isSelected: false, streak: 2,
      dailyTasks: [
        const DailyTask(id: 'm1', type: DailyTaskType.quiz, title: 'Human Anatomy Quiz', description: '10 MCQs on organ systems', xpReward: 50, coinReward: 10),
        const DailyTask(id: 'm2', type: DailyTaskType.mockTest, title: 'NEET Biology Mock', description: '45 questions from NCERT Biology', xpReward: 130, coinReward: 26, timeLimit: 45),
        const DailyTask(id: 'm3', type: DailyTaskType.flashcard, title: 'Pharmacology Flashcards', description: '20 drug name–function cards', xpReward: 30, coinReward: 5),
      ],
    ),

    // 4. Design & Creative
    StudyCategory(
      id: 'design',
      name: 'Design & Creative',
      icon: 'palette',
      emoji: '🎨',
      color: const Color(0xFFEC4899),
      gradientColors: [const Color(0xFFEC4899), const Color(0xFFDB2777)],
      description: 'UI/UX, Graphic Design, Motion & Creative Arts',
      tags: [
        'Graphic Designer', 'UI Designer', 'UX Designer', 'Product Designer',
        'Motion Designer', 'Animator', 'Illustrator', 'Logo Designer',
        'Brand Designer', '3D Artist', 'Interior Designer', 'Fashion Designer',
        'Content Writer', 'Copywriter', 'YouTuber', 'Influencer',
      ],
      levelTitles: [
        const LevelTitle(minLevel: 1, title: 'Creative Learner', icon: '🌱'),
        const LevelTitle(minLevel: 5, title: 'Visual Artist', icon: '🎨'),
        const LevelTitle(minLevel: 10, title: 'UI Specialist', icon: '📐'),
        const LevelTitle(minLevel: 20, title: 'Brand Expert', icon: '✨'),
        const LevelTitle(minLevel: 30, title: 'Design Master', icon: '🏆'),
        const LevelTitle(minLevel: 50, title: 'Creative Legend', icon: '⭐'),
      ],
      badges: [
        const StudyBadge(id: 'first_design', label: 'First Design', icon: '🎨', color: Color(0xFFEC4899), unlocksAtLevel: 1),
        const StudyBadge(id: 'color_theory', label: 'Color Theory', icon: '🌈', color: Color(0xFF8B5CF6), unlocksAtLevel: 3),
        const StudyBadge(id: 'ui_pro', label: 'UI Pro', icon: '📱', color: Color(0xFF3B82F6), unlocksAtLevel: 8),
      ],
      level: 3, xp: 720, totalXpForNextLevel: 1500, coins: 210, rank: 1456, hiringScore: 55, isSelected: false, streak: 3,
      dailyTasks: [
        const DailyTask(id: 'd1', type: DailyTaskType.quiz, title: 'Design Principles Quiz', description: 'Test Gestalt laws, color harmony & typography rules', xpReward: 50, coinReward: 10),
        const DailyTask(id: 'd2', type: DailyTaskType.assignment, title: 'Redesign a Login Screen', description: 'Sketch or wireframe a modern login UI — share on portfolio', xpReward: 100, coinReward: 20),
        const DailyTask(id: 'd3', type: DailyTaskType.flashcard, title: 'UX Terms', description: 'Review 15 UX research terminology cards', xpReward: 30, coinReward: 5),
      ],
    ),

    // 5. Business & Finance
    StudyCategory(
      id: 'business',
      name: 'Business & Finance',
      icon: 'business_center',
      emoji: '💼',
      color: const Color(0xFF10B981),
      gradientColors: [const Color(0xFF10B981), const Color(0xFF059669)],
      description: 'Entrepreneurship, Finance, Marketing & CA',
      tags: [
        'Entrepreneur', 'Startup Founder', 'Business Analyst', 'Product Manager',
        'Project Manager', 'Digital Marketing', 'SEO', 'Sales Expert',
        'CA', 'CS', 'CMA', 'MBA', 'Finance', 'Accounting',
        'Investment', 'Stock Market', 'FinTech', 'Cryptocurrency',
      ],
      levelTitles: [
        const LevelTitle(minLevel: 1, title: 'Business Rookie', icon: '📊'),
        const LevelTitle(minLevel: 5, title: 'Market Analyst', icon: '📈'),
        const LevelTitle(minLevel: 10, title: 'Finance Pro', icon: '💰'),
        const LevelTitle(minLevel: 20, title: 'Strategy Expert', icon: '♟️'),
        const LevelTitle(minLevel: 30, title: 'Business Leader', icon: '🏆'),
        const LevelTitle(minLevel: 50, title: 'Industry Legend', icon: '⭐'),
      ],
      badges: [
        const StudyBadge(id: 'first_profit', label: 'First Profit', icon: '💰', color: Color(0xFF10B981), unlocksAtLevel: 1),
        const StudyBadge(id: 'market_maven', label: 'Market Maven', icon: '📈', color: Color(0xFFF59E0B), unlocksAtLevel: 5),
      ],
      level: 1, xp: 200, totalXpForNextLevel: 800, coins: 50, rank: 4210, hiringScore: 20, isSelected: false, streak: 1,
      dailyTasks: [
        const DailyTask(id: 'b1', type: DailyTaskType.quiz, title: 'Finance Fundamentals', description: '10 MCQs on balance sheets, P&L and ratios', xpReward: 50, coinReward: 10),
        const DailyTask(id: 'b2', type: DailyTaskType.caseStudy, title: 'Startup Case Study', description: 'Analyze Zomato\'s growth strategy — answer 5 questions', xpReward: 90, coinReward: 18),
      ],
    ),

    // 6. Mathematics & Aptitude
    StudyCategory(
      id: 'mathematics',
      name: 'Mathematics & Aptitude',
      icon: 'calculate',
      emoji: '📐',
      color: const Color(0xFF3B82F6),
      gradientColors: [const Color(0xFF3B82F6), const Color(0xFF2563EB)],
      description: 'Quantitative Aptitude, Logical Reasoning & Maths',
      tags: [
        'Quantitative Aptitude', 'Logical Reasoning', 'Analytical Reasoning',
        'Data Interpretation', 'Statistics', 'Probability', 'Algebra',
        'Geometry', 'Trigonometry', 'Profit & Loss', 'Time & Work',
        'Speed Time Distance', 'Permutation & Combination', 'Number Series',
      ],
      levelTitles: [
        const LevelTitle(minLevel: 1, title: 'Number Rookie', icon: '🔢'),
        const LevelTitle(minLevel: 5, title: 'Aptitude Learner', icon: '🧩'),
        const LevelTitle(minLevel: 10, title: 'Reasoning Expert', icon: '⚡'),
        const LevelTitle(minLevel: 20, title: 'Math Master', icon: '📐'),
        const LevelTitle(minLevel: 50, title: 'Math Legend', icon: '⭐'),
      ],
      badges: [
        const StudyBadge(id: 'speed_math', label: 'Speed Math', icon: '⚡', color: Color(0xFF3B82F6), unlocksAtLevel: 1),
      ],
      level: 5, xp: 2100, totalXpForNextLevel: 3000, coins: 560, rank: 345, hiringScore: 62, isSelected: false, streak: 8,
      dailyTasks: [
        const DailyTask(id: 'ma1', type: DailyTaskType.quiz, title: 'Quant Practice', description: '15 questions on percentages, ratios & time-work', xpReward: 50, coinReward: 10),
        const DailyTask(id: 'ma2', type: DailyTaskType.puzzle, title: 'Number Series Challenge', description: 'Find the next 3 terms in 5 given series', xpReward: 60, coinReward: 12),
      ],
    ),

    // 7. Law
    StudyCategory(
      id: 'law',
      name: 'Law & Legal',
      icon: 'gavel',
      emoji: '⚖️',
      color: const Color(0xFF8B5CF6),
      gradientColors: [const Color(0xFF8B5CF6), const Color(0xFF7C3AED)],
      description: 'Advocate, Corporate, Civil & Cyber Law',
      tags: ['Advocate', 'Corporate Law', 'Criminal Law', 'Civil Law', 'Cyber Law', 'Intellectual Property', 'Judiciary Preparation'],
      levelTitles: [
        const LevelTitle(minLevel: 1, title: 'Law Aspirant', icon: '📜'),
        const LevelTitle(minLevel: 10, title: 'Legal Scholar', icon: '⚖️'),
        const LevelTitle(minLevel: 30, title: 'Legal Expert', icon: '🏆'),
        const LevelTitle(minLevel: 50, title: 'Legal Legend', icon: '⭐'),
      ],
      badges: [
        const StudyBadge(id: 'first_case', label: 'First Case', icon: '📜', color: Color(0xFF8B5CF6), unlocksAtLevel: 1),
      ],
      level: 1, xp: 100, totalXpForNextLevel: 800, coins: 30, rank: 5600, hiringScore: 15, isSelected: false, streak: 1,
      dailyTasks: [
        const DailyTask(id: 'l1', type: DailyTaskType.quiz, title: 'Constitutional Law Quiz', description: '10 MCQs on fundamental rights & duties', xpReward: 50, coinReward: 10),
      ],
    ),

    // 8. Languages
    StudyCategory(
      id: 'languages',
      name: 'Languages',
      icon: 'translate',
      emoji: '🗣️',
      color: const Color(0xFFF97316),
      gradientColors: [const Color(0xFFF97316), const Color(0xFFEA580C)],
      description: 'English, Hindi, French, German, Japanese & more',
      tags: ['English', 'Hindi', 'French', 'German', 'Japanese', 'Chinese', 'Spanish', 'Russian', 'Arabic', 'Korean'],
      levelTitles: [
        const LevelTitle(minLevel: 1, title: 'Language Beginner', icon: '🌱'),
        const LevelTitle(minLevel: 5, title: 'Conversational', icon: '💬'),
        const LevelTitle(minLevel: 15, title: 'Fluent Speaker', icon: '🗣️'),
        const LevelTitle(minLevel: 30, title: 'Bilingual Pro', icon: '🌍'),
        const LevelTitle(minLevel: 50, title: 'Polyglot Master', icon: '⭐'),
      ],
      badges: [
        const StudyBadge(id: 'first_word', label: 'First Word', icon: '🌱', color: Color(0xFFF97316), unlocksAtLevel: 1),
      ],
      level: 2, xp: 350, totalXpForNextLevel: 1000, coins: 80, rank: 3200, hiringScore: 35, isSelected: false, streak: 4,
      dailyTasks: [
        const DailyTask(id: 'lang1', type: DailyTaskType.flashcard, title: 'Vocabulary Builder', description: 'Learn 10 new advanced English words with context sentences', xpReward: 40, coinReward: 8),
        const DailyTask(id: 'lang2', type: DailyTaskType.assignment, title: 'Essay Writing', description: 'Write a 200-word essay on "The Future of AI" — AI will review it', xpReward: 80, coinReward: 15),
      ],
    ),

    // 9. School Students
    StudyCategory(
      id: 'school',
      name: 'School Students',
      icon: 'school',
      emoji: '🏫',
      color: const Color(0xFF14B8A6),
      gradientColors: [const Color(0xFF14B8A6), const Color(0xFF0D9488)],
      description: 'Class 6–12, Olympiad, NTSE & Foundation',
      tags: ['Class 6', 'Class 7', 'Class 8', 'Class 9', 'Class 10', 'Class 11', 'Class 12', 'Olympiad', 'NTSE', 'Foundation', 'JEE Foundation', 'NEET Foundation'],
      levelTitles: [
        const LevelTitle(minLevel: 1, title: 'Young Learner', icon: '🌱'),
        const LevelTitle(minLevel: 5, title: 'School Star', icon: '⭐'),
        const LevelTitle(minLevel: 10, title: 'Academic Topper', icon: '🏆'),
        const LevelTitle(minLevel: 20, title: 'Scholar', icon: '📚'),
        const LevelTitle(minLevel: 50, title: 'Young Genius', icon: '🧠'),
      ],
      badges: [
        const StudyBadge(id: 'first_rank', label: 'First Rank', icon: '🥇', color: Color(0xFF14B8A6), unlocksAtLevel: 1),
      ],
      level: 1, xp: 50, totalXpForNextLevel: 500, coins: 20, rank: 8900, hiringScore: 10, isSelected: false, streak: 0,
      dailyTasks: [
        const DailyTask(id: 's1', type: DailyTaskType.quiz, title: 'Science Quiz', description: '10 questions from Class 10 Physics & Chemistry', xpReward: 30, coinReward: 6),
        const DailyTask(id: 's2', type: DailyTaskType.puzzle, title: 'Math Brain Teaser', description: '5 fun math puzzles from Olympiad paper', xpReward: 40, coinReward: 8),
      ],
    ),

    // 10. Higher Education
    StudyCategory(
      id: 'higher_education',
      name: 'Higher Education',
      icon: 'account_balance',
      emoji: '🎓',
      color: const Color(0xFFA78BFA),
      gradientColors: [const Color(0xFFA78BFA), const Color(0xFF7C3AED)],
      description: 'B.Tech, MBA, PhD, Research & Competitive Exams',
      tags: ['BCA', 'B.Tech', 'M.Tech', 'B.Sc', 'M.Sc', 'BA', 'MA', 'MBA', 'MCA', 'PhD', 'Research Scholar', 'CAT', 'GATE', 'CUET'],
      levelTitles: [
        const LevelTitle(minLevel: 1, title: 'College Fresher', icon: '🎓'),
        const LevelTitle(minLevel: 5, title: 'Academic Explorer', icon: '🔭'),
        const LevelTitle(minLevel: 15, title: 'Research Associate', icon: '🔬'),
        const LevelTitle(minLevel: 30, title: 'Scholar', icon: '📖'),
        const LevelTitle(minLevel: 50, title: 'Research Legend', icon: '⭐'),
      ],
      badges: [
        const StudyBadge(id: 'grad_entry', label: 'Grad Entry', icon: '🎓', color: Color(0xFFA78BFA), unlocksAtLevel: 1),
      ],
      level: 3, xp: 950, totalXpForNextLevel: 2000, coins: 260, rank: 1890, hiringScore: 40, isSelected: false, streak: 3,
      dailyTasks: [
        const DailyTask(id: 'he1', type: DailyTaskType.mockTest, title: 'CAT Mock — Quant', description: '20 questions from DILR & Quant section', xpReward: 100, coinReward: 20, timeLimit: 40),
        const DailyTask(id: 'he2', type: DailyTaskType.caseStudy, title: 'MBA Case: Market Entry', description: 'Framework a go-to-market strategy for a new FMCG brand', xpReward: 90, coinReward: 18),
      ],
    ),
  ];
}

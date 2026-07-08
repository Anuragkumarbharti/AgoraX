import 'package:flutter/material.dart';

// ─── Career DNA Model ──────────────────────────────────────────────────────────

class CareerDimension {
  const CareerDimension({
    required this.name,
    required this.score,
    required this.color,
    required this.icon,
  });
  final String name;
  final double score; // 0.0 to 1.0
  final Color color;
  final String icon;
}

class CareerMatch {
  const CareerMatch({
    required this.title,
    required this.emoji,
    required this.matchPercent,
    required this.salaryRange,
    required this.description,
    required this.topSkills,
  });
  final String title;
  final String emoji;
  final int matchPercent;
  final String salaryRange;
  final String description;
  final List<String> topSkills;
}

class ReadinessScore {
  const ReadinessScore({
    required this.label,
    required this.emoji,
    required this.score,
    required this.color,
    required this.tip,
  });
  final String label;
  final String emoji;
  final int score;
  final Color color;
  final String tip;
}

class CareerDNA {
  CareerDNA({
    required this.userId,
    required this.dimensions,
    required this.careerMatches,
    required this.readinessScores,
    required this.naturalStrengths,
    required this.weaknesses,
    required this.learningSpeed,
    required this.aiConfidenceScore,
    required this.salaryPotential,
    required this.lastUpdated,
  });

  final String userId;
  final List<CareerDimension> dimensions;
  final List<CareerMatch> careerMatches;
  final List<ReadinessScore> readinessScores;
  final List<String> naturalStrengths;
  final List<String> weaknesses;
  final String learningSpeed; // Fast / Medium / Steady
  final int aiConfidenceScore; // 0-100
  final String salaryPotential;
  final DateTime lastUpdated;

  static CareerDNA mockDNA() => CareerDNA(
        userId: 'me',
        dimensions: const [
          CareerDimension(
            name: 'Logic',
            score: 0.85,
            color: Color(0xFF6366F1),
            icon: '🔷',
          ),
          CareerDimension(
            name: 'Creativity',
            score: 0.62,
            color: Color(0xFFEC4899),
            icon: '🎨',
          ),
          CareerDimension(
            name: 'Communication',
            score: 0.70,
            color: Color(0xFF10B981),
            icon: '🗣️',
          ),
          CareerDimension(
            name: 'Leadership',
            score: 0.55,
            color: Color(0xFFF59E0B),
            icon: '👑',
          ),
          CareerDimension(
            name: 'Teamwork',
            score: 0.80,
            color: Color(0xFF3B82F6),
            icon: '🤝',
          ),
          CareerDimension(
            name: 'Problem Solving',
            score: 0.90,
            color: Color(0xFF8B5CF6),
            icon: '🧩',
          ),
          CareerDimension(
            name: 'Discipline',
            score: 0.75,
            color: Color(0xFF14B8A6),
            icon: '⚡',
          ),
          CareerDimension(
            name: 'Confidence',
            score: 0.68,
            color: Color(0xFFF97316),
            icon: '🦁',
          ),
        ],
        careerMatches: const [
          CareerMatch(
            title: 'Software Architect',
            emoji: '🏗️',
            matchPercent: 94,
            salaryRange: '₹25L–₹60L',
            description:
                'Your logic + problem solving combo is perfect for designing complex systems.',
            topSkills: ['System Design', 'DSA', 'Cloud'],
          ),
          CareerMatch(
            title: 'AI/ML Engineer',
            emoji: '🤖',
            matchPercent: 88,
            salaryRange: '₹20L–₹50L',
            description:
                'Strong analytical thinking makes you a natural fit for AI research.',
            topSkills: ['Python', 'ML Frameworks', 'Math'],
          ),
          CareerMatch(
            title: 'Product Manager',
            emoji: '📱',
            matchPercent: 76,
            salaryRange: '₹18L–₹45L',
            description:
                'Your balanced teamwork + logic score works well in cross-functional roles.',
            topSkills: ['Strategy', 'Communication', 'Analytics'],
          ),
        ],
        readinessScores: const [
          ReadinessScore(
            label: 'Company',
            emoji: '🏢',
            score: 72,
            color: Color(0xFF6366F1),
            tip: 'Complete 2 more projects to reach 85%',
          ),
          ReadinessScore(
            label: 'Govt Exam',
            emoji: '🏛️',
            score: 45,
            color: Color(0xFFF59E0B),
            tip: 'Focus on GK and Reasoning daily for 3 months',
          ),
          ReadinessScore(
            label: 'Startup',
            emoji: '🚀',
            score: 81,
            color: Color(0xFF10B981),
            tip: 'Build 1 more end-to-end product to prove ownership',
          ),
          ReadinessScore(
            label: 'Research',
            emoji: '🔬',
            score: 58,
            color: Color(0xFFEC4899),
            tip: 'Publish a paper or contribute to open source research',
          ),
        ],
        naturalStrengths: [
          'Algorithmic Thinking',
          'Pattern Recognition',
          'Quick Learner',
          'Collaborative Problem Solving',
          'Code Optimization',
        ],
        weaknesses: [
          'Public Speaking',
          'Leadership Initiation',
          'Creativity under Pressure',
        ],
        learningSpeed: 'Fast',
        aiConfidenceScore: 84,
        salaryPotential: '₹18L–₹55L',
        lastUpdated: DateTime.now().subtract(const Duration(hours: 6)),
      );
}

// ─── Skill Node Model ──────────────────────────────────────────────────────────

enum SkillNodeStatus { locked, inProgress, completed }

class SkillNode {
  SkillNode({
    required this.id,
    required this.name,
    required this.icon,
    required this.xpReward,
    this.status = SkillNodeStatus.locked,
    this.children = const [],
    this.description = '',
    this.tasksRequired = 5,
    this.tasksCompleted = 0,
  });

  final String id;
  final String name;
  final String icon;
  final int xpReward;
  SkillNodeStatus status;
  final List<SkillNode> children;
  final String description;
  final int tasksRequired;
  int tasksCompleted;

  double get progress =>
      tasksCompleted / tasksRequired.clamp(1, tasksRequired);
}

class SkillTree {
  SkillTree({
    required this.id,
    required this.name,
    required this.emoji,
    required this.color,
    required this.roots,
  });

  final String id;
  final String name;
  final String emoji;
  final Color color;
  final List<SkillNode> roots;

  static List<SkillTree> mockTrees() => [
        SkillTree(
          id: 'programming',
          name: 'Programming',
          emoji: '💻',
          color: const Color(0xFF6366F1),
          roots: [
            SkillNode(
              id: 'c',
              name: 'C',
              icon: 'C',
              xpReward: 200,
              status: SkillNodeStatus.completed,
              tasksRequired: 10,
              tasksCompleted: 10,
              description: 'Pointers, memory, file I/O, algorithms in C',
            ),
            SkillNode(
              id: 'cpp',
              name: 'C++',
              icon: 'C++',
              xpReward: 250,
              status: SkillNodeStatus.completed,
              tasksRequired: 12,
              tasksCompleted: 12,
              description: 'OOP, STL, templates, competitive programming',
            ),
            SkillNode(
              id: 'java',
              name: 'Java',
              icon: '☕',
              xpReward: 300,
              status: SkillNodeStatus.inProgress,
              tasksRequired: 15,
              tasksCompleted: 9,
              description: 'Collections, Spring, OOP, multithreading',
            ),
            SkillNode(
              id: 'python',
              name: 'Python',
              icon: '🐍',
              xpReward: 280,
              status: SkillNodeStatus.inProgress,
              tasksRequired: 14,
              tasksCompleted: 6,
              description:
                  'Scripting, data structures, Django, ML libraries',
            ),
            SkillNode(
              id: 'js',
              name: 'JavaScript',
              icon: 'JS',
              xpReward: 280,
              status: SkillNodeStatus.locked,
              tasksRequired: 14,
              tasksCompleted: 0,
              description: 'DOM, async/await, closures, Node.js basics',
            ),
            SkillNode(
              id: 'rust',
              name: 'Rust',
              icon: '🦀',
              xpReward: 400,
              status: SkillNodeStatus.locked,
              tasksRequired: 20,
              tasksCompleted: 0,
              description: 'Memory safety, ownership, systems programming',
            ),
          ],
        ),
        SkillTree(
          id: 'dsa',
          name: 'DSA',
          emoji: '🔢',
          color: const Color(0xFF10B981),
          roots: [
            SkillNode(
              id: 'arrays',
              name: 'Arrays',
              icon: '📊',
              xpReward: 150,
              status: SkillNodeStatus.completed,
              tasksRequired: 8,
              tasksCompleted: 8,
            ),
            SkillNode(
              id: 'linked_list',
              name: 'Linked List',
              icon: '🔗',
              xpReward: 180,
              status: SkillNodeStatus.completed,
              tasksRequired: 8,
              tasksCompleted: 8,
            ),
            SkillNode(
              id: 'trees',
              name: 'Trees',
              icon: '🌲',
              xpReward: 250,
              status: SkillNodeStatus.inProgress,
              tasksRequired: 12,
              tasksCompleted: 7,
            ),
            SkillNode(
              id: 'graphs',
              name: 'Graph',
              icon: '🕸️',
              xpReward: 320,
              status: SkillNodeStatus.locked,
              tasksRequired: 15,
              tasksCompleted: 0,
            ),
            SkillNode(
              id: 'dp',
              name: 'DP',
              icon: '⚡',
              xpReward: 400,
              status: SkillNodeStatus.locked,
              tasksRequired: 20,
              tasksCompleted: 0,
            ),
          ],
        ),
        SkillTree(
          id: 'webdev',
          name: 'Web Dev',
          emoji: '🌐',
          color: const Color(0xFFF59E0B),
          roots: [
            SkillNode(
              id: 'html',
              name: 'HTML',
              icon: '🏗️',
              xpReward: 100,
              status: SkillNodeStatus.completed,
              tasksRequired: 5,
              tasksCompleted: 5,
            ),
            SkillNode(
              id: 'css',
              name: 'CSS',
              icon: '🎨',
              xpReward: 120,
              status: SkillNodeStatus.completed,
              tasksRequired: 6,
              tasksCompleted: 6,
            ),
            SkillNode(
              id: 'react',
              name: 'React',
              icon: '⚛️',
              xpReward: 350,
              status: SkillNodeStatus.inProgress,
              tasksRequired: 18,
              tasksCompleted: 5,
            ),
            SkillNode(
              id: 'node',
              name: 'Node.js',
              icon: '🟢',
              xpReward: 300,
              status: SkillNodeStatus.locked,
              tasksRequired: 15,
              tasksCompleted: 0,
            ),
            SkillNode(
              id: 'database',
              name: 'Database',
              icon: '🗄️',
              xpReward: 280,
              status: SkillNodeStatus.locked,
              tasksRequired: 14,
              tasksCompleted: 0,
            ),
          ],
        ),
      ];
}

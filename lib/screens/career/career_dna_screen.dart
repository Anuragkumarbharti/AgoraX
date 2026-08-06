import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:creania/core/theme.dart';
import '../../models/progression/career_dna_model.dart';

class CareerDnaScreen extends StatefulWidget {
  const CareerDnaScreen({Key? key}) : super(key: key);

  @override
  State<CareerDnaScreen> createState() => _CareerDnaScreenState();
}

class _CareerDnaScreenState extends State<CareerDnaScreen>
    with TickerProviderStateMixin {
  late AnimationController _radarController;
  late AnimationController _pulseController;
  late Animation<double> _radarAnimation;
  final CareerDNA _dna = CareerDNA.mockDNA();
  bool _isRunningAssessment = false;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _radarAnimation = CurvedAnimation(
      parent: _radarController,
      curve: Curves.easeOutCubic,
    );
    _radarController.forward();
  }

  @override
  void dispose() {
    _radarController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: Column(
              children: [
                _buildDnaHeader(),
                _buildRadarSection(),
                _buildReadinessSection(),
                _buildCareerMatchSection(),
                _buildStrengthWeaknessSection(),
                _buildUpdateDnaButton(),
                SizedBox(height: 80),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      pinned: true,
      backgroundColor: context.scaffoldBackgroundColor,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
        onPressed: () => Get.back(),
      ),
      title: Text(
        'Career DNA',
        style: TextStyle(
          color: context.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      actions: [
        Container(
          margin: EdgeInsets.only(right: 16, top: 8, bottom: 8),
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '🧬 AI Score: ${_dna.aiConfidenceScore}%',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDnaHeader() {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF6366F1).withOpacity(0.2),
            Color(0xFF8B5CF6).withOpacity(0.1),
            context.secondaryBackgroundColor.withOpacity(0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Color(0xFF6366F1).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnimatedBuilder(
                animation: _pulseController,
                builder: (ctx, _) => Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF6366F1)
                        .withOpacity(0.15 + 0.08 * _pulseController.value),
                    border: Border.all(
                      color: Color(0xFF6366F1).withOpacity(0.5),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFF6366F1)
                            .withOpacity(0.2 * _pulseController.value),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text('🧬', style: TextStyle(fontSize: 24)),
                  ),
                ),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Career DNA',
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'AI-powered career identity • Updated 6h ago',
                      style: TextStyle(
                        color: context.caption,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              _dnaInfoChip('💰 ${_dna.salaryPotential}',
                  Color(0xFF10B981)),
              SizedBox(width: 8),
              _dnaInfoChip('⚡ ${_dna.learningSpeed} Learner',
                  Color(0xFF6366F1)),
              SizedBox(width: 8),
              _dnaInfoChip('🎯 ${_dna.aiConfidenceScore}% AI Conf.',
                  Color(0xFFF59E0B)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dnaInfoChip(String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  // ─── Radar Chart Section ───────────────────────────────────────────────────

  Widget _buildRadarSection() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.borderColor.withOpacity(0.4)),
      ),
      child: Column(
        children: [
          Text(
            '🔷 Ability Radar',
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 20),
          AnimatedBuilder(
            animation: _radarAnimation,
            builder: (ctx, _) => SizedBox(
              width: 260,
              height: 260,
              child: CustomPaint(
                painter: _RadarChartPainter(
                  dimensions: _dna.dimensions,
                  progress: _radarAnimation.value,
                ),
              ),
            ),
          ),
          SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: _dna.dimensions.map((d) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: d.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: 4),
                  Text(
                    '${d.icon} ${d.name} ${(d.score * 100).toInt()}%',
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ─── Readiness Scores ───────────────────────────────────────────────────────

  Widget _buildReadinessSection() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🎯 Readiness Scores',
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.4,
            children: _dna.readinessScores
                .map((r) => _buildReadinessCard(r))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildReadinessCard(ReadinessScore r) {
    return GestureDetector(
      onTap: () => Get.snackbar(
        '${r.emoji} ${r.label} Readiness',
        r.tip,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: r.color.withOpacity(0.9),
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
      ),
      child: Container(
        padding: EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: r.color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: r.color.withOpacity(0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(r.emoji, style: TextStyle(fontSize: 22)),
                Text(
                  '${r.score}%',
                  style: TextStyle(
                    color: r.color,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              r.label,
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: r.score / 100,
                minHeight: 5,
                backgroundColor: r.color.withOpacity(0.15),
                valueColor: AlwaysStoppedAnimation(r.color),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Career Matches ─────────────────────────────────────────────────────────

  Widget _buildCareerMatchSection() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '💼 Best Career Matches',
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 12),
          ..._dna.careerMatches.asMap().entries.map(
                (e) => _buildCareerMatchCard(e.value, e.key == 0),
              ),
        ],
      ),
    );
  }

  Widget _buildCareerMatchCard(CareerMatch match, bool isTop) {
    final color = isTop
        ? Color(0xFFFBBF24)
        : Color(0xFF6366F1);
    return Container(
      margin: EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isTop
            ? Color(0xFFFBBF24).withOpacity(0.06)
            : context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(isTop ? 0.4 : 0.2),
          width: isTop ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(match.emoji,
                  style: TextStyle(fontSize: 26)),
            ),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (isTop)
                      Container(
                        margin: EdgeInsets.only(right: 6),
                        padding: EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Color(0xFFFBBF24).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '🏆 Best Match',
                          style: TextStyle(
                            color: Color(0xFFFBBF24),
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    Text(
                      match.title,
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 3),
                Text(
                  match.description,
                  style: TextStyle(
                    color: context.caption,
                    fontSize: 11,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 6),
                Wrap(
                  spacing: 4,
                  children: match.topSkills
                      .map(
                        (s) => Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(s,
                              style: TextStyle(
                                  color: color,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600)),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
          SizedBox(width: 10),
          Column(
            children: [
              Text(
                '${match.matchPercent}%',
                style: TextStyle(
                  color: color,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                match.salaryRange,
                style: TextStyle(
                  color: context.caption,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Strengths & Weaknesses ────────────────────────────────────────────────

  Widget _buildStrengthWeaknessSection() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildStrengthCard()),
          SizedBox(width: 10),
          Expanded(child: _buildWeaknessCard()),
        ],
      ),
    );
  }

  Widget _buildStrengthCard() {
    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Color(0xFF10B981).withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: Color(0xFF10B981).withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '💪 Strengths',
            style: TextStyle(
              color: Color(0xFF10B981),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 10),
          ..._dna.naturalStrengths.map(
            (s) => Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline_rounded,
                      size: 12, color: Color(0xFF10B981)),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      s,
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeaknessCard() {
    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Color(0xFFEF4444).withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: Color(0xFFEF4444).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '⚠️ Improve',
            style: TextStyle(
              color: Color(0xFFEF4444),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 10),
          ..._dna.weaknesses.map(
            (w) => Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(Icons.arrow_upward_rounded,
                      size: 12, color: Color(0xFFEF4444)),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      w,
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpdateDnaButton() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          onPressed: _isRunningAssessment
              ? null
              : () async {
                  setState(() => _isRunningAssessment = true);
                  await Future.delayed(const Duration(seconds: 2));
                  if (mounted) {
                    setState(() => _isRunningAssessment = false);
                    _radarController.reset();
                    _radarController.forward();
                    Get.snackbar(
                      '🧬 DNA Updated!',
                      'Your Career DNA has been recalculated by AI',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor:
                          Color(0xFF6366F1).withOpacity(0.9),
                      colorText: Colors.white,
                    );
                  }
                },
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _isRunningAssessment
                    ? [context.borderColor, context.borderColor]
                    : [
                        Color(0xFF6366F1),
                        Color(0xFF8B5CF6),
                      ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: _isRunningAssessment
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Running AI Assessment...',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      '🧬 Update My Career DNA',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Radar Chart Painter ───────────────────────────────────────────────────────

class _RadarChartPainter extends CustomPainter {
  _RadarChartPainter({
    required this.dimensions,
    required this.progress,
  });

  final List<CareerDimension> dimensions;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 20;
    final count = dimensions.length;
    final angleStep = (2 * math.pi) / count;

    // Draw background grid rings
    for (int ring = 1; ring <= 4; ring++) {
      final r = radius * ring / 4;
      final path = Path();
      for (int i = 0; i < count; i++) {
        final angle = -math.pi / 2 + i * angleStep;
        final x = center.dx + r * math.cos(angle);
        final y = center.dy + r * math.sin(angle);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.white.withOpacity(0.06)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }

    // Draw spokes
    for (int i = 0; i < count; i++) {
      final angle = -math.pi / 2 + i * angleStep;
      canvas.drawLine(
        center,
        Offset(
          center.dx + radius * math.cos(angle),
          center.dy + radius * math.sin(angle),
        ),
        Paint()
          ..color = Colors.white.withOpacity(0.08)
          ..strokeWidth = 1,
      );
    }

    // Draw filled radar polygon
    final filledPath = Path();
    for (int i = 0; i < count; i++) {
      final angle = -math.pi / 2 + i * angleStep;
      final r = radius * dimensions[i].score * progress;
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
      if (i == 0) {
        filledPath.moveTo(x, y);
      } else {
        filledPath.lineTo(x, y);
      }
    }
    filledPath.close();

    canvas.drawPath(
      filledPath,
      Paint()
        ..color = Color(0xFF6366F1).withOpacity(0.25)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      filledPath,
      Paint()
        ..color = Color(0xFF6366F1).withOpacity(0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Draw dots and labels
    for (int i = 0; i < count; i++) {
      final angle = -math.pi / 2 + i * angleStep;
      final r = radius * dimensions[i].score * progress;
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
      canvas.drawCircle(
        Offset(x, y),
        5,
        Paint()..color = dimensions[i].color,
      );

      // Label
      final labelRadius = radius + 16;
      final lx = center.dx + labelRadius * math.cos(angle);
      final ly = center.dy + labelRadius * math.sin(angle);
      final tp = TextPainter(
        text: TextSpan(
          text: dimensions[i].name,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 9,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(lx - tp.width / 2, ly - tp.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(_RadarChartPainter old) =>
      old.progress != progress;
}

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../services/study_vault_controller.dart';
import '../../models/study_vault_model.dart';

class StudyVaultReaderScreen extends StatefulWidget {
  final StudyVaultItem book;
  final bool isPreview;
  const StudyVaultReaderScreen({Key? key, required this.book, this.isPreview = false}) : super(key: key);

  @override
  State<StudyVaultReaderScreen> createState() => _StudyVaultReaderScreenState();
}

class _StudyVaultReaderScreenState extends State<StudyVaultReaderScreen> {
  final StudyVaultController _controller = Get.find<StudyVaultController>();

  bool _isDarkMode = true;
  double _zoomScale = 1.0;
  int _currentPage = 1;
  int _maxPages = 100;
  
  Timer? _sessionTimer;
  int _timerSeconds = 0;

  // Highlights and notes state
  final Map<int, List<String>> _pageHighlights = {};
  final Map<int, String> _pageNotes = {};
  final Set<int> _pageBookmarks = {};

  final TextEditingController _noteInputController = TextEditingController();
  final TextEditingController _jumpController = TextEditingController();

  // Selected text for highlight simulation
  String? _simulatedSelectedText;

  @override
  void initState() {
    super.initState();
    _maxPages = widget.book.pages;
    
    // Auto Resume last read page if exists
    final progress = _controller.readingProgress[widget.book.id];
    if (progress != null && !widget.isPreview) {
      _currentPage = progress.lastPageRead;
      _pageBookmarks.addAll(progress.bookmarkedPages);
      progress.highlights.forEach((k, v) {
        _pageHighlights[k] = [v];
      });
      progress.personalNotes.forEach((k, v) {
        _pageNotes[k] = v;
      });
    }

    _controller.startReadingSession(widget.book, _currentPage, isPreview: widget.isPreview);

    // Start timer for reading duration tracker
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _timerSeconds++;
      _controller.readingTimeSeconds.value = _timerSeconds.toDouble();
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    _controller.stopReadingSession();
    _noteInputController.dispose();
    _jumpController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (widget.isPreview && _currentPage >= widget.book.previewPagesCount) {
      Get.snackbar(
        'Preview Limit 🔒',
        'Purchase the full book to unlock pages past page ${widget.book.previewPagesCount}.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.amber,
        colorText: Colors.black,
      );
      return;
    }
    if (_currentPage < _maxPages) {
      setState(() {
        _currentPage++;
        _controller.activeBookPage.value = _currentPage;
      });
    }
  }

  void _prevPage() {
    if (_currentPage > 1) {
      setState(() {
        _currentPage--;
        _controller.activeBookPage.value = _currentPage;
      });
    }
  }

  void _jumpToPage() {
    final int? page = int.tryParse(_jumpController.text);
    if (page == null || page < 1 || page > _maxPages) {
      Get.snackbar('Invalid Page ❌', 'Enter a page number between 1 and $_maxPages');
      return;
    }
    if (widget.isPreview && page > widget.book.previewPagesCount) {
      Get.snackbar('Preview Limit 🔒', 'Pages past ${widget.book.previewPagesCount} are locked in preview mode.');
      return;
    }

    setState(() {
      _currentPage = page;
      _controller.activeBookPage.value = _currentPage;
      _jumpController.clear();
    });
    Get.back();
  }

  void _toggleBookmark() {
    setState(() {
      if (_pageBookmarks.contains(_currentPage)) {
        _pageBookmarks.remove(_currentPage);
        Get.snackbar('Bookmark Removed', 'Page $_currentPage unbookmarked.');
      } else {
        _pageBookmarks.add(_currentPage);
        Get.snackbar('Bookmarked 📚', 'Page $_currentPage added to bookmarks.');
      }
    });
    _controller.toggleBookmarkPage(widget.book.id, _currentPage);
  }

  void _showAddNoteDialog() {
    _noteInputController.text = _pageNotes[_currentPage] ?? '';
    Get.dialog(
      Dialog(
        backgroundColor: _isDarkMode ? const Color(0xFF13131A) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'STUDY NOTE - PAGE $_currentPage',
                style: GoogleFonts.outfit(
                  color: _isDarkMode ? Colors.white : Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteInputController,
                maxLines: 4,
                style: TextStyle(color: _isDarkMode ? Colors.white : Colors.black, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Type your handwritten notes, key formulas, or takeaways here...',
                  hintStyle: TextStyle(color: _isDarkMode ? Colors.white30 : Colors.black38),
                  fillColor: _isDarkMode ? Colors.black.withOpacity(0.2) : Colors.grey.shade100,
                  filled: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Get.back(),
                    child: Text('Cancel', style: TextStyle(color: _isDarkMode ? Colors.white38 : Colors.grey)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      final note = _noteInputController.text.trim();
                      setState(() {
                        if (note.isEmpty) {
                          _pageNotes.remove(_currentPage);
                        } else {
                          _pageNotes[_currentPage] = note;
                        }
                      });
                      _controller.saveNote(widget.book.id, _currentPage, note);
                      Get.back();
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                    child: const Text('Save Note', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  void _simulateHighlight() {
    if (_simulatedSelectedText == null) return;
    setState(() {
      if (!_pageHighlights.containsKey(_currentPage)) {
        _pageHighlights[_currentPage] = [];
      }
      _pageHighlights[_currentPage]!.add(_simulatedSelectedText!);
    });
    _controller.saveHighlight(widget.book.id, _currentPage, _simulatedSelectedText!);
    Get.snackbar(
      'Text Highlighted 🖍️',
      'Saved to your highlights deck.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.yellow.withOpacity(0.9),
      colorText: Colors.black,
    );
    _simulatedSelectedText = null;
  }

  void _simulateScreenshotAttempt() {
    Get.snackbar(
      'Screenshot Blocked 🛡️',
      'AgoraX DRM protects this document. Screenshot capturing has been disabled.',
      backgroundColor: AppTheme.errorColor.withOpacity(0.9),
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  // ── Smart AI Drawer ──
  void _showAiDrawer() {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _isDarkMode ? AppTheme.bgLight : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('🤖', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                  Text(
                    'AgoraX AI Assistant',
                    style: GoogleFonts.outfit(
                      color: _isDarkMode ? Colors.white : Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _aiToolCard('Summarize Page', 'Generate quick key summary bullet points of this page content.', () {
                Get.back();
                _showAiResponseDialog('AI Summary', _controller.generateAISummary(widget.book.id));
              }),
              _aiToolCard('Generate Flashcards', 'Extract 3 Q&A flashcards for exam review from this book.', () {
                Get.back();
                final flash = _controller.generateAIFlashcards(widget.book.id);
                _showAiResponseDialog(
                  'AI Flashcards',
                  flash.map((f) => 'Q: ${f['question']}\nA: ${f['answer']}\n').join('\n'),
                );
              }),
              _aiToolCard('Quick Quiz (MCQ)', 'Create an interactive 2-question mock test based on index.', () {
                Get.back();
                final quiz = _controller.generateAIQuiz(widget.book.id);
                _showAiQuizDialog(quiz);
              }),
              _aiToolCard('Solve Doubt', 'Ask an AI tutor questions regarding notes content.', () {
                Get.back();
                _showAiDoubtSolver();
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _aiToolCard(String title, String desc, VoidCallback onTap) {
    return Card(
      color: _isDarkMode ? AppTheme.cardBg : Colors.grey.shade100,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        title: Text(title, style: TextStyle(color: _isDarkMode ? Colors.white : Colors.black, fontSize: 13, fontWeight: FontWeight.bold)),
        subtitle: Text(desc, style: TextStyle(color: _isDarkMode ? AppTheme.textTertiary : Colors.grey.shade600, fontSize: 10.5)),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 12),
        onTap: onTap,
      ),
    );
  }

  void _showAiResponseDialog(String title, String content) {
    Get.defaultDialog(
      title: title,
      titleStyle: GoogleFonts.outfit(color: _isDarkMode ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
      backgroundColor: _isDarkMode ? AppTheme.bgLight : Colors.white,
      content: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Text(
          content,
          style: GoogleFonts.poppins(color: _isDarkMode ? AppTheme.textSecondary : Colors.black87, fontSize: 12.5, height: 1.5),
        ),
      ),
      cancel: TextButton(onPressed: () => Get.back(), child: const Text('Close')),
    );
  }

  void _showAiQuizDialog(List<Map<String, dynamic>> quiz) {
    Get.defaultDialog(
      title: 'AI Practice Quiz 📝',
      titleStyle: GoogleFonts.outfit(color: _isDarkMode ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
      backgroundColor: _isDarkMode ? AppTheme.bgLight : Colors.white,
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: quiz.length,
          itemBuilder: (context, i) {
            final q = quiz[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${i+1}. ${q['question']}', style: TextStyle(color: _isDarkMode ? Colors.white : Colors.black, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  ...(q['options'] as List<String>).asMap().entries.map((entry) {
                    final optIdx = entry.key;
                    final optText = entry.value;
                    final isCorrect = optIdx == q['answerIndex'];

                    return GestureDetector(
                      onTap: () {
                        Get.snackbar(
                          isCorrect ? 'Correct! 🎉' : 'Incorrect ❌',
                          q['explanation'],
                          snackPosition: SnackPosition.BOTTOM,
                          backgroundColor: isCorrect ? Colors.green : Colors.red,
                          colorText: Colors.white,
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _isDarkMode ? Colors.black26 : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Text(optText, style: TextStyle(color: _isDarkMode ? Colors.white70 : Colors.black87, fontSize: 11)),
                      ),
                    );
                  }).toList()
                ],
              ),
            );
          },
        ),
      ),
      cancel: TextButton(onPressed: () => Get.back(), child: const Text('Done')),
    );
  }

  void _showAiDoubtSolver() {
    final TextEditingController doubtCtrl = TextEditingController();
    Get.defaultDialog(
      title: 'AI Doubt Solver 💡',
      titleStyle: GoogleFonts.outfit(color: _isDarkMode ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
      backgroundColor: _isDarkMode ? AppTheme.bgLight : Colors.white,
      content: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            TextField(
              controller: doubtCtrl,
              maxLines: 2,
              style: TextStyle(color: _isDarkMode ? Colors.white : Colors.black, fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Type your question about this page...',
                hintStyle: TextStyle(color: _isDarkMode ? Colors.white30 : Colors.black38),
              ),
            ),
          ],
        ),
      ),
      confirm: ElevatedButton(
        onPressed: () {
          final q = doubtCtrl.text.trim();
          if (q.isEmpty) return;
          Get.back();
          _showAiResponseDialog('Doubt Resolved', _controller.solveAIDoubt(widget.book.id, q));
        },
        child: const Text('Ask AI'),
      ),
      cancel: TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeBg = _isDarkMode ? const Color(0xFF18181C) : const Color(0xFFF9F9FB);
    final themeText = _isDarkMode ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B);

    return Scaffold(
      backgroundColor: themeBg,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.book.title,
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: _isDarkMode ? Colors.white : Colors.black),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              widget.isPreview ? 'Preview Mode (Locked after pg ${widget.book.previewPagesCount})' : 'Secure Reader Active',
              style: GoogleFonts.poppins(fontSize: 10, color: widget.isPreview ? Colors.amber : AppTheme.accentColor, fontWeight: FontWeight.bold),
            )
          ],
        ),
        backgroundColor: _isDarkMode ? const Color(0xFF111115) : Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: _isDarkMode ? Colors.white : Colors.black),
          onPressed: () => Get.back(),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _pageBookmarks.contains(_currentPage) ? Icons.bookmark : Icons.bookmark_border_rounded,
              color: _pageBookmarks.contains(_currentPage) ? AppTheme.primaryColor : (_isDarkMode ? Colors.white : Colors.black),
            ),
            onPressed: _toggleBookmark,
          ),
          IconButton(
            icon: Icon(Icons.wb_sunny_outlined, color: _isDarkMode ? Colors.white : Colors.black),
            onPressed: () => setState(() => _isDarkMode = !_isDarkMode),
          ),
          IconButton(
            icon: Icon(Icons.psychology_outlined, color: _isDarkMode ? Colors.white : Colors.black),
            onPressed: _showAiDrawer,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Reader Viewport ──
            Expanded(
              child: _buildReaderViewport(themeBg, themeText),
            ),

            // ── Bottom Reader Toolbar ──
            _buildBottomToolbar(),
          ],
        ),
      ),
    );
  }

  Widget _buildReaderViewport(Color themeBg, Color themeText) {
    final double scale = _zoomScale;

    // Check if preview ends on this page
    final isPreviewLockedPage = widget.isPreview && _currentPage > widget.book.previewPagesCount;

    return InteractiveViewer(
      minScale: 0.8,
      maxScale: 3.0,
      scaleEnabled: true,
      child: Center(
        child: Container(
          width: double.infinity,
          height: double.infinity,
          padding: const EdgeInsets.all(24),
          color: themeBg,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 1. Repeating Diagonal Anti-Piracy Watermark Background Layer
              Positioned.fill(
                child: IgnorePointer(
                  child: ClipRect(
                    child: Transform.rotate(
                      angle: -pi / 6,
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 30,
                          mainAxisSpacing: 50,
                          childAspectRatio: 3.5,
                        ),
                        itemCount: 40,
                        itemBuilder: (context, i) {
                          return Opacity(
                            opacity: _isDarkMode ? 0.04 : 0.07,
                            child: Text(
                              'AgoraX • Anurag Kumar • 773091 • 10.24.8.112',
                              style: TextStyle(
                                color: _isDarkMode ? Colors.white : Colors.black,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),

              // 2. Simulated Academic Content Layer
              if (!isPreviewLockedPage)
                SingleChildScrollView(
                  child: Transform.scale(
                    scale: scale,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CHAPTER ${(_currentPage / 10).ceil()} : ADVANCED TAXONOMY',
                          style: TextStyle(
                            color: AppTheme.primaryColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Page $_currentPage / $_maxPages - Core Principles',
                          style: TextStyle(color: themeText, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        _buildSimulatedAcademicText(themeText),
                        
                        // Highlights render
                        if (_pageHighlights[_currentPage] != null) ...[
                          const SizedBox(height: 20),
                          const Text('📝 ACTIVE HIGHLIGHTS:', style: TextStyle(color: Colors.amber, fontSize: 9, fontWeight: FontWeight.bold)),
                          ..._pageHighlights[_currentPage]!.map((hl) => Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.all(6),
                            color: Colors.yellow.withOpacity(0.12),
                            child: Text(hl, style: const TextStyle(color: Colors.amber, fontSize: 11)),
                          )),
                        ],

                        // Study notes render
                        if (_pageNotes[_currentPage] != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.edit_note, color: AppTheme.primaryColor, size: 14),
                                    SizedBox(width: 6),
                                    Text('MY STUDY NOTE:', style: TextStyle(color: AppTheme.primaryColor, fontSize: 9, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(_pageNotes[_currentPage]!, style: TextStyle(color: themeText, fontSize: 11.5)),
                              ],
                            ),
                          ),
                        ]
                      ],
                    ),
                  ),
                )
              else
                // 🔒 Preview Blur Lock overlay
                _buildPreviewLockedCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSimulatedAcademicText(Color themeText) {
    // Generate text content dynamically based on category
    final category = widget.book.category.toLowerCase();
    String content = '';

    if (category.contains('coding') || category.contains('programming') || category.contains('ai')) {
      content = 'The standard algorithmic complexity for binary tree search is O(log N). '
          'We achieve this partition by comparing target credentials against parent nodes sequentially. '
          'During execution, if node value matches target SID, return true. '
          'Else, dynamically route search query either to the left child or the right child subtree.\n\n'
          'Code Snippet (Dart):\n'
          'class BinaryNode {\n'
          '  final String key;\n'
          '  BinaryNode? left, right;\n'
          '  BinaryNode(this.key);\n'
          '}';
    } else if (category.contains('upsc') || category.contains('history')) {
      content = 'The Modern Indian Nationalist movement accelerated rapidly post-1915 following the arrival of Mahatma Gandhi. '
          'The Satyagraha campaign was first piloted successfully in Champaran (Bihar) in 1917, resolving indigo farmer grievances. '
          'This established a non-violent civil disobedience protocol that was subsequently scaled to the Non-Cooperation Movement (1920) and Civil Disobedience (1930).';
    } else {
      content = 'The primary operational hypothesis requires modeling external forces as dynamic vectors. '
          'We calculate the net structural divergence by resolving tensor values across Cartesian coordinates. '
          'This mathematical proof demonstrates that under high-velocity stress, structural integrity depends directly on vector constraints and node limits.';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onLongPress: () {
            // Simulate selecting a paragraph for highlighting
            setState(() {
              _simulatedSelectedText = content.split('.')[0] + '.';
            });
            _showHighlightOptionMenu();
          },
          child: Text(
            content,
            style: GoogleFonts.poppins(color: themeText, fontSize: 13, height: 1.6),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          '(💡 Hint: Long press the paragraph to simulate text selection & highlighting)',
          style: TextStyle(color: AppTheme.textTertiary, fontSize: 10, fontStyle: FontStyle.italic),
        )
      ],
    );
  }

  void _showHighlightOptionMenu() {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(20),
        color: _isDarkMode ? AppTheme.bgLight : Colors.white,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Selected Text Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 6),
            Text(
              '"$_simulatedSelectedText"',
              style: const TextStyle(color: AppTheme.textTertiary, fontSize: 11, fontStyle: FontStyle.italic),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.border_color, color: Colors.amber),
              title: const Text('Highlight Text', style: TextStyle(fontSize: 13)),
              onTap: () {
                Get.back();
                _simulateHighlight();
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy, color: AppTheme.primaryColor),
              title: const Text('Copy Protection (Mock copy attempt)', style: TextStyle(fontSize: 13)),
              onTap: () {
                Get.back();
                Get.snackbar('Copy Blocked 🛡️', 'AgoraX secure reader prevents clipboard copying.');
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewLockedCard() {
    return Container(
      width: double.infinity,
      height: 350,
      decoration: BoxDecoration(
        color: AppTheme.cardBg.withOpacity(0.85),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.amber.withOpacity(0.5)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock_outline_rounded, color: Colors.amber, size: 48),
          const SizedBox(height: 18),
          Text(
            'Preview Limit Reached 🔒',
            style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            'You are viewing a free preview of this notes bundle (Limit: ${widget.book.previewPagesCount} pages). Purchase the complete package to unlock all ${widget.book.pages} pages.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(color: AppTheme.textSecondary, fontSize: 11.5, height: 1.5),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              Get.back(); // close reader and go back to details to purchase
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
            child: const Text('View Purchase Options', style: TextStyle(fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  Widget _buildBottomToolbar() {
    final barBg = _isDarkMode ? const Color(0xFF111115) : Colors.white;
    final barText = _isDarkMode ? Colors.white70 : Colors.black87;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: BoxDecoration(
        color: barBg,
        border: Border(top: BorderSide(color: _isDarkMode ? Colors.white10 : Colors.grey.shade200)),
      ),
      child: Column(
        children: [
          // Slider Row
          Row(
            children: [
              IconButton(icon: Icon(Icons.chevron_left, color: barText), onPressed: _prevPage),
              Expanded(
                child: Slider(
                  value: _currentPage.toDouble(),
                  min: 1,
                  max: _maxPages.toDouble(),
                  activeColor: AppTheme.primaryColor,
                  inactiveColor: _isDarkMode ? Colors.white10 : Colors.grey.shade200,
                  onChanged: (val) {
                    if (widget.isPreview && val.toInt() > widget.book.previewPagesCount) {
                      return; // locked
                    }
                    setState(() {
                      _currentPage = val.toInt();
                      _controller.activeBookPage.value = _currentPage;
                    });
                  },
                ),
              ),
              IconButton(icon: Icon(Icons.chevron_right, color: barText), onPressed: _nextPage),
            ],
          ),

          // Tools Row: Page number, reading time, note pad, anti-copy simulation
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Page jump indicator
              GestureDetector(
                onTap: () {
                  _jumpController.text = _currentPage.toString();
                  Get.defaultDialog(
                    title: 'Jump to Page',
                    backgroundColor: barBg,
                    content: TextField(
                      controller: _jumpController,
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      style: TextStyle(color: _isDarkMode ? Colors.white : Colors.black),
                    ),
                    confirm: ElevatedButton(onPressed: _jumpToPage, child: const Text('Go')),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isDarkMode ? Colors.white10 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('Pg $_currentPage / $_maxPages', style: TextStyle(color: barText, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ),

              // Reading Timer count
              Text(
                '⏱️ ${(_timerSeconds ~/ 60).toString().padLeft(2, '0')}:${(_timerSeconds % 60).toString().padLeft(2, '0')}',
                style: TextStyle(color: barText, fontSize: 11, fontWeight: FontWeight.bold),
              ),

              // Study tools
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.edit_note, color: barText, size: 20),
                    onPressed: _showAddNoteDialog,
                  ),
                  IconButton(
                    icon: Icon(Icons.zoom_in, color: barText, size: 20),
                    onPressed: () {
                      setState(() {
                        _zoomScale = min(3.0, _zoomScale + 0.2);
                      });
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.zoom_out, color: barText, size: 20),
                    onPressed: () {
                      setState(() {
                        _zoomScale = max(0.8, _zoomScale - 0.2);
                      });
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.camera_alt_outlined, color: barText, size: 20),
                    onPressed: _simulateScreenshotAttempt,
                  )
                ],
              )
            ],
          )
        ],
      ),
    );
  }
}

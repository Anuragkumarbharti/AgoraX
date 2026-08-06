import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../models/room/room_model.dart';
import '../../../../services/room/room_controller.dart';
import '../../../../services/voice/voice_controller.dart';
import '../../../../services/user/user_profile_cache_manager.dart';
import '../../../../services/user/premium_identity_controller.dart';
import '../../../../widgets/index.dart';

class RoomCallSpecialPanels extends StatelessWidget {
  final String roomId;
  final VoiceRoom room;
  final String userId;
  final String userName;
  final RxInt debateRound;
  final RxInt debateTimerSeconds;
  final RxBool isDebateTimerRunning;
  final RxInt scoreCandidateA;
  final RxInt scoreCandidateB;
  final Timer? debateTimer;
  final RxMap<String, int> quizVotes;
  final RxString quizSelectedOption;
  final RxBool quizVoted;
  final RxList<Map<String, String>> songQueue;
  final RxMap<String, int> pollVotes;
  final RxString pollSelectedOption;
  final RxBool pollVoted;
  final List<Map<String, dynamic>> seats;
  final AnimationController glowController;
  final String Function(String) getUserDp;
  final Function(int) onJoinSeat;
  final Function(int) onShowLeaveSeatMenu;
  final Function(String, String, String, int) onShowMiniProfileDialog;

  const RoomCallSpecialPanels({
    Key? key,
    required this.roomId,
    required this.room,
    required this.userId,
    required this.userName,
    required this.debateRound,
    required this.debateTimerSeconds,
    required this.isDebateTimerRunning,
    required this.scoreCandidateA,
    required this.scoreCandidateB,
    required this.debateTimer,
    required this.quizVotes,
    required this.quizSelectedOption,
    required this.quizVoted,
    required this.songQueue,
    required this.pollVotes,
    required this.pollSelectedOption,
    required this.pollVoted,
    required this.seats,
    required this.glowController,
    required this.getUserDp,
    required this.onJoinSeat,
    required this.onShowLeaveSeatMenu,
    required this.onShowMiniProfileDialog,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (room.type == 'Debate Arena' || room.type == 'Debate Room') {
      return _buildDebatePanel(context);
    } else if (room.type == 'Study Arena' || room.type == 'Study Room') {
      return _buildStudyPanel(context);
    } else if (room.type == 'Music Arena' || room.type == 'Music Room') {
      return _buildMusicPanel(context);
    } else if (room.type == 'Event Arena' || room.type == 'Event Room') {
      return _buildEventPanel(context);
    }
    return const SizedBox.shrink();
  }

  Widget _buildDebatePanel(BuildContext context) {
    final RoomController controller = RoomController.to;
    final callerRole = controller.getUserRole(room, userId);
    final isJudge = callerRole == 'Owner' ||
        callerRole == 'Co-owner' ||
        callerRole == 'Admin';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.05),
        border: Border.all(color: Colors.redAccent.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '⚖️ DEBATE MODE (Round ${debateRound.value})',
                style: GoogleFonts.poppins(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 10),
              ),
              Obx(() {
                final mins = (debateTimerSeconds.value ~/ 60)
                    .toString()
                    .padLeft(2, '0');
                final secs =
                    (debateTimerSeconds.value % 60).toString().padLeft(2, '0');
                return Text(
                  'Timer: $mins:$secs',
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 11),
                );
              }),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Column(
                children: [
                  const Text('Candidate A (Pro-AI)',
                      style: TextStyle(color: Colors.white70, fontSize: 10)),
                  Obx(() => Text('${scoreCandidateA.value} pts',
                      style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 14,
                          fontWeight: FontWeight.bold))),
                  if (isJudge)
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.add_circle,
                              color: Colors.green, size: 18),
                          onPressed: () => scoreCandidateA.value += 5,
                        ),
                        IconButton(
                          icon: const Icon(Icons.remove_circle,
                              color: Colors.red, size: 18),
                          onPressed: () => scoreCandidateA.value =
                              max(0, scoreCandidateA.value - 5),
                        ),
                      ],
                    ),
                ],
              ),
              Container(width: 1, height: 40, color: Colors.white24),
              Column(
                children: [
                  const Text('Candidate B (Anti-AI)',
                      style: TextStyle(color: Colors.white70, fontSize: 10)),
                  Obx(() => Text('${scoreCandidateB.value} pts',
                      style: const TextStyle(
                          color: Colors.blueAccent,
                          fontSize: 14,
                          fontWeight: FontWeight.bold))),
                  if (isJudge)
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.add_circle,
                              color: Colors.green, size: 18),
                          onPressed: () => scoreCandidateB.value += 5,
                        ),
                        IconButton(
                          icon: const Icon(Icons.remove_circle,
                              color: Colors.red, size: 18),
                          onPressed: () => scoreCandidateB.value =
                              max(0, scoreCandidateB.value - 5),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
          if (isJudge) ...[
            const Divider(color: Colors.white10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () {
                    if (isDebateTimerRunning.value) {
                      debateTimer?.cancel();
                      isDebateTimerRunning.value = false;
                    } else {
                      isDebateTimerRunning.value = true;
                    }
                  },
                  child: Obx(() => Text(
                      isDebateTimerRunning.value
                          ? 'Pause Timer'
                          : 'Start Timer',
                      style: const TextStyle(fontSize: 10))),
                ),
                TextButton(
                  onPressed: () {
                    debateTimerSeconds.value = 180;
                  },
                  child: const Text('Reset',
                      style: TextStyle(fontSize: 10, color: Colors.white70)),
                ),
                TextButton(
                  onPressed: () {
                    debateRound.value++;
                    debateTimerSeconds.value = 180;
                  },
                  child: const Text('Next Round',
                      style: TextStyle(fontSize: 10, color: Colors.amber)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStudyPanel(BuildContext context) {
    final RoomController controller = RoomController.to;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.tealAccent.withOpacity(0.04),
        border: Border.all(color: Colors.tealAccent.withOpacity(0.15)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.quiz, color: Colors.tealAccent, size: 14),
              const SizedBox(width: 6),
              Text(
                'STUDY HUB QUIZ',
                style: GoogleFonts.poppins(
                    color: Colors.tealAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Q: Which article deals with the amendment procedure of the Constitution of India?',
            style: TextStyle(
                color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Obx(() {
            final voted = quizVoted.value;
            final selected = quizSelectedOption.value;
            final totalVotes =
                quizVotes.values.fold<int>(0, (sum, val) => sum + val);

            Widget buildOption(String opt, String label) {
              final votesCount = quizVotes[opt] ?? 0;
              final percent = totalVotes > 0 ? (votesCount / totalVotes) : 0.0;
              final optSelected = selected == opt;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: GestureDetector(
                  onTap: voted
                      ? null
                      : () {
                          quizSelectedOption.value = opt;
                          quizVotes[opt] = votesCount + 1;
                          quizVoted.value = true;
                          controller.sendRoomMessage(roomId,
                              'voted for Option $opt in Study Quiz!',
                              senderRole: 'Student');
                        },
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: optSelected
                          ? Colors.tealAccent.withOpacity(0.2)
                          : Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color:
                              optSelected ? Colors.tealAccent : Colors.white10),
                    ),
                    child: Stack(
                      children: [
                        if (voted)
                          FractionallySizedBox(
                            widthFactor: percent,
                            child: Container(
                              height: 32,
                              decoration: BoxDecoration(
                                color: Colors.tealAccent.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(7),
                              ),
                            ),
                          ),
                        Container(
                          height: 32,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          alignment: Alignment.centerLeft,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(label,
                                  style: TextStyle(
                                      color: optSelected
                                          ? Colors.tealAccent
                                          : Colors.white,
                                      fontSize: 11)),
                              if (voted)
                                Text(
                                    '${(percent * 100).toStringAsFixed(0)}% ($votesCount votes)',
                                    style: const TextStyle(
                                        color: Colors.white54, fontSize: 9)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return Column(
              children: [
                buildOption('A', 'A: Article 356'),
                buildOption('B', 'B: Article 368'),
                buildOption('C', 'C: Article 370'),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMusicPanel(BuildContext context) {
    final RoomController controller = RoomController.to;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.pinkAccent.withOpacity(0.03),
        border: Border.all(color: Colors.pinkAccent.withOpacity(0.15)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.music_note,
                      color: Colors.pinkAccent, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    'KARAOKE SONG QUEUE',
                    style: GoogleFonts.poppins(
                        color: Colors.pinkAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 10),
                  ),
                ],
              ),
              IconButton(
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.playlist_add,
                    color: Colors.pinkAccent, size: 20),
                onPressed: () {
                  final txtController = TextEditingController();
                  Get.defaultDialog(
                    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                    title: 'Request Song',
                    titleStyle:
                        const TextStyle(color: Colors.white, fontSize: 15),
                    content: TextField(
                      controller: txtController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Enter song title & artist...',
                        hintStyle: TextStyle(color: Colors.white30),
                        enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white30)),
                      ),
                    ),
                    confirm: ElevatedButton(
                      onPressed: () {
                        if (txtController.text.trim().isNotEmpty) {
                          songQueue.add({
                            'title': txtController.text.trim(),
                            'singer': 'Singer Request',
                            'requester': userName,
                          });
                          controller.sendRoomMessage(roomId,
                              'added song "${txtController.text.trim()}" to the Karaoke queue! 🎤');
                        }
                        Get.back();
                      },
                      child: const Text('Add'),
                    ),
                    cancel: TextButton(
                        onPressed: () => Get.back(),
                        child: const Text('Cancel')),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          Obx(() {
            final count = songQueue.length;
            if (count == 0) {
              return const Text('Queue is empty! Tap + to add songs.',
                  style: TextStyle(color: Colors.white38, fontSize: 10));
            }
            return Column(
              children: songQueue.take(2).map((song) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      const Icon(Icons.play_circle_fill,
                          color: Colors.pinkAccent, size: 14),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '"${song['title']}" requested by ${song['requester']}',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 10),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          songQueue.remove(song);
                        },
                        child: const Icon(Icons.close,
                            color: Colors.white38, size: 12),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildEventPanel(BuildContext context) {
    final RoomController controller = RoomController.to;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.purpleAccent.withOpacity(0.04),
        border: Border.all(color: Colors.purpleAccent.withOpacity(0.15)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events, color: Colors.amber, size: 14),
              const SizedBox(width: 6),
              Text(
                'LIVE EVENT POLL',
                style: GoogleFonts.poppins(
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                    fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Question: Should we extend this Creator Awards session by 30 mins?',
            style: TextStyle(
                color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Obx(() {
            final voted = pollVoted.value;
            final selected = pollSelectedOption.value;
            final totalVotes =
                pollVotes.values.fold<int>(0, (sum, val) => sum + val);

            Widget buildPollOption(String opt, String label) {
              final count = pollVotes[opt] ?? 0;
              final percent = totalVotes > 0 ? (count / totalVotes) : 0.0;
              final isSel = selected == opt;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: GestureDetector(
                  onTap: voted
                      ? null
                      : () {
                          pollSelectedOption.value = opt;
                          pollVotes[opt] = count + 1;
                          pollVoted.value = true;
                          controller.sendRoomMessage(roomId,
                              'voted "$opt" in the Live Event Poll!');
                        },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSel
                          ? Colors.amber.withOpacity(0.2)
                          : Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: isSel ? Colors.amber : Colors.white10),
                    ),
                    child: Stack(
                      children: [
                        if (voted)
                          FractionallySizedBox(
                            widthFactor: percent,
                            child: Container(
                              height: 32,
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(7),
                              ),
                            ),
                          ),
                        Container(
                          height: 32,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          alignment: Alignment.centerLeft,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(label,
                                  style: TextStyle(
                                      color:
                                          isSel ? Colors.amber : Colors.white,
                                      fontSize: 11)),
                              if (voted)
                                Text(
                                    '${(percent * 100).toStringAsFixed(0)}% ($count votes)',
                                    style: const TextStyle(
                                        color: Colors.white54, fontSize: 9)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return Column(
              children: [
                buildPollOption('Yes', '🔥 Yes, keep going!'),
                buildPollOption('No', '⏰ No, let\'s wrap up.'),
              ],
            );
          }),
        ],
      ),
    );
  }

  Color _getRoleBadgeColor(String? role) {
    switch (role) {
      case 'Host':
        return const Color(0xFFFF9500);
      case 'Co-Host':
        return const Color(0xFFAF52DE);
      case 'Speaker':
        return const Color(0xFF007AFF);
      default:
        return Colors.white54;
    }
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../models/community/post_model.dart';
import '../../widgets/post_creation/instagram_mini_post_preview.dart';

class PostEventService extends GetxController {
  static PostEventService get to {
    if (!Get.isRegistered<PostEventService>()) {
      return Get.put(PostEventService());
    }
    return Get.find<PostEventService>();
  }

  final StreamController<Post> _postCreatedController = StreamController<Post>.broadcast();

  /// Stream of newly created posts for active feeds to listen to
  Stream<Post> get onPostCreated => _postCreatedController.stream;

  /// Notify all feed listeners of a newly created post and show the mini preview toast overlay
  void notifyPostCreated(Post post, {BuildContext? context}) {
    // 1. Broadcast event to feeds to prepend at index 0
    _postCreatedController.add(post);

    // 2. Display Instagram-style floating mini confirmation prompt
    InstagramMiniPostPreview.show(
      context: context ?? Get.context,
      post: post,
    );
  }

  @override
  void onClose() {
    _postCreatedController.close();
    super.onClose();
  }
}

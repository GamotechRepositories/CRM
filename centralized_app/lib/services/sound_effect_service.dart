import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class SoundEffectService {
  SoundEffectService._();
  static final SoundEffectService instance = SoundEffectService._();

  final AudioPlayer _player = AudioPlayer();

  Future<void> playTaskApproval() async {
    try {
      await _player.stop();
      await _player.play(AssetSource('sounds/task_approval.mp3'));
    } catch (e) {
      debugPrint('Failed to play task_approval sound: $e');
    }
  }

  Future<void> playTaskSucceed() async {
    try {
      await _player.stop();
      await _player.play(AssetSource('sounds/task_succeed.mp3'));
    } catch (e) {
      debugPrint('Failed to play task_succeed sound: $e');
    }
  }

  Future<void> playTaskRejected() async {
    try {
      await _player.stop();
      await _player.play(AssetSource('sounds/task_rejected.mp3'));
    } catch (e) {
      debugPrint('Failed to play task_rejected sound: $e');
    }
  }
}

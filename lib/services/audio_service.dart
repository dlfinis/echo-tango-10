/// Audio facade for the kiosk. Plays verdict sound effects on a pulse
/// or a result transition. The actual `.wav` files live under
/// `assets/sounds/` — sourced from "Retro game sound effects" by
/// Vircon32 (Carra), CC-BY 4.0, https://opengameart.org/content/
/// retro-game-sound-effects. Background music from SubspaceAudio
/// (Juhani Junkala), CC0, https://opengameart.org/content/5-chiptunes-action.
///
/// **Asset behaviour**: if an asset is missing, the play call logs a
/// debugPrint warning and continues silently. The kiosk works without
/// any audio files present — every play call is best-effort.
library;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// One [AudioPlayer] per effect keeps state independent (an effect
/// that just finished should not interfere with one about to start).
class AudioService {
  AudioService();

  final AudioPlayer _pulse = AudioPlayer();
  final AudioPlayer _victory = AudioPlayer();
  final AudioPlayer _casi = AudioPlayer();
  final AudioPlayer _niPorAsomo = AudioPlayer();
  final AudioPlayer _tePasaste = AudioPlayer();
  final AudioPlayer _waiting = AudioPlayer();
  final AudioPlayer _gameplay = AudioPlayer();

  bool _preloaded = false;

  /// Loads the five effect sources. Idempotent — a second call is a
  /// no-op so callers don't have to track lifecycle.
  Future<void> preload() async {
    if (_preloaded) return;
    _preloaded = true;
    await Future.wait(<Future<void>>[
      _safeSetSource(_pulse, 'sounds/pulse.wav'),
      _safeSetSource(_victory, 'sounds/victory.wav'),
      _safeSetSource(_casi, 'sounds/casi.wav'),
      _safeSetSource(_niPorAsomo, 'sounds/ni_por_asomo.wav'),
      _safeSetSource(_tePasaste, 'sounds/te_pasaste.wav'),
      _safeSetSource(_waiting, 'sounds/waiting_loop.wav'),
      _safeSetSource(_gameplay, 'sounds/gameplay_loop.wav'),
    ]);
  }

  Future<void> _safeSetSource(AudioPlayer player, String asset) async {
    try {
      await player.setSource(AssetSource(asset));
    } on Object catch (e) {
      debugPrint('AudioService: missing or unreadable asset "$asset": $e');
    }
  }

  Future<void> playPulse() => _safePlay(_pulse);
  Future<void> playVictory() => _safePlay(_victory);
  Future<void> playCasi() => _safePlay(_casi);
  Future<void> playNiPorAsomo() => _safePlay(_niPorAsomo);
  Future<void> playTePasaste() => _safePlay(_tePasaste);

  Future<void> _safePlay(AudioPlayer player) async {
    try {
      await player.stop();
      await player.resume();
    } on Object catch (e) {
      debugPrint('AudioService: play failed: $e');
    }
  }

  /// Starts the waiting-screen music loop. Idempotent.
  Future<void> startWaitingMusic() async {
    try {
      if (_waiting.state != PlayerState.playing) {
        _waiting.setReleaseMode(ReleaseMode.loop);
        await _waiting.resume();
      }
    } on Object catch (e) {
      debugPrint('AudioService: waiting music failed: $e');
    }
  }

  /// Switches from waiting music to gameplay music. Stops the waiting
  /// loop and starts the gameplay loop from the beginning.
  Future<void> switchToGameplayMusic() async {
    try {
      await _waiting.stop();
      _gameplay.setReleaseMode(ReleaseMode.loop);
      await _gameplay.resume();
    } on Object catch (e) {
      debugPrint('AudioService: switch to gameplay failed: $e');
    }
  }

  /// Stops all background music.
  Future<void> stopMusic() async {
    try {
      await _waiting.stop();
      await _gameplay.stop();
    } on Object catch (e) {
      debugPrint('AudioService: stop music failed: $e');
    }
  }

  /// Sets the music volume (0.0 to 1.0) for both waiting and gameplay
  /// players. Does not affect sound effects (pulse, victory, etc.).
  void setMusicVolume(double volume) {
    final double v = volume.clamp(0.0, 1.0);
    _waiting.setVolume(v);
    _gameplay.setVolume(v);
  }

  Future<void> dispose() async {
    await Future.wait(<Future<void>>[
      _pulse.dispose(),
      _victory.dispose(),
      _casi.dispose(),
      _niPorAsomo.dispose(),
      _tePasaste.dispose(),
      _waiting.dispose(),
      _gameplay.dispose(),
    ]);
  }
}

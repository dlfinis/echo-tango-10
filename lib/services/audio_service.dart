/// Audio facade for the kiosk. Plays verdict sound effects on a pulse
/// or a result transition. The actual `.wav` files live under
/// `assets/sounds/` — sourced from "Retro game sound effects" by
/// Vircon32 (Carra), CC-BY 4.0, https://opengameart.org/content/
/// retro-game-sound-effects.
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
      await player.resume();
    } on Object catch (e) {
      debugPrint('AudioService: play failed: $e');
    }
  }

  Future<void> startGameplayMusic() async {
    try {
      await _gameplay.setSource(AssetSource('sounds/gameplay_loop.wav'));
      _gameplay.setReleaseMode(ReleaseMode.loop);
      await _gameplay.resume();
    } on Object catch (e) {
      debugPrint('AudioService: gameplay music failed: $e');
    }
  }

  Future<void> stopGameplayMusic() async {
    try {
      await _gameplay.stop();
    } on Object catch (e) {
      debugPrint('AudioService: stop gameplay failed: $e');
    }
  }

  Future<void> dispose() async {
    await Future.wait(<Future<void>>[
      _pulse.dispose(),
      _victory.dispose(),
      _casi.dispose(),
      _niPorAsomo.dispose(),
      _tePasaste.dispose(),
      _gameplay.dispose(),
    ]);
  }
}

/// Audio facade for the kiosk. Plays verdict sound effects on a pulse
/// or a result transition. The actual `.mp3` files live under
/// `assets/sounds/` — the operator is expected to drop them there
/// before deploying the kiosk.
///
/// **Asset behaviour**: if an asset is missing, the play call logs a
/// debugPrint warning and continues silently. This is intentional —
/// the audio service is a STUB until the operator provides real
/// sound files. The kiosk works without any audio files present.
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

  bool _preloaded = false;

  /// Loads the five effect sources. Idempotent — a second call is a
  /// no-op so callers don't have to track lifecycle.
  Future<void> preload() async {
    if (_preloaded) return;
    _preloaded = true;
    await Future.wait(<Future<void>>[
      _safeSetSource(_pulse, 'sounds/pulse.mp3'),
      _safeSetSource(_victory, 'sounds/victory.mp3'),
      _safeSetSource(_casi, 'sounds/casi.mp3'),
      _safeSetSource(_niPorAsomo, 'sounds/ni_por_asomo.mp3'),
      _safeSetSource(_tePasaste, 'sounds/te_pasaste.mp3'),
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

  Future<void> dispose() async {
    await Future.wait(<Future<void>>[
      _pulse.dispose(),
      _victory.dispose(),
      _casi.dispose(),
      _niPorAsomo.dispose(),
      _tePasaste.dispose(),
    ]);
  }
}

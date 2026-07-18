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

/// Small seam around audioplayers so playback configuration is testable
/// without a platform audio backend.
abstract interface class AudioPlayerHandle {
  PlayerState get state;

  Future<void> setPlayerMode(PlayerMode playerMode);
  Future<void> setReleaseMode(ReleaseMode releaseMode);
  Future<void> setSource(String asset);
  Future<void> setVolume(double volume);
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<void> resume();
  Future<void> dispose();
}

typedef AudioPlayerFactory = AudioPlayerHandle Function();

class _AudioplayersHandle implements AudioPlayerHandle {
  _AudioplayersHandle() : _player = AudioPlayer();

  final AudioPlayer _player;

  @override
  PlayerState get state => _player.state;

  @override
  Future<void> setPlayerMode(PlayerMode playerMode) =>
      _player.setPlayerMode(playerMode);

  @override
  Future<void> setReleaseMode(ReleaseMode releaseMode) =>
      _player.setReleaseMode(releaseMode);

  @override
  Future<void> setSource(String asset) => _player.setSource(AssetSource(asset));

  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume);

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> resume() => _player.resume();

  @override
  Future<void> dispose() => _player.dispose();
}

/// One [AudioPlayer] per effect keeps state independent (an effect
/// that just finished should not interfere with one about to start).
class AudioService {
  AudioService({AudioPlayerFactory? playerFactory})
      : _playerFactory = playerFactory ?? _defaultPlayerFactory;

  static AudioPlayerHandle _defaultPlayerFactory() => _AudioplayersHandle();

  final AudioPlayerFactory _playerFactory;

  late final AudioPlayerHandle _pulse = _playerFactory();
  late final AudioPlayerHandle _victory = _playerFactory();
  late final AudioPlayerHandle _casi = _playerFactory();
  late final AudioPlayerHandle _niPorAsomo = _playerFactory();
  late final AudioPlayerHandle _tePasaste = _playerFactory();
  late final AudioPlayerHandle _waiting = _playerFactory();
  late final AudioPlayerHandle _gameplay = _playerFactory();

  bool _preloaded = false;
  bool _gameplayWarmed = false;
  bool _gameplayMuted = false;
  double _musicVolume = 1.0;

  /// Loads the five effect sources. Idempotent — a second call is a
  /// no-op so callers don't have to track lifecycle.
  Future<void> preload() async {
    if (_preloaded) return;
    _preloaded = true;
    await Future.wait(<Future<void>>[
      _configureSfx(_pulse, 'sounds/pulse.wav', volume: 0.65),
      _configureSfx(_victory, 'sounds/victory.wav', volume: 1.0),
      _configureSfx(_casi, 'sounds/casi.wav', volume: 0.65),
      _configureSfx(_niPorAsomo, 'sounds/ni_por_asomo.wav', volume: 0.65),
      _configureSfx(_tePasaste, 'sounds/te_pasaste.wav', volume: 0.65),
      _configureMusic(_waiting, 'sounds/waiting_loop.wav'),
      _configureMusic(_gameplay, 'sounds/gameplay_loop.wav'),
    ]);
  }

  /// `ReleaseMode.stop` retains the native source after natural completion,
  /// unlike the default `release` mode. This lets every SFX replay safely.
  Future<void> _configureSfx(
    AudioPlayerHandle player,
    String asset, {
    double volume = 1.0,
  }) async {
    await _safeConfigure(
      player.setPlayerMode(PlayerMode.lowLatency),
      'configure low-latency mode for $asset',
    );
    await _safeConfigure(
      player.setReleaseMode(ReleaseMode.stop),
      'configure stop release mode for $asset',
    );
    await _safeConfigure(
      player.setVolume(volume),
      'configure volume for $asset',
    );
    await _safeConfigure(player.setSource(asset), 'load asset $asset');
  }

  Future<void> _configureMusic(AudioPlayerHandle player, String asset) async {
    await _safeConfigure(
      player.setPlayerMode(PlayerMode.mediaPlayer),
      'configure media player mode for $asset',
    );
    await _safeConfigure(
      player.setReleaseMode(ReleaseMode.loop),
      'configure loop release mode for $asset',
    );
    await _safeConfigure(player.setSource(asset), 'load asset $asset');
  }

  Future<bool> _safeConfigure(Future<void> operation, String description) async {
    try {
      await operation;
      return true;
    } on Object catch (e) {
      debugPrint('AudioService: failed to $description: $e');
      return false;
    }
  }

  Future<void> playPulse() => _safePlay(_pulse);
  Future<void> playVictory() => _safePlay(_victory);
  Future<void> playCasi() => _safePlay(_casi);
  Future<void> playNiPorAsomo() => _safePlay(_niPorAsomo);
  Future<void> playTePasaste() => _safePlay(_tePasaste);

  Future<void> _safePlay(AudioPlayerHandle player) async {
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
        await _waiting.resume();
      }
    } on Object catch (e) {
      debugPrint('AudioService: waiting music failed: $e');
    }
  }

  /// Starts the gameplay path muted while WAITING so Android opens its audio
  /// output before the first game. It remains muted until PLAYING begins.
  Future<void> warmGameplayMusic() async {
    if (_gameplayWarmed) return;
    try {
      await _gameplay.setVolume(0.0);
      await _gameplay.resume();
      _gameplayWarmed = true;
      _gameplayMuted = true;
    } on Object catch (e) {
      debugPrint('AudioService: gameplay warmup failed: $e');
    }
  }

  /// Switches from waiting music to gameplay music at the loop start.
  /// The warmed route is explicitly rewound before its configured volume is
  /// restored, so warmup position never leaks into gameplay.
  Future<void> switchToGameplayMusic() async {
    try {
      await _gameplay.stop();
      await _gameplay.seek(Duration.zero);
      await _gameplay.setVolume(0.0);
      await _gameplay.resume();
      await _waiting.stop();
      await _gameplay.setVolume(_musicVolume);
      _gameplayMuted = false;
    } on Object catch (e) {
      _gameplayMuted = true;
      try {
        await _gameplay.stop();
      } on Object {
        // Best-effort rollback — we prefer a logged warmup failure over
        // leaving the player half-switched.
      }
      try {
        if (_waiting.state != PlayerState.playing) {
          await _waiting.resume();
        }
      } on Object {
        // Waiting music restart is best-effort only.
      }
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

  /// Sets the desired music volume (0.0 to 1.0). A warmed gameplay route
  /// stays muted until PLAYING begins. Does not affect sound effects.
  Future<void> setMusicVolume(double volume) async {
    _musicVolume = volume.clamp(0.0, 1.0);
    try {
      await Future.wait(<Future<void>>[
        _waiting.setVolume(_musicVolume),
        _gameplay.setVolume(_gameplayMuted ? 0.0 : _musicVolume),
      ], eagerError: false);
    } on Object catch (e) {
      debugPrint('AudioService: set music volume failed: $e');
    }
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

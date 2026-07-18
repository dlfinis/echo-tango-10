import 'package:arcade_timer_10s/services/audio_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakePlayer implements AudioPlayerHandle {
  final List<String> calls = <String>[];
  PlayerState _state = PlayerState.stopped;

  void completeNaturally() {
    _state = PlayerState.completed;
  }

  @override
  PlayerState get state => _state;

  @override
  Future<void> setPlayerMode(PlayerMode playerMode) async {
    calls.add('mode:$playerMode');
  }

  @override
  Future<void> dispose() async {
    calls.add('dispose');
  }

  @override
  Future<void> resume() async {
    calls.add('resume');
    _state = PlayerState.playing;
  }

  @override
  Future<void> setReleaseMode(ReleaseMode releaseMode) async {
    calls.add('release:$releaseMode');
  }

  @override
  Future<void> setSource(String asset) async {
    calls.add('source:$asset');
  }

  @override
  Future<void> setVolume(double volume) async {
    calls.add('volume:$volume');
  }

  @override
  Future<void> stop() async {
    calls.add('stop');
    _state = PlayerState.stopped;
  }

  @override
  Future<void> seek(Duration position) async {
    calls.add('seek:$position');
  }
}

void main() {
  group('AudioService', () {
    test('configures modes before sources and keeps SFX replayable', () async {
      final List<_FakePlayer> players = <_FakePlayer>[];
      final AudioService service = AudioService(playerFactory: () {
        final _FakePlayer player = _FakePlayer();
        players.add(player);
        return player;
      });

      await service.preload();

      for (final _FakePlayer sfx in players.take(5)) {
        expect(sfx.calls, contains('mode:PlayerMode.lowLatency'));
        expect(sfx.calls, contains('release:ReleaseMode.stop'));
        expect(sfx.calls, isNot(contains('release:ReleaseMode.release')));
        expect(
          sfx.calls.indexOf('mode:PlayerMode.lowLatency'),
          lessThan(sfx.calls
              .indexWhere((String call) => call.startsWith('source:'))),
        );
      }
      for (final _FakePlayer music in players.skip(5)) {
        expect(music.calls, contains('mode:PlayerMode.mediaPlayer'));
        expect(music.calls, contains('release:ReleaseMode.loop'));
        expect(
          music.calls.indexOf('mode:PlayerMode.mediaPlayer'),
          lessThan(music.calls
              .indexWhere((String call) => call.startsWith('source:'))),
        );
      }
      expect(players[1].calls, contains('volume:1.0'));
      expect(players[0].calls, contains('volume:0.65'));
      expect(players[2].calls, contains('volume:0.65'));

      // Simulate a natural completion: ReleaseMode.stop preserves the source,
      // so the next call can stop at zero and resume the same native source.
      await service.playVictory();
      players[1].completeNaturally();
      await service.playVictory();
      expect(players[1].calls.where((String call) => call == 'stop'),
          hasLength(2));
      expect(players[1].calls.where((String call) => call == 'resume'),
          hasLength(2));
      expect(
          players[1].calls.where((String call) => call.startsWith('source:')),
          hasLength(1));
    });

    test('keeps warmed gameplay muted when admin changes music volume',
        () async {
      final List<_FakePlayer> players = <_FakePlayer>[];
      final AudioService service = AudioService(playerFactory: () {
        final _FakePlayer player = _FakePlayer();
        players.add(player);
        return player;
      });

      await service.preload();
      await service.warmGameplayMusic();
      await service.setMusicVolume(0.4);

      final _FakePlayer gameplay = players[6];
      expect(gameplay.calls.where((String call) => call == 'volume:0.0'),
          hasLength(2));
      expect(gameplay.calls, isNot(contains('volume:0.4')));
    });

    test('warms gameplay muted and restarts it at the loop start', () async {
      final List<_FakePlayer> players = <_FakePlayer>[];
      final AudioService service = AudioService(playerFactory: () {
        final _FakePlayer player = _FakePlayer();
        players.add(player);
        return player;
      });

      await service.preload();
      await service.setMusicVolume(0.4);
      await service.startWaitingMusic();
      await service.warmGameplayMusic();

      final _FakePlayer waiting = players[5];
      final _FakePlayer gameplay = players[6];
      expect(
          gameplay.calls,
          containsAllInOrder(<String>[
            'volume:0.4',
            'volume:0.0',
            'resume',
          ]));
      expect(
        gameplay.calls.where((String call) => call.startsWith('source:')),
        hasLength(1),
      );

      await service.switchToGameplayMusic();

      expect(waiting.calls, contains('stop'));
      expect(
          gameplay.calls,
          containsAllInOrder(<String>[
            'volume:0.0',
            'resume',
            'stop',
            'seek:0:00:00.000000',
            'volume:0.0',
            'resume',
            'volume:0.4',
          ]));
    });

    test('continues preloading when an asset cannot be configured', () async {
      final AudioService service =
          AudioService(playerFactory: _ThrowingPlayer.new);

      await expectLater(service.preload(), completes);
    });
  });
}

class _ThrowingPlayer extends _FakePlayer {
  @override
  Future<void> setSource(String asset) =>
      Future<void>.error(StateError('missing $asset'));
}

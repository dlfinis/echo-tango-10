/// Application state machine for the Arcade Timer 10s kiosk.
///
/// 5 mutually-exclusive states; the orchestrator widget transitions by
/// calling the pure [next] function with the current state and a
/// [TimerEvent]. Persistence, side effects, and IO are deliberately
/// kept OUT of this file so [next] can be unit-tested in isolation.
library;

/// High-level application states.
///
/// * [waiting]   — invitation loop is running, listening for a pulse.
/// * [playing]   — stopwatch is running, single pulse will stop it.
/// * [result]    — final time + delta displayed, pulse to advance.
/// * [winnerName]— victory branch (delta < tolerance), touch keyboard up.
/// * [admin]     — admin panel open, invitation loop paused.
enum AppState { waiting, playing, result, winnerName, admin }

/// Events that can drive a state transition.
///
/// `victory` carries [isVictory] so the state machine does not need to
/// know the actual delta value — the caller (which has the result data)
/// makes the judgment and feeds it in.
enum TimerEvent {
  pulse,
  timeout,
  adminGesture,
  exitAdmin,
  acceptWinner,
}

/// Computes the next [AppState] from a [current] state and a [TimerEvent].
///
/// This function is PURE: no IO, no time, no side effects. All side
/// effects (start/stop/reset, confetti, persistence) are the caller's
/// responsibility once the next state is known.
///
/// Per spec requirement 1:
///   * WAITING  + pulse     → PLAYING
///   * PLAYING  + pulse     → RESULT
///   * PLAYING  + timeout   → WAITING  (60s guard)
///   * RESULT   + pulse     → WINNER_NAME (when [isVictory]=true)
///                          → WAITING    (otherwise)
///   * WAITING  + admin     → ADMIN
///   * ADMIN    + exitAdmin → WAITING
///   * WINNER_NAME + acceptWinner → WAITING
AppState next(
  AppState current,
  TimerEvent event, {
  bool isVictory = false,
}) {
  switch (current) {
    case AppState.waiting:
      if (event == TimerEvent.pulse) return AppState.playing;
      if (event == TimerEvent.adminGesture) return AppState.admin;
      return current; // ignore other events while waiting

    case AppState.playing:
      if (event == TimerEvent.pulse) return AppState.result;
      if (event == TimerEvent.timeout) return AppState.waiting;
      return current; // ignore admin/etc. while playing

    case AppState.result:
      if (event == TimerEvent.pulse) {
        return isVictory ? AppState.winnerName : AppState.waiting;
      }
      return current;

    case AppState.winnerName:
      if (event == TimerEvent.acceptWinner) return AppState.waiting;
      // any pulse from input is ignored until "Aceptar" is pressed
      return current;

    case AppState.admin:
      if (event == TimerEvent.exitAdmin) return AppState.waiting;
      return current;
  }
}

// ---------------------------------------------------------------------------
// Branch-level assertions (informal — exercise via unit tests in PR2).
//
//   next(waiting, pulse)        == playing       // start game
//   next(playing, pulse)        == result        // stop timing
//   next(result,  pulse, isVictory: false) == waiting        // miss
//   next(result,  pulse, isVictory: true)  == winnerName     // hit
//   next(playing, timeout)      == waiting       // 60s guard
//   next(waiting, adminGesture) == admin         // open admin
//   next(admin,   exitAdmin)    == waiting       // close admin
//   next(winnerName, acceptWinner) == waiting    // saved, reset
// ---------------------------------------------------------------------------

# arcade_timer_10s

Kiosk game for a Colombian fair / World Cup season. The player
presses a physical button (Arduino USB Serial on Android, Space on
Web) to start a stopwatch, then presses again to stop it. The
closer the elapsed time is to exactly **10.000 seconds**, the
better the score. Victories enter the top-10 leaderboard with the
player's typed name.

## Two swappable themes

The kiosk ships with a theme abstraction. The active theme owns
copy, colors, and the waiting-screen / result-screen painters.

| id | Display name | Default |
|---|---|---|
| `worldcup` | Selección Colombia | ✅ |
| `classic` | Arcade Clásico | |

The operator switches themes from the admin panel (`Administrar →
Tema activo`). The change applies on the next frame, no restart.

For details on the theme contract and how to add a new theme, see
[`docs/THEMES.md`](docs/THEMES.md). For the operator-facing
manual in Spanish, see [`docs/MANUAL_OPERADOR.md`](docs/MANUAL_OPERADOR.md).

## Hardware

- **Android** (Fire HD 8 production target): Arduino sends a
  single `0x01` byte per press over USB CDC-ACM at 9600 8N1.
  200 ms debounce in software.
- **Web** (dev only): Space key, or Web Serial picker via the
  admin "Connect" button.

## Build

```sh
fvm use 3.44.1
fvm flutter pub get
fvm flutter test
fvm flutter run                 # debug, picks the host platform
fvm flutter build apk --debug   # production tablet build
fvm flutter build web           # web dev build
```

## Releases

| Tag | Notes |
|---|---|
| `v0.1.0-arcade` | Pre-tema-futbol-colombia. Single theme, copy and constants baked in. Use this tag to roll back. |
| `v0.2.0-themes` | Theme abstraction + `classic` + `worldcup` shipped. |

# Audio direction: "Event Frame"

## Concept

The art is one frame of bubble-chamber film on a scanning table, so the sound is the lab
around it: a magnet hum, the tick of the film transport, cold glass tones. Particles
write their tracks in **bubbles**, so the musical motif is a *bubble track*: a run of
glass notes spiralling down a chord, with gaps that shrink as it goes, the way a slowing
particle leaves denser bubbles. The art's amber marks what is live; in sound, only live
events (launch, wall hit, goal) are bright and pitched. Static UI is a dry tick.

Everything is synthesized in code (`tools/audio/`, numpy/scipy). No samples, soundfonts
or packs. Rebuild with `python3 tools/audio/build.py` (about 3 minutes, mostly reverb).

## Harmony and timbre

- Mode: **D Dorian** throughout (D E F G A B C). Cool, unresolved, not sad.
- Drone: D2 sine with fifth and octave, breathing slowly (whole LFO cycles per loop).
- Pads: three detuned sines per note, slow attack, no saws; chords Dm9, Fmaj7, G6/9,
  Em7, Cmaj9, Bm7b5, A7sus4.
- Bubbles: two-operator FM bells (ratio 3.5), short decay, panned along a drift.
- Film transport: band-passed noise click (2.5-6.5 kHz) on the beat, accent on beat 1.
- Room: Freeverb-style reverb, wet only on the music. SFX are dry.

## Tracks

| File | Use | Tempo / metre | Length | Loudness | Cue |
|---|---|---|---|---|---|
| `audio/music/scanning_table.mp3` | Title screen | 60 BPM, 4/4, 16 bars | 64.0 s | -18 LUFS | Drone and four-bar pads (Dm9, Fmaj7, Em7, A7sus4). One glass note per bar on the slow motif D A C E D A F G. A bubble track spirals down on bar 3 of each chord. The tick falls on every other beat. Nothing pulses; the table is idle. |
| `audio/music/exposure.mp3` | During play and result | 90 BPM, 4/4, 32 bars | 85.3 s | -18 LUFS | Bars 1-8: drone, pads changing every two bars, a bubble track every two bars, tick on every beat. Bars 9-24: a soft eighth-note bass pulse on the chord roots (accents on 1, the "and" of 2, and 4) and denser bubble tracks with stray single bubbles. Bars 25-32: the bass stops at bar 28 and the tracks thin back to the opening, so the loop restarts naturally. |

On the result screen the music sinks 9 dB over 1.2 s, matching the level powering down to
grey. Replay brings it back. Title to play is a 1.2 s crossfade.

Both loops are rendered into a buffer of exactly the loop length. Note tails and the
reverb wrap round to the start, so the end flows into the beginning (seam step 0.016
against a 99.9th percentile step of 0.14). The MP3s are LAME CBR 128 kbps with the
gapless header, and the Godot import sets `loop=true`.

## Sound effects

All are 16-bit mono WAV, dry, peaks at or below -1.5 dBFS.

| Event | File | Length | Peak | Sound |
|---|---|---|---|---|
| Ball launched | `launch.wav` | 0.32 s | -2 dB | Latch click and a particle chirp rising from 330 Hz to about 1 kHz. |
| Ball hits a wall | `wall_hit.wav` | 0.42 s | -3 dB | Struck glass (FM bell on D5) with a tiny tick. In game the pitch steps up D Dorian with the wall multiplier (x1.2 = D, x2.0 = A, x2.2 = B, x2.4 = C) and one degree per doubling of speed above 400 px/s (up to 3). Faster hits are up to 6 dB louder. |
| Ball boils through a zone | `fizz.wav` | 0.60 s | -5 dB | About 26 tiny rising bubble pops over a hiss that swells and falls. Plays on entry and every 0.5 s while a moving ball is inside. |
| Ball scores in the goal | `goal.wav` | 0.90 s | -2 dB | Camera shutter (two clicks) and an amber rising fifth, D5 to A5. |
| Out of balls (lose) | `out_of_balls.wav` | 1.30 s | -2 dB | The chamber powers down: a falling sine and a magnet hum that sags and dies. |
| Target met (win) | `target_met.wav` | 1.90 s | -1.5 dB | Shutter, a glass arpeggio up Dm9 (D F A C E), then a held D/A fifth. |
| Start round / replay | `ui_confirm.wav` | 0.20 s | -6 dB | Two rising ticks, A5 to D6. |
| Language or sound toggle, M | `ui_click.wav` | 0.03 s | -8 dB | Dry key tick with a faint 1.76 kHz tone. |
| Hover over a wall | `ui_hover.wav` | 0.02 s | -15 dB | Lighter, higher tick. |
| Wall turned one step | `rotate.wav` | 0.02 s | -14 dB | Ratchet tick (slightly lower when turning back). |
| Space with no balls left | `empty.wav` | 0.05 s | -6 dB | Dull dry fire. |

Repeats are rate-limited per sound (wall hit 40 ms, fizz 250 ms, rotate 35 ms, hover 80 ms).

## Runtime

- Buses (`default_bus_layout.tres`): Master, Music (-3 dB), SFX.
- `scripts/Audio.gd` is the `Audio` autoload. It provides a 10-voice SFX pool, two music
  players for crossfades, `play()`, `play_wall_hit()`, `play_music()` and
  `duck_music()`. It also owns the master volume.
- Volume: the HUD label at the top right ("Sound ●●○") steps the volume down 3, 2, 1,
  off and back to 3 when clicked. `M` toggles mute. The level is saved in
  `user://settings.cfg` under `[audio]`. The default is 2 of 3.
- On the web the AudioContext starts on the first click or key press (the title screen
  needs one anyway).

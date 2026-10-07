# Audio direction: "Event Frame"

## Concept

The art is one frame of bubble-chamber film on a scanning table, so the sound is the lab
around it: a magnet hum, the tick of the film transport, cold glass tones. Particles
write their tracks in **bubbles**, so the musical motif is a *bubble track*: a run of
glass notes spiralling down a chord, with gaps that shrink as it goes, the way a slowing
particle leaves denser bubbles. The art's amber marks what is live; in sound, only live
events (launch, wall hit, goal) are bright and pitched. Static UI is a dry tick.

Music and SFX are composed programmatically by AI (Claude) and rendered offline with the
Vital and Serum 2 synthesizers, the MuseScore "MS Basic" General MIDI soundfont (via
fluidsynth) and numpy synthesis, mixed with pedalboard's built-in effects. No sample packs.
`tools/audio/compose.py` writes the MIDI and render specs, `tools/audio/sfx.py` layers the
effects, and `tools/audio/build.py` renders everything (see "Rebuild" below).

## Harmony and timbre

- Mode: **D Dorian** throughout (D E F G A B C). Cool, unresolved, not sad.
- Pad: Serum 2 "PD - Dark Space" holding Dm9, Fmaj7, G6/9, Em7, Cmaj9, Bm7b5, A7sus4.
- Drone: Vital "Analog Pad" (In The Mix) on the chord roots, octave 2.
- Glass motif: Vital "Crescendo Bells" (Level 8), swelling one note at a time.
- Bubble tracks: Serum 2 "BL - Kinderjoy" (low-passed) doubled by a quiet numpy FM bell.
- Film transport tick: Vital "Ceramic" (Databroth) on the beat, accent on beat 1.
- In play: Serum 2 "BA - Club - Muted" eighth-note bass pulse, a soft MS Basic GM kit
  (kick, side stick, closed hat) and a Serum 2 "SY - Tetris" glide lead.
- Room: pedalboard Reverb per part; a gentle master compressor and 12 kHz low-pass.

## Tracks

| File | Use | Tempo / metre | Length | Loudness | Cue |
|---|---|---|---|---|---|
| `audio/music/scanning_table.mp3` | Title screen | 60 BPM, 4/4, 16 bars | 64.0 s | -18 LUFS | Dark Space pad and Analog Pad drone in four-bar chords (Dm9, Fmaj7, Em7, A7sus4). One Crescendo Bells note per bar on the slow motif D A C E D A F G. A Kinderjoy bubble track spirals down on bar 3 of each chord. The Ceramic tick falls on every other beat. Nothing pulses; the table is idle. |
| `audio/music/exposure.mp3` | During play and result | 90 BPM, 4/4, 32 bars | 85.3 s | -18 LUFS | A (bars 1-8): pad and drone changing every two bars, Crescendo Bells glass notes, a bubble track every two bars, tick on every beat. B (9-16): a muted eighth-note bass pulse on the chord roots (accents on 1, the "and" of 2, and 4) and a soft GM kit; denser bubble tracks. C (17-24): a Tetris glide lead phrase over Dm9 Fmaj7 G6/9 Em7. D (25-32): kick and stick drop at 25, bass and hats stop at 28, the glass notes return, so the loop restarts naturally. |

On the result screen the music sinks 9 dB over 1.2 s, matching the level powering down to
grey. Replay brings it back. Title to play is a 1.2 s crossfade.

Both loops are rendered with audiokit's loop option: everything past the loop end (note
tails, reverb) is folded back onto the start, so the end flows into the beginning (seam
jump below 0.005 against a 99th-percentile step of about 0.03). The MP3s are LAME CBR
128 kbps with the gapless header, and the Godot import sets `loop=true`.

## Sound effects

All are 16-bit mono WAV, dry, DC-free, peaks at or below -1 dBFS. Each one layers at least
two sources: single notes rendered from Serum 2 Kinderjoy (glass), Vital Ceramic (ticks,
shutter, rising runs), Vital Super Nice Pluck (sub thuds) and Vital Crescendo Bells (held
chime), plus numpy synthesis (chirps, pops, hiss, hum, clicks), then enveloped and filtered.

| Event | File | Length | Peak | Sound |
|---|---|---|---|---|
| Ball launched | `launch.wav` | 0.40 s | -1 dB | Ceramic latch tick, a fast rising run of Ceramic ticks and a numpy chirp rising from 330 Hz to about 1 kHz. |
| Ball hits a wall | `wall_hit.wav` | 0.45 s | -3 dB | Kinderjoy glass on D5 with an FM-bell body and a Ceramic tick. In game the pitch steps up D Dorian with the wall multiplier (x1.2 = D, x2.0 = A, x2.2 = B, x2.4 = C) and one degree per doubling of speed above 400 px/s (up to 3). Faster hits are up to 6 dB louder. |
| Ball boils through a zone | `fizz.wav` | 0.60 s | -5 dB | A burst of 18 Ceramic micro-ticks and 14 numpy bubble pops over a hiss that swells and falls. Plays on entry and every 0.5 s while a moving ball is inside. |
| Ball scores in the goal | `goal.wav` | 0.95 s | -1 dB | Ceramic shutter (two clicks) and a rising Kinderjoy fifth, D5 to A5. |
| Out of balls (lose) | `out_of_balls.wav` | 1.30 s | -2 dB | The chamber powers down: falling Kinderjoy glass (A F D A), a Super Nice Pluck sub thud, a falling sine and a magnet hum that sags and dies. |
| Target met (win) | `target_met.wav` | 1.90 s | -1.5 dB | Shutter, a Kinderjoy arpeggio up Dm9 (D F A C E) doubled by FM bells, then a held Crescendo Bells D/A fifth. |
| Start round / replay | `ui_confirm.wav` | 0.30 s | -6 dB | Two rising Kinderjoy glass ticks, A5 to D6, with clicks. |
| Language or sound toggle, M | `ui_click.wav` | 0.04 s | -8 dB | Dry Ceramic tick with a faint 1.76 kHz tone. |
| Hover over a wall | `ui_hover.wav` | 0.025 s | -15 dB | Lighter, higher Ceramic tick plus a noise click. |
| Wall turned one step | `rotate.wav` | 0.022 s | -14 dB | Ratchet tick (slightly lower when turning back). |
| Space with no balls left | `empty.wav` | 0.10 s | -6 dB | Dull dry fire: a muffled sub thud and a low click. |

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

## Rebuild

```sh
arch -arm64 /tmp/audiokit/venv/bin/python tools/audio/build.py
```

This needs the local audiokit toolchain in `/tmp/audiokit` (pedalboard hosting Vital and
Serum 2, fluidsynth with `MS Basic.sf3`), plus `lame` and `ffmpeg`. Rendering is offline
and silent; nothing is played and no plugin window opens.

## Credits and licences

- Music and SFX composed programmatically by AI (Claude) and rendered with Vital / Serum 2 /
  MS Basic soundfont.
- Vital by Matt Tytel (GPL-3.0). Presets: "Analog Pad" (In The Mix), "Crescendo Bells"
  (Level 8), "Ceramic" (Databroth), "Super Nice Pluck" (Mr Bill).
- Serum 2 by Xfer Records, factory presets: "PD - Dark Space", "BL - Kinderjoy",
  "SY - Tetris", "BA - Club - Muted".
- MS Basic soundfont (MuseScore), MIT licence: General MIDI drum kit.

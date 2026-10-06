# Art direction: "Event Frame" (bubble-chamber film)

## Seed reading

A 256-character random string served as the prompt for this direction. The string itself is not used anywhere in the game.

- **Palette.** The only valid six-digit hex run in the seed is `1B49AC`, a saturated cobalt. It becomes the ground colour. Cobalt laid flat on paper reads as a cyanotype, so the rest of the palette is that process: unexposed paper white, cream rag paper and Prussian ink. A fragment, `6Ae9`, suggests a pale blue for secondary marks.
- **Metaphor and key device.** `Q`, `O`, `o` and `0` are among the most frequent glyphs. A circle with a tail (`Q`) is a ball together with its trajectory, so every ball leaves a permanent white trace. `T` is the most common letter. A crossbar on a stem suggests a ruler or deflector, so the energy walls become rulers.
- **Type personality.** Upper and lower case are exactly balanced (104/104), and capitals arrive in dense clusters (`JUFBR`, `ZAKFL`, `NGNPU`). The type pairs a dense condensed caps face for numbers and labels with a loose hand for notes. About 19% of the seed is digits, so the score is set large.
- **Layout skeleton.** The paired `00` and `XGG` clusters suggest a frame inside a frame. The print sits behind a cut passe-partout mat, and the HUD is typeset on the mat like a museum caption.

## Fifteen shallow directions

1. **Sun print (cyanotype).** The level is a photogram on cobalt paper. Objects are white silhouettes and every ball burns a white trace into the print.
2. **Pinball backglass.** Enamel cabinet art, a chrome ball and lit inserts.
3. **Billiard baize.** Green felt, chalk marks and brass rails.
4. **Wooden marble run.** Lacquered toy blocks on a kid's table.
5. **Sumi-e.** The ball is an ink drop and the walls are brush strokes on rice paper.
6. **Stomach (unreasonable).** The ball is a pill rolling past villi.
7. **Curling (unreasonable).** A top-down ice sheet where sweeping brooms act as the energy walls.
8. **Pachinko in a stained-glass rose window (unreasonable).**
9. **Pollen under a microscope (unreasonable).** The walls are diatoms on a glass slide.
10. **Radar scope (unreasonable).** The ball is a phosphor blip and the walls are runway deflectors.
11. **Bubble-chamber photo.** White particle spirals on black film, with magnets as the walls.
12. **Risograph zine.** Two-ink cobalt and fluoro overprint with misregistration.
13. **Swiss railway map (unreasonable).** The ball is a train and the walls are switches.
14. **Orrery chart.** The ball is a comet, the goal is a planet and the slow zone is a nebula.
15. **Letterpress poster.** Huge nume## First pick: 1, Sun Print (rounds 1-2, abandoned)

Option 1 fit the seed's cobalt, its circle-with-tail glyphs and its framing. It was built as a cobalt photogram behind a cream mat, with Barlow and Caveat type. The critic scored it 5 and then 5: it read as a mat and caption template rather than a game. Following the brief's rule (no improvement after two rounds means rethinking the direction), it was dropped.

## Final pick: 11, Bubble-chamber photo ("Event Frame")

Each round is one exposed frame of bubble-chamber film. Balls are particles. Every ball writes a track made of bubbles, spaced and brightened by its speed, and sprays short tracks where it hits a wall. The level is the chamber hardware, and the HUD is the scanning-table annotation printed at the frame edge in pixel type. This direction makes the mechanic (speed is score) visible in the art itself.

## Round history

| Round | Score | What changed |
|---|---|---|
| 1 | 5 | Sun Print: cyanotype print, mat and caption |
| 2 | 5 | Sun Print: blueprint title block and stamp |
| 3 | 4 | Rethink to Event Frame: film strip, sprockets, dot-matrix type |
| 4 | 6 | Thin frame, level hidden on the title screen, single pixel font |
| 5 | 5 | Annotations next to walls, scan-in of the level |
| 6 | 5 | Amber only for live values, flat background, outline walls, level powered off on the result |

After round 6 the subtraction pass removed the grain shader, the filled launcher jaws and the corner rulers.

## Build brief (<= 200 words)

**Aesthetic.** One frame of bubble-chamber film on a scanning table: cold instrument, black field, nothing decorative.

**Palette.** Near-black `#0B0B0B` field. Track white `#EEEEE6` for every outline and track. Grey `#8F8F8A` for all static text and the frame hairline. Amber `#F0A040` is reserved for what changes: the ball, the goal reticle, live speed and score.

**Layout.** One hairline frame. The title is centred high. Controls sit on the bottom-left edge and the ball count on the bottom-right. The score is bottom-right, three times the HUD size. The result appears in an outlined black window while the level powers down to grey.

**Type.** Fusion Pixel 12 px (OFL), CJK included, at 12, 24 and 48 px only, on the pixel grid (text layer rendered at 1/3 scale).

**Material.** Bubbles spaced by speed, impact sprays, boiling zones that flicker, and the level scanning in on the first start.

**Forbidden.** Gradients, glows, vignettes, film grain, filled shapes besides the ball, a second accent colour, and decorative rulers.

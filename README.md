# Guide The Ball

A small physics puzzle made with Godot 4.6: launch balls, rotate Energy Walls and guide every ball into the goal circle.

Play on itch.io: https://kuthorx.itch.io/guide-the-ball

## Controls

- `Space` - launch a ball
- Mouse wheel over an Energy Wall - rotate it
- Left mouse drag - move the camera
- `R` - replay

## Languages

The game supports **English** and **简体中文**.

- On first launch the language follows the OS / browser language (Chinese -> 中文, otherwise English).
- Click the `中文 / EN` button in the top-right corner to switch; the choice is saved to `user://settings.cfg`.
- All strings live in `i18n/translations.csv` (`keys,en,zh`) and are registered under `[internationalization]` in `project.godot`.
- Chinese glyphs come from `fonts/LXGWWenKai-Regular-subset.ttf` (LXGW WenKai, SIL OFL 1.1, subset to the characters used), set as a fallback of the Latin font in `theme/*.tres`. When adding new Chinese text, regenerate the subset, e.g.:

  ```sh
  pyftsubset LXGWWenKai-Regular.ttf --text-file=chars.txt --unicodes=U+0020-007E,U+3000-303F,U+FF01-FF5E --output-file=fonts/LXGWWenKai-Regular-subset.ttf
  ```

## Export

Presets: `Windows Desktop` and `Web` (single-threaded, for itch.io).

```sh
godot --headless --path . --export-release "Web" ../guide-the-ball-export/web/index.html
```

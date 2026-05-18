# Themes

Curated `~/.commandress` configurations that exercise the v0.6.0 [palette layer](../adr/) and per-segment color contract. Each theme is a single CYML snippet — append it to your `~/.commandress` (or replace the file outright) and your next prompt redraw picks it up.

## Available themes

| Theme | File | Palette aesthetic |
|---|---|---|
| **commandress** | [`commandress.cyml`](commandress.cyml) | First-party signature theme — royal magenta + indigo + gold |
| **nord** | [`nord.cyml`](nord.cyml) | Cool blues + cyans; Arctic palette |
| **dracula** | [`dracula.cyml`](dracula.cyml) | Vivid purples + pinks + green accents |
| **gruvbox** | [`gruvbox.cyml`](gruvbox.cyml) | Warm yellows + oranges + retro-amber feel |
| **monokai** | [`monokai.cyml`](monokai.cyml) | Vibrant greens + magentas + bright yellow |

## How named colors map to your terminal

`commandress` v0.6.x speaks the 16 named ANSI colors only (8 standard + 8 bright + `default`). The *actual* color shown for `fg = "blue"` is whatever your terminal has bound to ANSI slot 34 — that's the terminal's job, not the prompt's.

In practice this means: **install the matching theme in your terminal** (`alacritty`, `kitty`, `wezterm`, etc. all support 16-color theme files for nord / dracula / gruvbox / monokai / etc.) and the commandress theme picks up that mapping automatically. Without the terminal-side theme, the prompt still works — it just uses your terminal's default 16-color palette.

Hex / 256-color support lands in a later release; once it does, these themes will land more faithfully without requiring terminal-side cooperation.

## Installing a theme

Each theme file is **self-contained** — it ships its own `[[prompt]]` block alongside `[[palette]]` and `[[segments.X]]`. So `cp` of any theme into your config gives you a working, fully-populated prompt out of the box.

### Fresh install / full replace

```sh
cp docs/themes/commandress.cyml ~/.commandress
```

This overwrites anything currently in `~/.commandress`. Use when you don't have a config yet — or when you don't mind starting fresh.

### Existing config you want to keep

Don't `cat >>` blindly. The config loader treats duplicate section names ("array of tables" semantics) as a list and uses the **first** occurrence — so appending a theme on top of an existing config means the theme's `[[prompt]]`, `[[segments.X]]`, and `[[palette]]` blocks get ignored, and you'd be staring at an unchanged prompt wondering why.

Edit by hand instead:

1. Open `~/.commandress` and the theme file side by side.
2. Replace your `[[palette]]` block with the theme's (or add one if you don't have one).
3. Replace each `[[segments.X]]` block with the theme's matching block. Leave alone the ones the theme doesn't ship.
4. Optionally update your `[[prompt]]` segment list — themes ship a maximalist set; trim to taste.

Open a new prompt — the precmd hook re-runs `cmdrs` on the next redraw, no shell restart needed.

## Writing your own

Each theme is a `[[palette]]` block (named slots) plus `[[segments.X]]` blocks that reference the slots via `fg = "palette:<name>"`. Copy any existing theme as a starting point and tweak the palette values. See [`../adr/0005-language-env-probe-pattern.md`](../adr/0005-language-env-probe-pattern.md) for the env-segment shape and the [v0.6.0 CHANGELOG](../../CHANGELOG.md) for the full color contract.

## Powerline mode

Set `separator_style = "powerline"` plus a `separator_glyph` (and optionally `right_separator_glyph` for the right-prompt side) and `bg` on every segment you want to render as a colored block:

```cyml
[[prompt]]
segments              = ["cwd", "vcs", "cyrius_env", "exit"]
separator_style       = "powerline"
separator_glyph       = ""                 # U+E0B0; needs a nerd-patched font
right_separator_glyph = ""                 # U+E0B2; for right-prompt
trailer               = " $ "

[[segments.cwd]]
fg = "white"
bg = "blue"
style = "bold"

[[segments.vcs]]
fg = "black"
bg = "yellow"

[[segments.cyrius_env]]
fg = "white"
bg = "magenta"

[[segments.exit]]
fg = "white"
bg = "red"
style = "bold"
```

Render emits a `fg=prev_bg, bg=next_bg` SGR + the glyph between adjacent blocks, plus a trailing `fg=last_bg, bg=default` glyph to close the chain. Segments without a `bg` set still render their content but don't form a block — the transition into / out of them uses the terminal default for the missing side.

**Font requirement**: The default glyphs (`` / ``) live in the powerline private-use area (U+E0B0+) and need a nerd-patched font (NerdFonts, Powerline, Hack Nerd, etc.) installed and configured in your terminal. Without one, the glyph renders as a tofu box. Any single-byte ASCII character (`>`, `|`, `/`) works as a fallback if you don't want to install a font.

**Themes & powerline**: the five theme files in this directory are fg-only out of the box. Add `bg = "..."` to each `[[segments.X]]` block you want as a powerline block. A dedicated powerline-ready theme variant is planned for a follow-up release.

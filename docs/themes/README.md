# Themes

Curated `~/.commandress.cyml` configurations that exercise the v0.6.0 [palette layer](../adr/) and per-segment color contract. Each theme is a single CYML snippet — append it to your `~/.commandress.cyml` (or replace the file outright) and your next prompt redraw picks it up.

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

```sh
# Replace whatever's currently in your config:
cp docs/themes/nord.cyml ~/.commandress.cyml

# Or append to an existing config (everything below your current content):
cat docs/themes/nord.cyml >> ~/.commandress.cyml
```

Then open a new prompt — the precmd hook re-runs `cmdrs` on the next redraw, no shell restart needed.

## Writing your own

Each theme is a `[[palette]]` block (named slots) plus `[[segments.X]]` blocks that reference the slots via `fg = "palette:<name>"`. Copy any existing theme as a starting point and tweak the palette values. See [`../adr/0005-language-env-probe-pattern.md`](../adr/0005-language-env-probe-pattern.md) for the env-segment shape and the [v0.6.0 CHANGELOG](../../CHANGELOG.md) for the full color contract.

# Prompt tour — what `cmdrs` paints, by example

A reference gallery of `cmdrs` output for the v0.3.0 surface (cwd / exit / vcs). Each block shows the config that produced it, the shell context, and the literal line `cmdrs` prints to stdout. Use it to pick a config shape that matches the prompt you want; copy into `~/.commandress` and adjust.

The annotated all-knobs config is the sibling file [`commandress.cyml.example`](commandress.cyml.example).

---

## Defaults — no config file present

The baked-in defaults are deliberately quiet. `cmdrs` prints `<cwd> $ ` and stays out of the way unless the last command failed.

```sh
$ cmdrs
~/repos/commandress $

$ AGNOSHI_LAST_EXIT=42 cmdrs
~/repos/commandress [42] $

$ (cd /tmp && AGNOSHI_LAST_EXIT=0 cmdrs)
/tmp $

$ (cd / && cmdrs)
/ $
```

Notes:
- `cwd` shortens any path under `$HOME` to a leading `~` (strict prefix — `/home/macroX` won't match `/home/macro`).
- `exit` is empty on `0` by default; non-zero prints `[N]`. Override with `[[segments.exit]] hide_zero = false`.

---

## Enabling the `vcs` segment

`vcs` is opt-in for v0.3.0 — you have to list it in `segments`. It probes `sit status`; outside a `sit` repo (or with `sit` not on PATH) it renders empty, never noisy.

`~/.commandress`:

```cyml
[[prompt]]
segments = ["cwd", "vcs", "exit"]
```

Output:

```sh
# Inside a sit repo, working tree clean, on branch "main":
$ cmdrs
~/repos/commandress main $

# Inside the same repo after editing a tracked file:
$ cmdrs
~/repos/commandress main* $

# Same repo, on a feature branch:
$ sit checkout -b feature/prompt-tour
$ cmdrs
~/repos/commandress feature/prompt-tour $

# Outside any sit repo — vcs segment is silently empty:
$ (cd /tmp && cmdrs)
/tmp $
```

The trailing `*` (the dirty marker) is configurable:

```cyml
[[segments.vcs]]
dirty_marker = " ●"        # ●, ★, !, etc. — Unicode and multi-char both work
```

```sh
$ cmdrs
~/repos/commandress main ● $
```

Set `show_dirty = false` to drop the marker entirely (branch name only):

```cyml
[[segments.vcs]]
show_dirty = false
```

```sh
$ cmdrs              # dirty tree, but no marker shown
~/repos/commandress main $
```

---

## Always-visible exit code (good for screenshots / tutorials)

```cyml
[[segments.exit]]
hide_zero = false
```

```sh
$ AGNOSHI_LAST_EXIT=0 cmdrs
~/repos/commandress [0] $

$ AGNOSHI_LAST_EXIT=2 cmdrs
~/repos/commandress [2] $
```

---

## Custom separator and trailer

The separator goes between adjacent painted segments. The trailer is always painted at the end (cosmetic — include any whitespace you want before the prompt char).

```cyml
[[prompt]]
segments  = ["cwd", "vcs", "exit"]
separator = " │ "
trailer   = " ❯ "
```

```sh
$ cmdrs
~/repos/commandress │ main* ❯

$ AGNOSHI_LAST_EXIT=1 cmdrs
~/repos/commandress │ main* │ [1] ❯
```

---

## Absolute paths instead of `~`-shortening

```cyml
[[segments.cwd]]
home_shorten = false
```

```sh
$ cmdrs
/home/macro/repos/commandress $
```

---

## Reordering segments

The `segments` array is the order they paint. There's no "left side" / "right side" distinction in v0.3.0 — everything is one line. You can put `exit` at the start to lead with the previous status, for example:

```cyml
[[prompt]]
segments = ["exit", "vcs", "cwd"]
```

```sh
$ AGNOSHI_LAST_EXIT=1 cmdrs
[1] main* ~/repos/commandress $
```

---

## Shell integration (manual, pre-M7)

Until the agnoshi adapter (M7) lands, `cmdrs` is invoked by hand — it reads its context from env vars and prints one line to stdout. Wire it into your shell of choice:

### bash / zsh

Stash the previous command's exit before `cmdrs` runs so the segment can read it:

```sh
# In ~/.bashrc or ~/.zshrc:
_cmdrs_prompt() {
    AGNOSHI_LAST_EXIT=$? cmdrs
}
PROMPT_COMMAND='_cmdrs_prompt'        # bash
# OR
PROMPT='$(_cmdrs_prompt)'             # zsh — single quotes are intentional
```

### Smoke-testing the binary directly

```sh
$ AGNOSHI_LAST_EXIT=0 ./build/cmdrs                  # success path
$ AGNOSHI_LAST_EXIT=42 ./build/cmdrs                 # non-zero exit shown
$ (cd /tmp && ./build/cmdrs)                          # outside HOME, outside sit
```

### agnoshi (M7+, not yet shipped)

Planned shape — the agnoshi-side adapter will set this for you:

```sh
export AGNOSHI_PROMPT_CMD=cmdrs
```

---

## Picking a shape — quick recipes

| You want… | Add this section |
|---|---|
| Always-visible exit code | `[[segments.exit]]\nhide_zero = false` |
| Drop the dirty marker | `[[segments.vcs]]\nshow_dirty = false` |
| Different dirty glyph | `[[segments.vcs]]\ndirty_marker = " ●"` |
| Absolute paths in cwd | `[[segments.cwd]]\nhome_shorten = false` |
| Powerline-style separator | `[[prompt]]\nseparator = " │ "` *(theming proper lands in M5)* |
| Disable a segment | Omit it from `segments = [...]` |

---

## What's not yet here

The v0.3.0 surface is intentionally narrow. These land in upcoming milestones — see [`../development/roadmap.md`](../development/roadmap.md):

- **M3 (v0.4.0)** — `time`, `hostname`, `user` segments; per-segment timeout enforcement (drops slow segments instead of stalling).
- **M4 (v0.5.0)** — language-env segments (`python_env`, `node_env`, etc.).
- **M5 (v0.6.0)** — ANSI color palette, powerline separators, right-prompt.
- **M6 (v0.7.0)** — probe caching (the change that makes `vcs` cheap enough for default-on).
- **M7 (v0.8.0)** — agnoshi / bash / zsh first-party adapters.

# Prompt tour — what `cmdrs` paints, by example

A reference gallery of `cmdrs` output, centred on the core cwd / exit / vcs surface. Each block shows the config that produced it, the shell context, and the literal line `cmdrs` prints to stdout. Use it to pick a config shape that matches the prompt you want; copy into `~/.commandress` and adjust.

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

## Shell integration

**Use the shipped adapters** — they have shipped since v0.8.0, and they carry security
fixes that a hand-rolled hook will not:

```sh
source /path/to/commandress/adapters/zsh.sh    # zsh  — see docs/guides/zsh-setup.md
source /path/to/commandress/adapters/bash.sh   # bash — see docs/guides/bash-setup.md
```

> **Do not hand-roll `PROMPT='$(...)'` with single quotes.** That form only works with
> zsh's `prompt_subst`, which makes the shell run command substitution on the prompt at
> every redraw — and `cmdrs` output contains bytes chosen by whatever repository you are
> standing in. That is arbitrary command execution, confirmed and fixed in v1.1.6
> ([2026-08-26 audit](../audit/2026-08-26-audit.md), finding P-01). This tour recommended
> exactly that pattern until the 2026-08-26 doc sweep. The adapters assign a
> fully-rendered string in a `precmd` / `PROMPT_COMMAND` hook instead, which needs no
> prompt expansion at all. If you must inline it, copy the vetted paste from the setup
> guides — both marked-REQUIRED lines included.

### Smoke-testing the binary directly

```sh
$ AGNOSHI_LAST_EXIT=0 ./build/cmdrs                  # success path
$ AGNOSHI_LAST_EXIT=42 ./build/cmdrs                 # non-zero exit shown
$ (cd /tmp && ./build/cmdrs)                          # outside HOME, outside sit
```

### agnoshi (contract defined; agnoshi has not adopted it yet)

The 5-point contract is specified in [`adapters/agnoshi.sh`](../../adapters/agnoshi.sh). No
commandress change is required when agnoshi implements it:

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
| Powerline-style separator | `[[prompt]]\nseparator_style = "powerline"` — full theming shipped in v0.6.0; see [`../themes/`](../themes/) |
| Disable a segment | Omit it from `segments = [...]` |

---

## What's not yet here

Everything this tour once listed as upcoming has shipped: `time` / `hostname` / `user` and
per-segment timeouts (v0.4.0), the language-env segments (v0.5.0), colour + powerline +
right-prompt (v0.6.0), and probe caching (v0.7.0). v1.0 froze the schema.

What is genuinely still ahead is sequenced in
[`../development/roadmap.md`](../development/roadmap.md) — multi-palette and hex/256-colour
(1.2.0), `rust-toolchain.toml` and opt-in version shellouts (1.3.0), per-segment
`budget_ms` and local-time support (1.4.0). Every item there is pinned to the line of code
that defers it.

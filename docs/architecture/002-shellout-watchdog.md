# 002 — Shellout watchdog

How `src/shellout.cyr::shellout_capture` enforces a per-call time budget on segments that fork an external process. Companion to [001 — Prompt render budget](001-prompt-render-budget.md), which sets the budget; this item describes how the gate is enforced.

## Surface

```
shellout_capture(cmd_path, argv, envp, budget_ms, buf, buflen): i64
```

Return code is the segment-side contract:

| Return    | Meaning                          | Caller does          |
|-----------|----------------------------------|----------------------|
| `>= 0`    | bytes captured into `buf`        | parse / render       |
| `-1`      | system error (pipe/fork/epoll)   | render empty         |
| `-2`      | exceeded `budget_ms`, child killed | render empty       |

The 0/-1/-2 split lets callers distinguish "the command succeeded with no output" from "the command was killed" — both render empty, but the -2 path is the watchdog firing and is worth surfacing in `--debug` mode (added in a later slot).

## Mechanism

1. `pipe(2)` → read + write fds.
2. `fork(2)`.
   - Child: `dup2` write-fd → stdout, open `/dev/null` → dup2 → stderr, `execve(cmd_path, argv, envp)`. On execve failure, `exit(127)`.
   - Parent: close write-fd, set up epoll on read-fd.
3. `clock_now_ms()` baseline; `deadline_ms = now + budget_ms`.
4. Loop:
   - `remaining = deadline_ms - clock_now_ms()`. If `<= 0` → timeout.
   - `epoll_wait(timeout=remaining)` for `EPOLLIN`. `EINTR` loops, because a stop and continue raises it even with no handler installed, and the loop re-reads the clock.
   - If `nev == 0` → timeout.
   - If readable → `read(buf + total, buflen - total)`. If `n <= 0` → EOF / child closed pipe, done. Else accumulate and loop.
5. Always, on every exit: `kill(pid, SIGKILL)`, close fds, then a short bounded reap that never blocks. See below.

## Why epoll, not poll/select

`lib/syscalls.cyr` exposes `sys_epoll_create` / `_ctl` / `_wait` and not bare `poll`/`select`. Both syscalls are available in the kernel; commandress could open-code `poll(2)` but the existing wrapper surface is the right tool to use. The trade is:

- **Plus**: a one-fd watch is what epoll is designed for, and reusing the wrappers means no new syscall numbers to plumb.
- **Minus**: epoll has a 1 ms timeout floor (`epoll_pwait2` lifts this with a `timespec` argument, but isn't wrapped in stdlib today). Sub-millisecond per-segment budgets land in M6 alongside parallel segment evaluation; until then, `budget_ms < 1` clamps to 1.

## What the watchdog does NOT do

- **No retry-with-cached-value.** A killed segment renders empty for one redraw; the next redraw runs it again from scratch. Caching (1 s TTL) lands in M6.
- **No partial-output behavior.** If the budget fires mid-read, the captured prefix is *discarded* (return `-2`, ignore `total`). Partial-output rendering would force every segment parser to handle truncation; the empty-render-on-timeout shape keeps the parser side simple.
- **No CPU-bound segment enforcement.** Pure-CPU segments (cwd, exit, time, hostname, user) clear 500 µs trivially and don't go through this watchdog. If a pure-CPU segment ever spins, it's a bug and stays a bug — not a watchdog miss. (`setitimer`-based CPU watchdog would change this; it's out of scope.)

## Nothing after the loop may block

The budget is enforced by `epoll_wait`, so it stops applying the moment the loop exits.
Everything after that point has to finish on its own, and this has been got wrong twice:

| Exit | Who could hang us | Fixed by |
|---|---|---|
| Capture buffer full, child still writing | `waitpid` on a child blocked in `write()` | `close(rfd)` first, so its next write dies on `EPIPE` (2026-08-26, P-05) |
| EOF, but the child closed stdout and lives on | `waitpid` on a child that is not writing | `SIGKILL` on every exit, not just a timeout (2026-08-26, A-02) |
| A child that will not finish dying | `waitpid` after `SIGKILL` | `_shellout_reap` never blocks (2026-11-06, R-01) |

The third row is the one that looked closed. `SIGKILL` is not synchronous: a child stuck on
a wedged FUSE filesystem, or held by a ptracer, stays unreapable for as long as that lasts.
A `sit` holding a file on a FUSE mount that never answered `FLUSH` parked `cmdrs` in
`do_wait` with no deadline, and a ptrace helper held it for 6 s against a 5 ms budget.

`_shellout_reap` tries `WNOHANG` five times over about half a millisecond, which is what a
normal exit takes, then gives up. `cmdrs` exits a moment later, and init collects the child.

**Order after the loop: kill, close, reap.** Measured at the 2026-08-26 audit, with `close`
and the wait swapped, the suite hung and was killed at 45 s. As shipped, a child flooding
200 KB through a 256-byte buffer returns in 5 ms. Pinned by
`test_shellout_oversized_child_does_not_hang`,
`test_shellout_eof_with_live_child_does_not_hang` and `test_shellout_reap_does_not_block`.

## Cross-arch surface

`sys_epoll_wait` is x86-specific in `lib/syscalls_x86_64_linux.cyr` (the aarch64 peer exposes the same wrapper via `lib/syscalls_aarch64_linux.cyr`). The watchdog code itself is arch-agnostic — it calls the wrapper, not the syscall number directly. Cross-arch builds work via Cyrius's arch-dispatched include selector.

## Replaces (history)

`src/segments/vcs.cyr` shipped an inline `_vcs_capture` in v0.3.0 to dodge two Cyrius 5.11.59-era stdlib bugs (`lib/process.cyr::_exec3` byte-contract; vec-exec family missing stderr dup2). Both fixed upstream in Cyrius 5.11.60 — see CHANGELOG [0.4.0] for the rewrite. The watchdog landed in the same slot because the per-segment-timeout work carried forward from M2/M3 also needs the fork+exec+poll+kill scaffold, and rebuilding it inside `vcs.cyr` made no sense once a shared helper existed.

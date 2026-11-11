# 0017 — On agnos the directory comes from the kernel, else agnsh's `$PWD`, and a pin keeps its rules there

**Status**: Accepted
**Date**: 2026-11-10

## Context

`cmdrs_getcwd` returned 0 on agnos, so `cwd`, `cyrius_env`, `python_env`, `node_env` and `rustup_env` were always empty there, and the default prompt was a bare ` $ `. The roadmap's agnoshi row named this as the one change it needed from this repo. Two sources of the directory exist there now:

- **`$PWD`.** agnsh tracks its own directory, and since agnoshi 2.2.0 it exports it to every child as `PWD`, normalized ([agnoshi ADR-012](https://github.com/MacCracken/agnoshi/blob/main/docs/adr/012-working-directory.md)).
- **The kernel.** Through 1.57.17 agnos had no working directory: the ABI said it was userland's. **agnos 1.57.18 added one per process**, with `chdir`#112 and `getcwd`#113 (agnos userland ABI § 3.2). `getcwd`#113 answers the directory cleaned lexically, and its length without the NUL. `spawn` seeds a child's directory from the first `PWD=` in its environment when that is absolute and names a directory, and from its creator's otherwise. The cyrius 6.7.18 agnos peer has no wrapper for either call yet (cyrius issue `2026-11-08-agnos-sys-chdir-getcwd-112-113-peer`).

This ADR was first written from agnoshi's ADR-012 and the old ABI paragraph, which both say agnos has no `getcwd`. The kernel source said otherwise before release, and the decision below was changed to match it.

Giving `cmdrs` a directory on agnos was never a one-liner, because it makes repo-controlled files reachable there for the first time. Both readers were plain `file_read_all` there. Two questions had to be answered for agnos.

**Can a repo file stall the read?** On Linux, a FIFO or device named `.nvmrc` would hang `cmdrs`, and `read_regular_file` has two guards against it (audit A-01). Read from the agnos kernel source:

| | agnos 1.57.19 |
|---|---|
| A FIFO or device inode on ext2, in an image made on Linux | `ext2_open` returns -1 for any inode that is not `S_IFREG` |
| The same on ZFS | `zfs_open` returns -1 for anything but a regular file or, with `AO_DIRECTORY`, a directory |
| Making one | The ABI has no `mknod`, and the stdlib's `sys_mknodat` is a stub. No device has a path: fds 0 to 2 are the only devices |
| `O_NONBLOCK` | Not defined in the agnos syscall peer |
| `fstat` | A hard stub. `fd_kind`#111, added at 1.57.13, answers what an fd is |

So the stall does not exist on agnos.

**Can a repo link to a file it does not contain?** Yes. agnos has symlinks on ext2 and, since 1.57.12, on ZFS. ADR 0015's name rule asks the kernel where a link ended through `/proc/self/fd/<n>`, and agnos has no `/proc`. With a directory and nothing else changed, `.nvmrc -> ../secret` shows the secret.

## Decision

**On agnos, `cmdrs_getcwd` asks the kernel with `getcwd`#113, and reads `$PWD` only when the kernel cannot answer. Either answer must be in normalized form. The pin readers keep ADR 0015's name rule there by walking the link chain with `readlink`, and every read checks that it got a regular file with `fd_kind`.**

### The directory

- **The kernel first.** `getcwd`#113 is the directory the process is in, whoever started it, and it does not depend on the environment. It is called raw, as `syscall(113, …)`, until the stdlib wraps it, and its length gains one for the NUL so it means what `getcwd(2)`'s does.
- **`$PWD` when the kernel cannot answer**, which is any kernel before 1.57.18, where agnsh 2.2.0 runs. Under agnsh the two agree, because the kernel seeds `cmdrs`'s directory from the same `PWD=`.
- **Only the normalized form is accepted** from either: absolute, with no NUL, no empty, `.` or `..` component, and no trailing `/` except on `/` itself. `cwd_shape_ok` checks this. It is the form both the kernel and agnsh produce, so anything else came from somewhere else. The walk up from `/a/../b` would probe `/a`, which is not above `/b`.
- **A kernel answer of the wrong form renders empty.** It is not replaced by `$PWD`, the less trusted input.
- **It is not normalized here.** `..` means whatever whoever wrote the path meant by it.
- **A path that does not fit the 4 KB buffer is refused**, not cut. A cut path names another directory. The kernel caps its directory at 4,095 bytes, so its answer always fits.
- **Linux is unchanged.** It keeps `getcwd(2)`, which needs no trust in the environment.

### The name rule, without `/proc`

- **`AO_NOFOLLOW` first**, as on Linux, so a plain file pays nothing. agnos answers -1 for a link under `AO_NOFOLLOW` and for a missing file alike, so a failure goes on to the walk.
- **The walk** follows the chain with `readlink`, one link at a time, joining a relative target to the directory of the link that holds it. It stops at the first path `readlink` does not read as a link, and that is the end of the chain. `..` is left to the kernel, which knows what `..` after a link means.
- **The end must keep the pin's name**, with ADR 0015's matching rules, and is then opened with `AO_NOFOLLOW`. A link swapped in after the walk is refused, not followed. A swap in a directory component can only move the read to another file of the pin's name, which is also true on Linux, where the kernel resolves those components too.
- **At most 8 links**, `PIN_LINK_HOPS`. Linux follows 40. A pin behind more than a few links is not a case worth a bigger bound.
- **A target that fills the 4 KB buffer is refused.** Since agnos 1.57.18, `readlink` copies at most the cap and returns the count, as Linux does, so a full buffer may be a cut path.

### The regular-file check

- **`_fd_is_regular` asks `fd_kind` on agnos**, and `fstat` on Linux, so `read_regular_file` and `read_pin_file` refuse anything but a regular file on both targets.
- **A kernel before 1.57.13 cannot answer, and its -1 reads as a file.** The backends open nothing else by path, so that loses nothing, where refusing would lose every pin and the config.
- **`read_regular_file` still opens without `O_NONBLOCK` on agnos.** The constant does not exist there, and nothing it would guard against can be opened.

## Consequences

- **Positive** — The cwd-based segments work on agnos, which is what agnoshi adoption needed from this repo. On 1.57.18 and later that holds whatever started `cmdrs`; before it, under agnsh 2.2.0 or later.
- **Positive** — ADR 0015's rule holds on agnos too. Booted on kernel 1.57.19 under agnsh 2.2.0 against ext2 fixtures: a link to another name, a chain ending at one, a dangling link, a loop, a directory with the right name and a chain of nine links all render nothing, and a plain pin, a relative link, an absolute link, a chain that ends at the right name and a chain of eight links all render the version. The same `$PWD` read without the agnos arm of `read_pin_file` shows the secret. `scripts/agnos-boot-check.py` repeats all of it. It builds that broken copy itself as a control, and runs builds that take the directory from `getcwd`#113 alone and from `$PWD` alone, so both sources are checked on a kernel.
- **Positive** — `read_regular_file` and `read_pin_file` mean the same thing on both targets.
- **Negative** — On a kernel before 1.57.18, a `$PWD` that agnsh did not write, such as one with a trailing slash from another launcher, renders the cwd-based segments empty. Normalizing it would mean trusting more of the environment.
- **Negative** — `getcwd`#113 is a raw syscall number in this repo until the cyrius agnos peer wraps it. The number is frozen in agnos's ABI.
- **Negative** — A pin behind more than 8 links renders empty on agnos, where Linux would show it.
- **Negative** — On agnos a symlinked pin costs a `readlink` per link and two opens. A plain file costs what it did.
- **Neutral** — The name rule needs agnos 1.56.53, which added `AO_NOFOLLOW` and `lstat`. On an older kernel the first open would follow a link unchecked. agnsh 2.2.0, the shell that exports `$PWD`, is tested on 1.57.14 and later, and the agnos peer of cyrius 6.7.18 already assumes 1.57.x calls.
- **Neutral** — agnoshi's ADR-012 still says agnos has no cwd syscall. agnoshi has an open issue to move `cd` onto `chdir`#112. Nothing here depends on it: once agnsh calls `chdir`#112, `getcwd`#113 is simply the same answer by another route.
- **Neutral** — `vcs` is still empty on agnos. `cmdrs` cannot run `sit` there, because `shellout_capture` is a stub.
- **Neutral** — ZFS was read from the kernel source and not booted. Its `zfs_open` honours `AO_NOFOLLOW` and `readlink`#70 reads its links, so the same walk applies.
- **Neutral** — This ADR supersedes the Neutral bullet of ADR 0015 that said agnos was unchanged.

## Alternatives considered

- **Read `$PWD` and leave the readers as they were.** The roadmap row named this as the trap. The boot test's control binary does exactly this, and shows the secret.
- **`$PWD` alone**, as first built. It works under agnsh, because the kernel seeds the directory from the same value, and nowhere else: a program started without `PWD` would render empty, and the kernel's answer would go unasked.
- **`getcwd`#113 alone.** Empty on every kernel before 1.57.18, where agnsh 2.2.0 runs and exports a usable `$PWD`.
- **Refuse every symlinked pin on agnos.** Simpler, and fails closed. It blanks `.nvmrc -> ../.nvmrc` in a monorepo, which ADR 0015 kept working on purpose.
- **Normalize `$PWD` here.** agnsh and the kernel both resolve `..` themselves. A second normalizer would only ever see a path neither of them wrote, and what that means is up to whoever wrote it.
- **`lstat` the pin, then `readlink` it.** One more syscall per link, and `readlink` already answers -1 for a path that is not a link.
- **Wait for agnos to grow `/proc/self/fd`.** Nothing schedules it, and the walk does not need it.

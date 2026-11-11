#!/usr/bin/env python3
# Boot `cmdrs --agnos` on the real agnos kernel, under agnsh, and check what it renders.
# Usage: python3 scripts/agnos-boot-check.py
#
# The suite runs on Linux, and on agnos the cwd and every pin read take their own arm
# (ADR 0017): getcwd#113 or `$PWD`, a readlink walk in place of /proc/self/fd, fd_kind
# in place of fstat. Nothing on the host can run those arms. This boots a kernel in QEMU,
# types `cd DIR` and `cmdrs` at agnsh through an emulated keyboard, and reads the prompt
# back from the serial console.
#
# It also builds patched copies of this tree. Two are broken and must fail: one whose agnos
# `cmdrs_getcwd` is the old stub, and one with no agnos arm in `read_pin_file`, which
# shows the planted secret. A check that cannot fail proves nothing. Two more take the
# directory from one source each, getcwd#113 or `$PWD`, so both arms run on a kernel. If a
# patch stops applying, the run fails and says so: update the patch with the code.
#
# Not in CI: it needs a built agnos kernel, gnoboot and an agnos-target agnsh, and takes
# several minutes. Run it when an agnos arm changes. The agnos and agnoshi trees are only
# read. Everything is written under build/agnos-boot/.
#
# Env: AGNOS_ROOT (default ../agnos), GNOBOOT_ROOT (default ../gnoboot),
#      AGNSH_AGNOS (default ../agnoshi/build/agnos-qemu/agnsh_agnos, which agnoshi's own
#      scripts/agnos-qemu-test.py leaves there; agnsh 2.2.0 or later, which exports PWD),
#      AGNOS_QEMU_TCG=1 forces TCG instead of KVM.
# Needs qemu-system-x86_64, OVMF, parted, sgdisk, mtools and mkfs.ext2. Exit 0 only when
# every check ran and held.
#
# Lessons from agnoshi's harness, and from the two scratch runs before this one:
#   - the first keystroke of a session is swallowed, so a bare Enter goes first;
#   - a failed firmware hand-off is VOID, not a failure: retry with fresh NVRAM;
#   - the monitor is TCP, because an AF_UNIX path under a deep build dir passes 108 bytes;
#   - the oracle is what cmdrs printed, between the echo of `cmdrs` and the trailer.
import os, re, shutil, socket, subprocess, sys, time

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SIB = os.path.dirname(REPO)
AGNOS_ROOT = os.path.abspath(os.environ.get("AGNOS_ROOT", os.path.join(SIB, "agnos")))
GNOBOOT = os.path.join(os.path.abspath(os.environ.get("GNOBOOT_ROOT", os.path.join(SIB, "gnoboot"))),
                       "build/BOOTX64.EFI")
AGNSH = os.path.abspath(os.environ.get("AGNSH_AGNOS",
                                       os.path.join(SIB, "agnoshi/build/agnos-qemu/agnsh_agnos")))
KERNEL = os.path.join(AGNOS_ROOT, "build/agnos")
ROOTFS = os.path.join(AGNOS_ROOT, "build/rootfs")
WORK = os.path.join(REPO, "build/agnos-boot")
IMG, SEED, SER = WORK + "/boot.img", WORK + "/seed", WORK + "/serial.log"
PART_OFFSET = 33 * 1048576
PART_BLOCKS = (67 * 1048576) // 4096
EXT2_FEATURES = "^resize_inode,^dir_index,^metadata_csum,^64bit,^uninit_bg"
VERSION = open(os.path.join(REPO, "VERSION")).read().strip()


def p(*a):
    print(*a, flush=True)


def die(msg):
    p("FAIL:", msg)
    sys.exit(1)


def sh(cmd):
    r = subprocess.run(cmd, shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
    if r.returncode != 0:
        die("image step: " + cmd + "\n" + r.stderr.decode("latin1")[:400])


def build_agnos(tree, out):
    env = dict(os.environ, CYRIUS_NO_WARN_SHADOW_LIB="1")
    r = subprocess.run(["cyrius", "build", "--agnos", "src/main.cyr", out], cwd=tree, env=env,
                       stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    if r.returncode != 0:
        die("cyrius build --agnos in " + tree + ":\n" + r.stdout.decode("latin1")[-600:])


def mutant(name, path, old, new):
    """A copy of this tree with `old` replaced by `new` in `path`, built for agnos."""
    tree = os.path.join(WORK, "mut-" + name)
    os.makedirs(tree)
    for entry in ("src", "lib"):
        shutil.copytree(os.path.join(REPO, entry), os.path.join(tree, entry), symlinks=True)
    for entry in ("cyrius.cyml", "cyrius.lock", "VERSION"):
        shutil.copyfile(os.path.join(REPO, entry), os.path.join(tree, entry))
    src = os.path.join(tree, path)
    text = open(src).read()
    if text.count(old) != 1:
        die(f"the {name} control's patch no longer applies to {path}: update it in this script")
    open(src, "w").write(text.replace(old, new))
    out = os.path.join(WORK, "cmdrs-" + name)
    build_agnos(tree, out)
    return out


# ---- preflight ----
for tool in ("qemu-system-x86_64", "parted", "sgdisk", "mformat", "mmd", "mcopy", "mkfs.ext2", "cyrius"):
    if shutil.which(tool) is None:
        die(tool + " is not installed")
for path, what in ((KERNEL, "build agnos"), (ROOTFS, "build agnos"), (GNOBOOT, "build gnoboot"),
                   (AGNSH, "run agnoshi's scripts/agnos-qemu-test.py, or set AGNSH_AGNOS")):
    if not os.path.exists(path):
        die("missing " + path + " (" + what + ")")
m = re.search(rb"agnoshi (\d+)\.(\d+)\.(\d+)", open(AGNSH, "rb").read())
if m is None or (int(m.group(1)), int(m.group(2))) < (2, 2):
    die(AGNSH + " is not agnsh 2.2.0 or later, which is the first to export PWD")
AGNSH_VER = b".".join(m.groups()).decode()
OVMF_CODE = next((c for c in ("/usr/share/edk2/x64/OVMF_CODE.4m.fd", "/usr/share/edk2/x64/OVMF_CODE.fd",
                               "/usr/share/OVMF/OVMF_CODE.fd", "/usr/share/OVMF/OVMF_CODE_4M.fd")
                  if os.path.exists(c)), None)
OVMF_VARS = next((c for c in ("/usr/share/edk2/x64/OVMF_VARS.4m.fd", "/usr/share/edk2/x64/OVMF_VARS.fd",
                               "/usr/share/OVMF/OVMF_VARS.fd", "/usr/share/OVMF/OVMF_VARS_4M.fd")
                  if os.path.exists(c)), None)
if not OVMF_CODE or not OVMF_VARS:
    die("OVMF not found")

# ---- the binaries: this tree, and two copies that must fail ----
shutil.rmtree(WORK, ignore_errors=True)
os.makedirs(WORK)
CMDRS = os.path.join(WORK, "cmdrs")
build_agnos(REPO, CMDRS)
GETCWD = "    var n = syscall(113, buf, cap, 0, 0);\n"
NOCWD = mutant("nocwd", "src/pathlookup.cyr", GETCWD, "    return 0;\n" + GETCWD)
KERNELONLY = mutant("kernelonly", "src/pathlookup.cyr",
                    '    return cwd_from_pwd(getenv("PWD"), buf, cap);\n', "    return 0;\n")
PWDONLY = mutant("pwdonly", "src/pathlookup.cyr", GETCWD, "    var n = 0 - 1;\n")
NOGUARD = mutant("noguard", "src/fslookup.cyr",
                 "    var afd = file_open(path, PIN_O_NOFOLLOW, 0);\n",
                 "    return file_read_all(path, buf, cap);\n    var afd = file_open(path, PIN_O_NOFOLLOW, 0);\n")

# ---- the image: a copy of agnos's rootfs, the binaries, and the fixtures, as ext2 ----
subprocess.run(["cp", "-a", ROOTFS, SEED], check=True)
for src, name in ((AGNSH, "agnsh"), (CMDRS, "cmdrs"), (NOCWD, "cmdrsnocwd"), (NOGUARD, "cmdrsnoguard"),
                  (KERNELONLY, "cmdrskernel"), (PWDONLY, "cmdrspwd")):
    shutil.copyfile(src, os.path.join(SEED, "bin", name))
    os.chmod(os.path.join(SEED, "bin", name), 0o755)


def put(rel, body):
    path = os.path.join(SEED, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write(body)


def link(target, rel):
    path = os.path.join(SEED, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    os.symlink(target, path)        # mkfs.ext2 -d keeps a symlink as a symlink


# HOME is / on agnos, so this is ~/.commandress. Each fixture holds one kind of pin, so the
# field after the cwd says which reader answered. The trailer marks the end of the prompt.
put(".commandress", '[[prompt]]\nsegments = ["cwd", "node_env", "python_env", "rustup_env", "cyrius_env"]\n'
                    'separator = " | "\ntrailer = " #END"\n')
put("secret", "hunter2\n")
put("p1/.nvmrc", "20\n")
os.makedirs(os.path.join(SEED, "p1/sub"))
link("../secret", "p2/.nvmrc")
link("../p1/.nvmrc", "p3/.nvmrc")
link("/p1/.nvmrc", "p4/.nvmrc")
link("link", "p5/.nvmrc")
link("../p1/.nvmrc", "p5/link")
link("link", "p6/.nvmrc")
link("../secret", "p6/link")
link("missing/.nvmrc", "p7/.nvmrc")
os.makedirs(os.path.join(SEED, "p8/.nvmrc"))
link("../p8/.nvmrc", "p8b/.nvmrc")
link(".nvmrc", "p9/.nvmrc")
put("p10/.python-version", "3.12.1\n")
link("../secret", "p11/.python-version")
put("p12/rust-toolchain.toml", '[toolchain]\nchannel = "1.80.0"\n')
link("../secret", "p13/rust-toolchain.toml")
put("p14/package.json", '{"engines":{"node":">=18"}}')
link("../secret", "p15/package.json")
put("p16/cyrius.cyml", "[package]\n")
put("p16/VERSION", "0.4.2\n")
put("p17/cyrius.cyml", "[package]\n")
link("../secret", "p17/VERSION")
# PIN_LINK_HOPS is 8: eight links to the file are followed, nine are not.
for d, links in (("p18", 8), ("p19", 9)):
    link("l1", d + "/.nvmrc")
    for i in range(1, links - 1):
        link("l%d" % (i + 1), d + "/l%d" % i)
    link("../p1/.nvmrc", d + "/l%d" % (links - 1))

CASES = [
    ("/p1", "/p1 | 20", "a plain .nvmrc"),
    ("/p1/sub", "/p1/sub | 20", "the walk finds it a level up"),
    ("/p2", "/p2", "a link to another name is refused"),
    ("/p3", "/p3 | 20", "a relative link that keeps the name"),
    ("/p4", "/p4 | 20", "an absolute one"),
    ("/p5", "/p5 | 20", "a chain counts by where it ends"),
    ("/p6", "/p6", "a chain ending at another name is refused"),
    ("/p7", "/p7", "a dangling link"),
    ("/p8", "/p8", "a directory with the name"),
    ("/p8b", "/p8b", "a link to that directory"),
    ("/p9", "/p9", "a loop ends"),
    ("/p18", "/p18 | 20", "eight links are followed"),
    ("/p19", "/p19", "nine are not"),
    ("/p10", "/p10 | 3.12.1", "python_env reads .python-version"),
    ("/p11", "/p11", "python_env refuses a link to another name"),
    ("/p12", "/p12 | 1.80.0", "rustup_env reads rust-toolchain.toml"),
    ("/p13", "/p13", "rustup_env refuses a link to another name"),
    ("/p14", "/p14 | >=18", "node_env reads package.json"),
    ("/p15", "/p15", "node_env refuses a package.json link to another name"),
    ("/p16", "/p16 | 0.4.2", "cyrius_env reads VERSION"),
    ("/p17", "/p17", "cyrius_env refuses a VERSION link to another name"),
]

sh(f"dd if=/dev/zero of={IMG} bs=1M count=128 status=none")
sh(f"parted -s {IMG} mklabel gpt mkpart ESP fat32 1MiB 33MiB set 1 esp on mkpart agnos-fs ext2 33MiB 100MiB")
sh(f"sgdisk -t 2:8300 {IMG} >/dev/null")
sh(f"mformat -i {IMG}@@1048576 -F")
sh(f"mmd -i {IMG}@@1048576 ::EFI ::EFI/BOOT ::boot")
sh(f"mcopy -i {IMG}@@1048576 {GNOBOOT} ::EFI/BOOT/BOOTX64.EFI")
sh(f"mcopy -i {IMG}@@1048576 {KERNEL} ::boot/agnos")
sh(f"mkfs.ext2 -F -q -L AGNOS-BG -b 4096 -m 0 -O {EXT2_FEATURES} -d {SEED} -E offset={PART_OFFSET} {IMG} {PART_BLOCKS}")

kver = re.search(rb"AGNOS kernel v([0-9.]+)", open(KERNEL, "rb").read())
p("agnos kernel:", kver.group(1).decode() if kver else "(version string not found)", "-", KERNEL)
p("agnsh:       ", AGNSH_VER, "-", AGNSH)
p("cmdrs:       ", VERSION, "(this tree, --agnos)")

# ---- boot ----
accel = ["-cpu", "max"]
if os.environ.get("AGNOS_QEMU_TCG") != "1" and os.access("/dev/kvm", os.R_OK | os.W_OK):
    accel = ["-enable-kvm", "-cpu", "host"]


def free_port():
    s = socket.socket()
    s.bind(("127.0.0.1", 0))
    port = s.getsockname()[1]
    s.close()
    return port


VOID = re.compile(r"gnoboot: fail @|BdsDxe: failed to load|BootManagerMenuApp|Please select boot device")
qemu = None
for attempt in range(1, 7):
    shutil.copyfile(OVMF_VARS, WORK + "/vars.fd")
    open(SER, "w").close()
    port = free_port()
    qemu = subprocess.Popen([
        "qemu-system-x86_64", "-machine", "q35", "-m", "512M", *accel, "-smp", "1",
        "-drive", f"if=pflash,format=raw,readonly=on,file={OVMF_CODE}",
        "-drive", f"if=pflash,format=raw,file={WORK}/vars.fd",
        "-drive", f"file={IMG},format=raw,if=none,id=disk0",
        "-device", "nvme,drive=disk0,serial=AGNOS-BG",
        "-device", "qemu-xhci,id=xhci", "-device", "usb-kbd,bus=xhci.0",
        "-serial", f"file:{SER}", "-display", "none", "-no-reboot",
        "-monitor", f"tcp:127.0.0.1:{port},server,nowait",
    ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    void = False
    for _ in range(480):
        log = open(SER, "rb").read().decode("latin1")
        if "AGNOS kernel v" in log:
            break
        if VOID.search(log) or qemu.poll() is not None:
            void = True
            break
        time.sleep(0.25)
    if not void:
        break
    qemu.terminate()
    try:
        qemu.wait(timeout=5)
    except subprocess.TimeoutExpired:
        qemu.kill()
    p(f"  (VOID attempt {attempt}: the firmware never handed off -- retrying with fresh NVRAM)")
else:
    die("the firmware never handed off in 6 attempts (infrastructure, not cmdrs)")

KEYS = {" ": "spc", "\n": "ret", "-": "minus", ".": "dot", "/": "slash"}
ANSI = re.compile(r"\x1b\[[0-9;]*m")
checks = []


def check(name, held, got=None):
    checks.append(bool(held))
    p(("  ok    " if held else "  FAIL  ") + name + ("" if held or got is None else f"   got: {got!r}"))


try:
    mon = None
    for _ in range(60):
        try:
            mon = socket.create_connection(("127.0.0.1", port), timeout=1.0)
            break
        except OSError:
            time.sleep(0.2)
    if mon is None:
        die("no QEMU monitor")
    mon.settimeout(0.05)

    def drain():
        try:
            while True:
                mon.recv(65536)
        except OSError:
            pass

    def ser():
        try:
            return open(SER, "rb").read().decode("latin1")
        except OSError:
            return ""

    def typ(text):
        for ch in text:
            mon.sendall(("sendkey " + KEYS.get(ch, ch) + "\n").encode())
            time.sleep(0.08)
            drain()

    def run_wait(cmd, marker, timeout=30, settle=0.8):
        """Type `cmd` and Enter, and return everything printed until `marker`, or the timeout."""
        mark = len(ser())
        typ(cmd + "\n")
        deadline = time.time() + timeout
        while time.time() < deadline and marker not in ser()[mark:]:
            time.sleep(0.25)
        time.sleep(settle)
        return ser()[mark:]

    def prompt(binary="cmdrs"):
        """What `binary` printed before its trailer, escapes removed, or None."""
        seg = ANSI.sub("", run_wait(binary, "#END")).replace("\r", "")
        found = re.search(r"([^\n]*) #END", seg)
        return found.group(1).strip() if found else None

    def cd(d):
        if "] >" not in run_wait("cd " + d, "] >"):
            die("agnsh stopped returning its prompt after `cd " + d + "`")

    booted = False
    for _ in range(480):
        if "agnoshi" in ser():
            booted = True
            break
        time.sleep(0.25)
    check("agnsh reached its banner", booted)
    if not booted:
        p(ser()[-800:])
        sys.exit(1)
    time.sleep(1.0)
    typ("\n")                                   # the first keystroke is swallowed
    time.sleep(1.0)

    seg = run_wait("cmdrs --version", "] >").replace("\r", "")
    check("the binary under test is this tree's", ("cmdrs " + VERSION) in seg, seg[-80:])
    got = prompt()
    check("at /, cwd renders (HOME is / on agnos)", got in ("~", "/"), got)

    for d, want, name in CASES:
        cd(d)
        got = prompt()
        check(d + ": " + name, got == want, got)
        if "hunter2" in (got or ""):
            check(d + ": the secret stays out of the prompt", False, got)

    # The controls. Each must show what the fix is for, or the checks above prove nothing.
    # Each source of the directory alone. On agnos 1.57.18 and later the kernel answers, and
    # the `$PWD` fallback is what a kernel before it gets; agnsh passes both the same path.
    cd("/p1/sub")
    got = prompt("cmdrskernel")
    check("getcwd#113 alone gives the directory", got == "/p1/sub | 20", got)
    got = prompt("cmdrspwd")
    check("$PWD alone gives it too, as on a kernel before 1.57.18", got == "/p1/sub | 20", got)
    cd("/p1")
    got = prompt("cmdrsnocwd")
    check("control: with the old cwd stub, nothing cwd-based renders", got == "", got)
    cd("/p2")
    got = prompt("cmdrsnoguard")
    check("control: with no agnos pin guard, a link shows the secret", got == "/p2 | hunter2", got)
    cd("/p6")
    got = prompt("cmdrsnoguard")
    check("control: and so does a chain", got == "/p6 | hunter2", got)
    cd("/p2")
    got = prompt()
    check("the binary under test still refuses it after the controls", got == "/p2", got)
finally:
    if qemu is not None:
        qemu.terminate()
        try:
            qemu.wait(timeout=5)
        except subprocess.TimeoutExpired:
            qemu.kill()

held = len(checks) > 0 and all(checks)
p(f"agnos-boot-check: {'OK' if held else 'FAIL'} ({sum(checks)} of {len(checks)} checks)")
sys.exit(0 if held else 1)

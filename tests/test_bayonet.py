"""Check the bayonet coupling as a mechanism.

usage: python3 tests/test_bayonet.py [OPENSCAD] [--update]

Through tests/probe.scad, for couplings with inner and outer pins, CW and CCW
turns, 2 to 4 pins, and both consumers' sizes:
  - at entry (the halves at a common origin) the halves are clear, and the pin
    half lifts straight out;
  - turned by bayonet_locked_rotation() they are clear and a lift is blocked;
  - turned the wrong way, they collide;
  - turned on past locked, the lock stops the pin.
Then that the turn stop still holds just under bayonet_max_sweep_angle() and
the assert stops a sweep just over it; that the channel-depth assert holds at
its boundary; that a keyed pattern blocks a wrong seating that an even one
admits; the helper functions' values; shell_only; every example evaluating
without warnings; and each half's volume against tests/volumes.txt
(--update rewrites it after an intended geometry change).

Two halves "collide" when they overlap by more than 0.001 cu mm; faces that
only touch leave zero-volume slivers.
"""

import concurrent.futures as cf
import math
import os
import re
import struct
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROBE = os.path.join(ROOT, "tests", "probe.scad")
VOLUMES = os.path.join(ROOT, "tests", "volumes.txt")

# name: probe settings. The hopper and bioreactor rows are those consumers' sizes.
COUPLINGS = {
    "3 pins outer CW": {},
    "3 pins outer CCW": {"TD": '"CCW"'},
    "3 pins inner CW": {"DIR": '"inner"'},
    "3 pins inner CCW": {"DIR": '"inner"', "TD": '"CCW"'},
    "2 pins inner CW, r8": {"N": 2, "R": 8, "H": 8, "ED": 4, "SWEEP": 40, "DIR": '"inner"'},
    "4 pins outer CCW, hopper": {"N": 4, "R": 29.15, "PR": 3, "ALLOW": 0.3, "SH": 6.85, "H": 18, "ED": 12, "SWEEP": 25,
                                 "TD": '"CCW"', "ANGLES": "[0, 75, 180, 270]"},
    "3 pins outer CW, bioreactor mini": {"R": 5, "PR": 1.2, "H": 6, "ED": 3, "ANGLES": "[0, 95, 240]"},
}


def run(openscad, out, defines, export="binstl"):
    cmd = [openscad, "--hardwarnings", "--export-format", export, "-o", out]
    for k, v in defines.items():
        cmd += ["-D", f"{k}={v}"]
    return subprocess.run(cmd + [PROBE], capture_output=True, text=True)


def volume(path):
    d = open(path, "rb").read()
    n = struct.unpack_from("<I", d, 80)[0]
    v = 0.0
    for i in range(n):
        a = struct.unpack_from("<9f", d, 84 + i * 50 + 12)
        p, q, r = a[0:3], a[3:6], a[6:9]
        v += (p[0] * (q[1] * r[2] - q[2] * r[1]) - p[1] * (q[0] * r[2] - q[2] * r[0]) + p[2] * (q[0] * r[1] - q[1] * r[0])) / 6
    return abs(v)


def main():
    args = [a for a in sys.argv[1:] if a != "--update"]
    openscad = args[0] if args else "openscad"
    failures = []

    def report(label, ok, got):
        print(f"{'ok  ' if ok else 'FAIL'} {label}: {got}")
        if not ok:
            failures.append(label)

    tmp = tempfile.mkdtemp()
    counter = iter(range(10 ** 9))

    def overlap(defines):
        out = os.path.join(tmp, f"o{next(counter)}.stl")
        r = run(openscad, out, {"CHECK": '"pair"', **defines})
        if "top level object is empty" in r.stderr.lower():
            return 0.0
        if r.returncode != 0:
            raise RuntimeError(r.stderr.strip().splitlines()[-1])
        return volume(out)

    def locked(c):
        sweep = float(c.get("SWEEP", 30))
        return -sweep if c.get("TD", '"CW"') == '"CW"' else sweep

    def mechanism(item):
        name, c = item
        sweep, ed = float(c.get("SWEEP", 30)), float(c.get("ED", 5))
        lock = locked(c)
        sign = 1 if lock > 0 else -1
        pin_vol = 4 / 3 * math.pi * float(c.get("PR", 1)) ** 3
        entry_clear = overlap(c) <= 0.001
        entry_lifts = all(overlap({**c, "LIFT": f * ed}) <= 0.001 for f in (0.3, 0.6, 1.05))
        locked_clear = overlap({**c, "TURN": lock}) <= 0.001
        locked_held = overlap({**c, "TURN": lock, "LIFT": 0.5 * ed}) > 0.001
        wrong_way = overlap({**c, "TURN": -lock}) > 0.001
        stop = max(overlap({**c, "TURN": lock + sign * t}) for t in (4, 8, 12)) >= 0.1 * pin_vol
        return name, [("at entry the halves are clear and lift apart", entry_clear and entry_lifts),
                      ("locked, they are clear and a lift is blocked", locked_clear and locked_held),
                      ("turned the wrong way, they collide", wrong_way),
                      ("turned on past locked, the lock stops the pin", stop)]

    with cf.ThreadPoolExecutor(8) as ex:
        for name, results in ex.map(mechanism, COUPLINGS.items()):
            for label, ok in results:
                report(f"{name}: {label}", ok, "yes" if ok else "no")

    # The sweep limit: just under it the stop holds, just over it the assert stops the part.
    for name in ("3 pins outer CW", "4 pins outer CCW, hopper"):
        c = COUPLINGS[name]
        n = c.get("N", 3)
        r, pr, a = float(c.get("R", 10)), float(c.get("PR", 1)), float(c.get("ALLOW", 0.2))
        angles = [float(x) for x in c["ANGLES"].strip("[]").split(",")] if "ANGLES" in c else [360 / n * i for i in range(n)]
        gaps = [(angles[(i + 1) % len(angles)] - angles[i]) % 360 for i in range(len(angles))]
        limit = min(gaps) - 2 * math.degrees(math.atan2(pr + a / 2, r))
        under = {**c, "SWEEP": round(limit - 0.5, 2)}
        sign = 1 if locked(under) > 0 else -1
        turns = range(1, int(min(gaps) - limit + 0.5) + 2)
        stop = max(overlap({**under, "TURN": locked(under) + sign * t}) for t in turns) >= 0.1 * 4 / 3 * math.pi * pr ** 3
        r_over = run(openscad, os.path.join(tmp, "over.csg"), {**c, "CHECK": '"lock"', "SWEEP": round(limit + 0.5, 2)}, export="csg")
        refused = "no turn stop" in r_over.stderr
        report(f"{name}: sweep {limit - 0.5:.1f} keeps its stop, {limit + 0.5:.1f} is refused", stop and refused,
               f"stop {'held' if stop else 'lost'}, over the limit {'refused' if refused else 'accepted'}")

    # The channel stays inside the part: at the boundary it builds, just past it the assert stops it.
    edge = {"CHECK": '"lock"', "H": 10, "ED": 10 - 1.1}
    ok_at = run(openscad, os.path.join(tmp, "e1.csg"), edge, export="csg").returncode == 0
    past = run(openscad, os.path.join(tmp, "e2.csg"), {**edge, "ED": 10 - 1.09}, export="csg")
    report("the channel-depth assert holds at its boundary", ok_at and "breaks out of the bottom face" in past.stderr,
           f"at the boundary {'builds' if ok_at else 'refused'}, past it {'refused' if 'breaks out' in past.stderr else 'builds'}")

    # Keying: turned 120 degrees from entry, an even 3-pin half seats again; a keyed one does not.
    even = overlap({"TURN": 120}) <= 0.001
    keyed = overlap({"ANGLES": "[0, 95, 240]", "TURN": 120}) > 0.001
    report("an even pattern seats a third of a turn round; a keyed one is blocked", even and keyed,
           f"even {'seats' if even else 'blocked'}, keyed {'blocked' if keyed else 'seats'}")

    # Helper values.
    out = os.path.join(tmp, "f.echo")
    run(openscad, out, {"CHECK": '"functions"'}, export="echo")
    got = dict(re.findall(r'ECHO: "F (\S+) (.*)"', open(out).read()))
    # half-angle atan2(1.1, 10) = 6.2773 deg; 3 even pins: 120 - 2 * 6.2773; keyed [0, 95, 240]: 95 - 2 * 6.2773
    want = {"max_sweep_3": "107.445", "max_sweep_keyed": "82.4454", "locked_cw": "-30", "locked_ccw": "30",
            "half_angle": "6.2773", "keyed": "[0, 95, 240] order 1 even order 3"}
    report("helper functions", got == want, got)

    # shell_only: a bare tube, and a render says so.
    r = run(openscad, os.path.join(tmp, "so.stl"), {"CHECK": '"lock"', "SHELL_ONLY": "true"})
    v = volume(os.path.join(tmp, "so.stl")) if os.path.exists(os.path.join(tmp, "so.stl")) else 0
    tube = math.pi * ((10 + 2.5) ** 2 - (10 + 0.1) ** 2) * 10
    warned = "shell_only active in a render" in r.stderr
    report("shell_only gives the bare lock tube and warns when rendered", warned and abs(v - tube) / tube < 0.01,
           f"{v:.0f} of {tube:.0f} cu mm, {'warned' if warned else 'silent'}")

    for f in sorted(os.listdir(os.path.join(ROOT, "examples"))):
        r = subprocess.run([openscad, "--hardwarnings", "--export-format", "csg", "-o", os.path.join(tmp, "ex.csg"),
                            os.path.join(ROOT, "examples", f)], capture_output=True, text=True)
        bad = [l for l in (r.stdout + r.stderr).splitlines() if l.startswith(("WARNING", "ERROR"))]
        report(f"examples/{f} evaluates", r.returncode == 0 and not bad, bad[:1] or "clean")

    # Volumes of each half of each coupling, to 0.01 cu mm.
    rows = []
    for name, c in COUPLINGS.items():
        for h in ("pin", "lock"):
            out = os.path.join(tmp, f"v_{h}.stl")
            run(openscad, out, {**c, "CHECK": f'"{h}"'})
            rows.append(f"{name} | {h} | {volume(out):.2f}")
    if "--update" in sys.argv:
        open(VOLUMES, "w").write("\n".join(rows) + "\n")
        print(f"wrote {len(rows)} volumes")
    stored = open(VOLUMES).read().splitlines() if os.path.exists(VOLUMES) else []
    changed = [r for r in rows if r not in stored]
    report("every half's volume matches tests/volumes.txt", not changed and len(stored) == len(rows),
           f"{len(rows) - len(changed)} of {len(rows)} match" + (f"; changed: {changed[:2]}" if changed else ""))

    print("all checks passed" if not failures else f"{len(failures)} failed")
    sys.exit(1 if failures else 0)


main()

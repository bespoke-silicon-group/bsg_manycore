#!/usr/bin/env python3
#
#   regress_verdict.py
#
#   The verdict on one test of software/spmd's make regress.
#
#   regress_verdict.py <exit status of the test's make> <log of the test>
#
#   Prints "ok", or "FAILED: " and the reasons, and exits with status 0 if the
#   test passed, 1 if not. A test passes only if
#
#   - its make exited with status 0;
#   - every simulation in its log finished: there are as many
#     "RECEIVED BSG_FINISH PACKET from all pods" lines as simulations started
#     ("[INFO][TESTBENCH] BSG_MACHINE_GLOBAL_X"), and at least one. A directory
#     such as bsg_riscv_tests runs a simulation for each subtest;
#   - nothing in its log reports a failure or an error: BSG_FAIL, BSG_TIMEOUT,
#     BSG_ERROR, or an error report of the simulator. VCS goes on after $error,
#     $fatal and a failed assertion and exits with status 0, so these are
#     found in the log; Verilator stops at them with status 1.
#

import re
import sys

STARTED = re.compile(r"^\[INFO\]\[TESTBENCH\] BSG_MACHINE_GLOBAL_X\s+=", re.M)
FINISHED = re.compile(r"RECEIVED BSG_FINISH PACKET from all pods")

# (pattern, what it means); patterns are matched against each line.
FAILURES = [
    (re.compile(r"BSG_FAIL"), "BSG_FAIL"),
    (re.compile(r"BSG_TIMEOUT"), "BSG_TIMEOUT"),
    (re.compile(r"BSG_ERROR"), "BSG_ERROR"),
    # Verilator: "[<time>] %Error: <file>:<line>: Assertion failed in ...",
    # "%Fatal: ..."
    (re.compile(r"%(Error|Fatal)"), "simulator error"),
    # VCS: $error and $fatal ('Error: "<file>", <line>: <scope>: at time <t>'),
    # runtime errors ("Error-[<code>]"), and a failed assertion without an
    # action block ('"<file>", <line>: <scope>: started at <t> failed at <t>').
    (re.compile(r'^(Error|Fatal): "'), "simulator error"),
    (re.compile(r"^(Error|Fatal)-\["), "simulator error"),
    (re.compile(r'^"[^"]*", \d+: .* started at .* failed at '), "failed assertion"),
    # Xcelium: "xmsim: *E,<code> ..." and "xmsim: *F,<code> ..."
    (re.compile(r"^xmsim: \*[EF],"), "simulator error"),
]


def verdict(status, text):
    """Reasons the test failed; empty if it passed."""
    reasons = []
    if status != 0:
        reasons.append("make exited with status %d" % status)
    for pattern, meaning in FAILURES:
        for line in text.splitlines():
            if pattern.search(line):
                reasons.append("%s: %s" % (meaning, line.strip()[:100]))
                break
    started = len(STARTED.findall(text))
    finished = len(FINISHED.findall(text))
    if started == 0:
        reasons.append("no simulation started")
    elif finished != started:
        reasons.append("%d of %d simulations finished" % (finished, started))
    return reasons


def main():
    if len(sys.argv) != 3:
        sys.exit("usage: regress_verdict.py <exit status> <log>")
    status = int(sys.argv[1])
    try:
        with open(sys.argv[2], errors="replace") as f:
            text = f.read()
    except OSError as e:
        print("FAILED: no log (%s)" % e)
        sys.exit(1)
    reasons = verdict(status, text)
    if reasons:
        print("FAILED: " + "; ".join(reasons))
        sys.exit(1)
    print("ok")


if __name__ == "__main__":
    main()

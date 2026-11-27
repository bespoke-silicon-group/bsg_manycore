#!/usr/bin/env python3
#
#   sim_cpus.py
#
#   Place simulations on the host's cores, for software/spmd's make regress.
#
#   sim_cpus.py slots <threads> [<max>]
#
#     Prints one line for each simulation of <threads> threads that can run at
#     the same time as the others, at most <max> lines. A line is the CPUs of
#     one simulation, comma separated, one CPU of each of <threads> cores (the
#     other hardware threads of those cores stay idle). A simulation's cores
#     are in one NUMA node, and are taken a last-level cache at a time:
#
#     - A socket of 18 cores that share one L3: two 8-thread simulations, on
#       cores 0-7 and 8-15 of it; cores 16 and 17 are left over.
#     - A socket of eight 4-core chiplets, each with its own L3: four 8-thread
#       simulations, each on two whole chiplets.
#
#     Lines alternate between NUMA nodes, so that fewer simulations than lines
#     spread over the sockets. Where CPUs cannot be bound (not Linux), the
#     lines are empty, one for every <threads> cores.
#
#   sim_cpus.py run <cpu>[,<cpu>...] -- <command> [<argument>...]
#
#     Runs the command on the given CPUs and pins its threads, in the order
#     they were created, one to each CPU, in the order given. A Verilator
#     model runs worker 0 of its schedule on the main thread and worker k on
#     the k-th thread of its pool, so the workers that a threads_group
#     placement puts next to each other share a chiplet. (Verilator does not
#     pin its threads itself when the process is already bound to fewer CPUs
#     than the host has.)
#

import glob
import os
import signal
import subprocess
import sys
import time


def parse_cpu_list(text):
    """'0-3,8,10-11' -> [0, 1, 2, 3, 8, 10, 11]"""
    cpus = []
    for part in text.strip().split(","):
        if not part:
            continue
        if "-" in part:
            lo, hi = part.split("-")
            cpus.extend(range(int(lo), int(hi) + 1))
        else:
            cpus.append(int(part))
    return cpus


def read(path):
    try:
        with open(path) as f:
            return f.read().strip()
    except OSError:
        return None


def linux_cores():
    """Cores this process may use, as {node: {cache: [cpu, ...]}}, each core
    represented by its lowest allowed hardware thread."""
    allowed = os.sched_getaffinity(0)
    node_of = {}
    for path in glob.glob("/sys/devices/system/node/node[0-9]*/cpulist"):
        node = int(os.path.basename(os.path.dirname(path))[4:])
        for cpu in parse_cpu_list(read(path) or ""):
            node_of[cpu] = node
    nodes = {}
    seen = set()
    for cpu in sorted(allowed):
        sys_cpu = "/sys/devices/system/cpu/cpu%d" % cpu
        siblings = read(sys_cpu + "/topology/thread_siblings_list")
        core = tuple(sorted(set(parse_cpu_list(siblings)) & allowed)) if siblings else (cpu,)
        if core in seen:
            continue
        seen.add(core)
        # The last-level cache: the highest cache level this CPU has.
        cache, level = None, 0
        for index in glob.glob(sys_cpu + "/cache/index[0-9]*"):
            lvl = int(read(index + "/level") or 0)
            if lvl > level and read(index + "/type") in ("Unified", "Data"):
                level, cache = lvl, read(index + "/shared_cpu_list")
        if cache is None:
            cache = read(sys_cpu + "/topology/physical_package_id") or "0"
        nodes.setdefault(node_of.get(cpu, 0), {}).setdefault(cache, []).append(core[0])
    return nodes


def slots(threads, nodes):
    """CPU lists of the simulations that can run at once (see the top of the file)."""
    per_node = []
    for node in sorted(nodes):
        caches = sorted(nodes[node].values(), key=min)
        node_slots, spare = [], []
        if threads <= max(len(c) for c in caches):
            # A simulation fits in one cache: never split one across caches,
            # except for the cores each cache has left over.
            for cores in caches:
                n = len(cores) // threads
                node_slots += [cores[i * threads:(i + 1) * threads] for i in range(n)]
                spare += cores[n * threads:]
        else:
            # A simulation needs several caches: take whole caches in order.
            spare = [cpu for cores in caches for cpu in cores]
        while len(spare) >= threads:
            node_slots.append(spare[:threads])
            spare = spare[threads:]
        per_node.append(node_slots)
    result = []
    for i in range(max((len(s) for s in per_node), default=0)):
        result += [s[i] for s in per_node if i < len(s)]
    if not result:
        # More threads than a node has cores: take cores from several nodes.
        everything = [cpu for node in sorted(nodes) for cores in
                      sorted(nodes[node].values(), key=min) for cpu in cores]
        result = [everything[i:i + threads]
                  for i in range(0, len(everything) - threads + 1, threads)]
        if not result:
            print("sim_cpus.py: %d threads, but only %d cores" % (threads, len(everything)),
                  file=sys.stderr)
            result = [everything]
    return result


def physical_cores():
    try:
        out = subprocess.run(["sysctl", "-n", "hw.physicalcpu"], capture_output=True,
                             text=True, check=True).stdout
        return int(out)
    except (OSError, subprocess.CalledProcessError, ValueError):
        return os.cpu_count() or 1


def cmd_slots(argv):
    threads = int(argv[0])
    if threads < 1:
        sys.exit("sim_cpus.py: a simulation needs at least one thread, not %d" % threads)
    limit = int(argv[1]) if len(argv) > 1 and argv[1] else None
    if hasattr(os, "sched_getaffinity"):
        lines = [",".join(str(c) for c in s) for s in slots(threads, linux_cores())]
    else:
        lines = [""] * max(1, physical_cores() // threads)
    if limit:
        lines = lines[:limit]
    for line in lines:
        print(line)


def cmd_run(argv):
    cpus = [int(c) for c in argv[0].split(",")]
    if argv[1] != "--":
        sys.exit("usage: sim_cpus.py run <cpu>[,<cpu>...] -- <command> [<argument>...]")
    os.sched_setaffinity(0, cpus)
    proc = subprocess.Popen(argv[2:])

    def forward(signum, frame):
        proc.send_signal(signum)
    for signum in (signal.SIGINT, signal.SIGTERM, signal.SIGHUP):
        signal.signal(signum, forward)

    # Wait for the threads (a Verilator model creates its pool before it
    # starts simulating), then pin them in the order they were created.
    tids = []
    deadline = time.monotonic() + 60
    while proc.poll() is None and time.monotonic() < deadline:
        try:
            tids = sorted(int(t) for t in os.listdir("/proc/%d/task" % proc.pid))
        except OSError:
            break
        if len(tids) >= len(cpus):
            break
        time.sleep(0.01)
    for tid, cpu in zip(tids, cpus):
        try:
            os.sched_setaffinity(tid, {cpu})
        except OSError:
            pass
    rc = proc.wait()
    sys.exit(128 - rc if rc < 0 else rc)


if __name__ == "__main__":
    if len(sys.argv) >= 3 and sys.argv[1] == "slots":
        cmd_slots(sys.argv[2:])
    elif len(sys.argv) >= 5 and sys.argv[1] == "run":
        cmd_run(sys.argv[2:])
    else:
        sys.exit("usage: sim_cpus.py slots <threads> [<max>]\n"
                 "       sim_cpus.py run <cpu>[,<cpu>...] -- <command> [<argument>...]")

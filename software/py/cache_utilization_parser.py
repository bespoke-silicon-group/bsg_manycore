#!/usr/bin/env python3
# Takes a cache trace and prints the utilization, miss, stall and idle fraction

import pandas as pd
import re
import numpy as np
import seaborn as sns
import matplotlib.pyplot as plt

df = pd.read_csv("vcache_operation_trace.csv")
# Each line in vcache_operation_trace looks like:
#     replicant_tb_top.testbench.DUT.py[0].podrow.px[0].pod.south_vc_x[0].south_vc_row.vc_y[0].vc_x[1].vc.cache.vcache_prof,ld_lw
# To get the cache index we detect south/north and set the offset to 0/16 (respectively).
# Then we take the last occurrence of [] and add the number inside the brackets
def idx_map(s):
    i = 0 if "north" in s else 16
    i += int(re.findall("\[\d+\]",s)[-1].strip("[]"))
    return i

def is_stall(s):
    return "stall" in s

def is_idle(s):
    return "idle" in s

def is_miss(s):
    return "miss" in s

def is_active(s):
    return not (is_miss(s) or is_stall(s) or is_idle(s))

# Create new columns in the dataframe
df["idx"] = df.vcache.map(idx_map)
df["stall"] = df.operation.map(is_stall).map(int)
df["idle"] = df.operation.map(is_idle).map(int)
df["miss"] = df.operation.map(is_miss).map(int)
df["active"] = df.operation.map(is_active).map(int)

# Collect all the lines that occur on the same cycle, and take the sum
# of each to get the total for each operation on each cycle
window = 100
idxs = df.idx.unique()
dfs = df.groupby("cycle").sum()
dfs.active = np.convolve([1.0] * window, dfs.active/(np.float32(len(idxs))), "same")/np.float32(window)
dfs.miss = np.convolve([1.0] * window, dfs.miss/(np.float32(len(idxs))), "same")/np.float32(window)
dfs.stall = np.convolve([1.0] * window, dfs.stall/(np.float32(len(idxs))), "same")/np.float32(window)
dfs.idle = np.convolve([1.0] * window, dfs.idle/(np.float32(len(idxs))), "same")/np.float32(window)
dfs.index = dfs.index - dfs.index.min()

ax = sns.lineplot(data=dfs[["miss", "idle", "active", "stall"]])
_ = ax.set(ylabel=f"Fraction of Cycles (Window = {window} cycles)", ylim=(0,1.0), title="Overall Cache Utilization")
fig = ax.get_figure()
fig.savefig("cache_utilization.png")
plt.clf()

# Do the same, but for each cache.
for i in idxs:
    sub = df[df.idx==i].copy()
    sub.active = np.convolve([1.0] * window, sub.active, "same")/np.float32(window)
    sub.miss = np.convolve([1.0] * window, sub.miss, "same")/np.float32(window)
    sub.stall = np.convolve([1.0] * window, sub.stall, "same")/np.float32(window)
    sub.idle = np.convolve([1.0] * window, sub.idle, "same")/np.float32(window)
    sub = sub.set_index(["cycle"])
    sub.index = sub.index - sub.index.min()

    ax = sns.lineplot(data=sub[["miss", "idle", "active", "stall"]])
    _ = ax.set(ylabel=f"Fraction of Cycles (Window = {window} cycles)", ylim=(0,1.0), title=f"Cache Utilization for Index {i}")
    fig = ax.get_figure()
    fig.savefig(f"cache_{i}_utilization.png")
    plt.clf()


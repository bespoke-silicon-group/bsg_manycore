#!/usr/bin/env python

import pandas as pd
#pd.set_option('display.max_columns', None)
#pd.set_option('display.max_rows', None)
#pd.set_option('display.float_format', lambda x: '%.3f' % x)

import re
from pathlib import Path
import seaborn as sns
import matplotlib as plt
import matplotlib.pyplot as plt

sns.set()

df = pd.read_csv("vanilla_core_pc_hist.csv")


# Aggregate across all tiles
df = df.groupby(["pc", "operation"]).sum()


# Pivot, and then drop the "cycles" level of the multi-index.
df = pd.pivot_table(df, index = ["pc"], columns = "operation")
df = df.fillna(0)
df = df.droplevel(level=0, axis = "columns")

# Colors assigns colors to each stall/instruction type, but it ALSO assigns the order.
# The order in the dictonary will be used below when graphed
colors = {
    "instr": "lightgreen",
    "fp_instr": "green",
    "stall_remote_ld_wb": "cyan",
    "stall_remote_flw_wb": "teal",
    "stall_depend_idiv": "lightsteelblue",
    "stall_idiv_busy": "lavender",
    "stall_depend_fdiv": "slateblue",
    "stall_fdiv_busy": "blue",
    "stall_depend_imul": "mediumblue",
    "stall_bypass": "darkblue",
    "stall_amo_aq": "thistle",
    "stall_amo_rl": "plum",
    "stall_lr_aq": "violet",
    "stall_fence": "orchid",
    "stall_barrier": "purple",
    "stall_remote_req": "lightcoral",
    "stall_depend_local_load": "indianred",
    "stall_depend_group": "red",
    "stall_depend_global": "firebrick",
    "stall_depend_dram": "maroon",
    "stall_ifetch_wait": "peachpuff",
    "stall_remote_credit": "sandybrown",
    "jalr_miss" : "yellow",
    "branch_miss" : "gold",
    "stall_fcsr": "gray",
    "unknown": "black"}


# Use the colors key order above to stack the bars, 
# but first we have to pick stalls that are actually IN the CSV (not all are printed)
cols = [k for k in colors.keys() if k in df.columns]
ax = df[cols][(df.instr > 128) | (df.fp_instr > 128)].plot.bar(stacked = True, figsize=(50,15), color = colors)
ax.tick_params(labelsize=9)
fig = ax.get_figure()
fig.savefig("pc_hist.pdf")


# The plot above is the PC Histogram. Now group PC ranges by basic block.
tot_instrs = df.instr + df.fp_instr
bbs = (tot_instrs != tot_instrs.shift()).cumsum()
groups = df.groupby(bbs).sum()
groups.index = map(lambda x: bbs[bbs == x].index.min() + "-" + bbs[bbs == x].index.max(), groups.index)
cols = [k for k in colors.keys() if k in groups.columns]


ax = groups[cols].plot.bar(stacked = True, figsize=(15,15), color = colors)
ax.tick_params(labelsize=10)
fig = ax.get_figure()
fig.savefig("bb_hist.pdf")


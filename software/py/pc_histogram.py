#!/usr/bin/env python

import math
import argparse
import pandas as pd
#pd.set_option('display.max_columns', None)
#pd.set_option('display.max_rows', None)
#pd.set_option('display.float_format', lambda x: '%.3f' % x)

import re
from pathlib import Path
import seaborn as sns
sns.set()
import matplotlib as plt
import matplotlib.pyplot as plt

parser = argparse.ArgumentParser(description="Argument parser for pc_histogram.py")
parser.add_argument("--start", default="0x00000000", type=str, help="Start PC for PC/BB Histogram, in hex. e.g: 0x00000000")
parser.add_argument("--end", default="0xffffffff", type=str, help="End PC for PC/BB Histogram, in hex. e.g: 0x00000000")
parser.add_argument("--pathpat", default="./", type=str, help="Search Path for CSV Files")
args = parser.parse_args()

# Colors assigns colors to each stall/instruction type, but it ALSO assigns the order.
# The order in the dictonary will be used below when graphed
colors = {
    "Instruction": "lightgreen",
    "FPU Instruction": "green",
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
    "stall_fence": "magenta",
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
labelsize = 9 #point
def read_histogram_csv(p):
    df = pd.read_csv(p)
    df = df[(df.pc < args.end) & (df.pc > args.start)]
    # Aggregate across all tiles
    df = df.groupby(["pc", "operation"]).sum()
    df.rename({"instr": "Instruction",
               "fp_instr": "FPU Instruction"},
              inplace=True)
    return df

def write_pc_hist(df, p):
    # Pivot, and then drop the "cycles" level of the multi-index.
    df = pd.pivot_table(df, index = ["pc"], columns = "operation")
    df = df.fillna(0)
    df = df.droplevel(level=0, axis = "columns")
    
    # Use the colors key order above to stack the bars, 
    # but first we have to pick stalls that are actually IN the CSV (not all are printed)
    cols = [k for k in colors.keys() if k in df.columns]
    df = df[cols]
    # TODO: Set figure size based on label size
    height = df.shape[0] * (labelsize + 4) / 72
    ax = df.plot.barh(stacked = True, figsize=(11, height), color = colors)
    ax.set_ylabel("Program Counter")
    ax.set_xlabel(f"Cycles * 10^{math.floor(math.log10(ax.get_xlim()[1]))}")
    ax.set_title(f"HammerBlade Program Counter Cycles Histogram")
    ax.tick_params(labelsize=labelsize)
    fig = ax.get_figure()
    plt.gca().invert_yaxis()
    plt.tight_layout()
    fig.savefig( p / "pc_hist.pdf")
    plt.close(fig)

def write_bb_hist(df, p):
    # Pivot, and then drop the "cycles" level of the multi-index.
    df = pd.pivot_table(df, index = ["pc"], columns = "operation")
    df = df.fillna(0)
    df = df.droplevel(level=0, axis = "columns")
    
    # Group together floating point and regular instructionos
    tot_instrs = df.Instruction + df["FPU Instruction"]

    # Group together PCs that have the same number of executions
    bb_ranges = (tot_instrs != tot_instrs.shift()).cumsum()
    df = df.groupby(bb_ranges).sum()

    # Get the new grouped index
    bb_index = map(lambda x: bb_ranges[bb_ranges == x].index.min() + "-" + bb_ranges[bb_ranges == x].index.max(), df.index)
    df.index = bb_index
    ipc =  (df.Instruction + df["FPU Instruction"]) / df.sum(axis = 1)
    pct = 100.0 *  df.sum(axis = 1) / df.sum(axis = 1).sum()
    idx = df.index.to_series()
    idx = idx.combine(pct, lambda i, pct: f"{i} ({pct:.0f}%".rjust(10))
    idx = idx.combine(ipc, (lambda i, ipc: f"{i} @ {ipc:1.3f})"))
    df.index = idx

    # Use the colors key order above to stack the bars, 
    # but first we have to pick stalls that are actually IN the CSV (not all are printed)
    cols = [k for k in colors.keys() if k in df.columns]
    height = df.shape[0] * (labelsize + 4) / 72
    ax = df[cols].plot.barh(stacked = True, figsize=(11, height), color = colors)
    ax.set_ylabel("Basic Block Range (% Cycles @ IPC)")
    ax.set_xlabel(f"Cycles * 10^{math.floor(math.log10(ax.get_xlim()[1]))}")
    ax.set_title(f"HammerBlade Basic Block Cycles Histogram")
    ax.tick_params(labelsize=labelsize)
    fig = ax.get_figure()
    plt.gca().invert_yaxis()
    plt.tight_layout()
    fig.savefig(p / "bb_hist.pdf")
    plt.close(fig)

files = list(Path('./').glob(args.pathpat + "/vanilla_core_pc_hist.csv"))

if(len(files) == 0):
    print("Error! No vanilla_core_pc_hist.csv files found")
    exit()

agg = None
for f in files:
    p = f.parent
    print("Parsing: "  + str(f))
    df = read_histogram_csv(f)
    write_bb_hist(df, p)
    write_pc_hist(df, p)
    if(agg is not None):
        agg += df
    else:
        agg = df.copy()

if(len(files) > 1):
    print("Writing aggregate histograms")
    write_bb_hist(df, Path("./"))
    write_pc_hist(df, Path("./"))







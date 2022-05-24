#!/usr/bin/env python3

import math
import argparse
import pandas as pd
import re
from pathlib import Path
import seaborn as sns
sns.set()
import matplotlib as plt
import matplotlib.pyplot as plt
import numpy as np

parser = argparse.ArgumentParser(description="Argument parser for the HB Spacetime Heatmap (Remote Load Profiler)")
parser.add_argument("-s", "--source", default=[], action="append", help="Source tile y,x for remote requests. Can specify multiple.")
parser.add_argument("--first", default=0, type=int, help="First Cycle for Spacetime Graph")
parser.add_argument("--last", default=np.Inf, type=int, help="Last Cycle for Spacetime Graph")
parser.add_argument("--cycbin", default=None, type=int, help="Cycles per Bin in Heatmap. Cannot specify both --cycbin and --nbins simultaneously.")
parser.add_argument("--nbins", default=None, type=int, help="Number of Bins in Heatmap. Cannot specify both --cycbin and --nbins simultaneously.")

args = parser.parse_args()
args.source = set(tuple(map(int, c.split(","))) for c in args.source)

if(args.cycbin and args.nbins):
    print("Error! Cannot specify --cycbin and --nbins simultaneously")
    exit(1)
if(not args.nbins):
    args.nbins = 1000

# Set up figure formatting
# Rows per Inch
rpi = 4
# Columns per inch
cpi = 40

lsy = 10
lsx = 8
    
p = "remote_load_trace.csv"

df = pd.read_csv(p)

df = df[df.type != "icache"]
df = df[df.dest_y != 0] # Filter host packets

df = df[(df.dest_y == df.dest_y.min()) | (df.dest_y == df.dest_y.max())]

# Filter out specified sources
if(args.source != set()):
    srcs = (df.src_y.combine(df.src_x, lambda y,x: (int(y),int(x))))
    df = df[srcs.apply(lambda l: l in args.source)]

# Filter outside of first/last cycle
df = df[df.start_cycle > args.first]
df = df[df.start_cycle < args.last]

# Bin the CSV entries
stdf = df

# Create bins
if(args.cycbin):
    f = args.cycbin
else:
    f = int((stdf.start_cycle.max() - stdf.start_cycle.min()) / args.nbins)

r = pd.interval_range(start = stdf.start_cycle.min(), end = stdf.start_cycle.max(), freq = f)
bins = pd.cut(stdf.start_cycle, bins=r, precision=1)

stdf = stdf.groupby([bins, "dest_y", "dest_x"]).size()
stdf = stdf.unstack(level=0)
stdf = 100.0 *(stdf/f)

height = len(stdf.index) / rpi
width = len(stdf.columns) / cpi

print()
fig = plt.figure(figsize=(width, height))
ax = sns.heatmap(stdf, cbar_kws={'label': 'Percent of Cache Request Bandwidth (# Requests / # of Cycles in bin)'}, vmin =0, vmax=max(stdf.max().max(), 100.00))
ax.tick_params(axis='x', labelsize=lsx)
ax.tick_params(axis='y', labelsize=lsy)

ax.set_xlabel(f"Cycle Range ({len(stdf.columns)} bins of {f} Cycles)")
ax.set_ylabel(f"Cache Location (Y-X)")
ax.set_title(f"HammerBlade Spacetime Read & Write Request Heatmap")

plt.tight_layout()
fig.savefig("request_heatmap.pdf")
plt.close(fig)


ldf = df.copy()
ldf = ldf[ldf.type != "write"]
ldf = ldf.fillna(0)
ldf.latency = ldf.latency.astype(int)
r = pd.interval_range(start = ldf.start_cycle.min(), end = ldf.start_cycle.max(), freq = f)
bins = pd.cut(ldf.start_cycle, bins = r, precision=0)
#pd.IntervalIndex([*filter(lambda i: i.left < ldf.start_cycle.max(), bins)], retbins =True)
# TODO: Find out why reported latency is so high on some of these requests.
ldf.latency = ldf.latency.apply(lambda x: 1000 if x > 1000 else x)
ldf = ldf.groupby([bins, "dest_y", "dest_x"]).latency.max()
ldf = ldf.unstack(level=0)
ldf = ldf.fillna(0)

height = len(ldf.index) / rpi
width = len(ldf.columns) / cpi

fig = plt.figure(figsize=(width, height))
ax = sns.heatmap(ldf, cbar_kws={'label': 'Max Latency of Read Requests in Bin'})
ax.tick_params(axis='x', labelsize=lsx)
ax.tick_params(axis='y', labelsize=lsy)
ax.set_xlabel(f"Cycle Range ({len(ldf.columns)} bins of {f} Cycles)")
ax.set_ylabel(f"Cache Location (Y,X)")
ax.set_title(f"HammerBlade Spacetime Max Read Latency Heatmap")

plt.tight_layout()
fig.savefig("maxlat_heatmap.pdf")
plt.close(fig)




ldf = df.copy()
ldf = ldf[ldf.type != "write"]
ldf = ldf.fillna(0)
ldf.latency = ldf.latency.astype(int)

r = pd.interval_range(start = ldf.start_cycle.min(), end = ldf.start_cycle.max(), freq = f)
bins = pd.cut(ldf.start_cycle, bins = r, precision=0)
ldf.latency = ldf.latency.apply(lambda x: 1000 if x > 1000 else x)
ldf = ldf.groupby([bins, "dest_y", "dest_x"]).latency.mean()
ldf = ldf.unstack(level=0)
ldf = ldf.fillna(0)

height = len(ldf.index) / rpi
width = len(ldf.columns) / cpi

fig = plt.figure(figsize=(width, height))
ax = sns.heatmap(ldf, cbar_kws={'label': 'Mean Latency of Read Requests in Bin'})
ax.tick_params(axis='x', labelsize=lsx)
ax.tick_params(axis='y', labelsize=lsy)
ax.set_xlabel(f"Cycle Range ({len(ldf.columns)} bins of {f} Cycles)")
ax.set_ylabel(f"Cache Location (Y,X)")
ax.set_title(f"HammerBlade Spacetime Mean Read Latency Heatmap")

plt.tight_layout()
fig.savefig("meanlat_heatmap.pdf")
plt.close(fig)






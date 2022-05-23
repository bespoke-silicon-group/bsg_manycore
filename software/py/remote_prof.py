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
args = parser.parse_args()
args.source = set(tuple(map(int, c.split(","))) for c in args.source)

# Tommy, you can change this to point to different files.
p = "remote_load_trace.csv"

df = pd.read_csv(p)

df = df[df.type != "icache"]
df = df[df.dest_y != 0] # Filter host packets

df = df[(df.dest_y == df.dest_y.min()) | (df.dest_y == df.dest_y.max())]

# Filter out specified sources
if(args.source != []):
    srcs = (df.src_y.combine(df.src_x, lambda y,x: (int(y),int(x))))
    df = df[srcs.apply(lambda l: l in args.source)]

# Filter outside of first/last cycle
df = df[df.start_cycle > args.first]
df = df[df.start_cycle < args.last]

# Bin the CSV entries
stdf = df
nbins = 1000
bins = pd.cut(stdf.start_cycle,bins=nbins, precision = 0)

stdf = stdf.groupby([bins, "dest_y", "dest_x"]).size()
stdf = stdf.unstack(level=0)

# Set up figure formatting
# Rows per Inch
rpi = 4
height = len(stdf.index) / rpi
# Columns per inch
cpi = 18
width = len(stdf.columns) / cpi

fig = plt.figure(figsize=(width, height))
ax = sns.heatmap(stdf, cbar_kws={'label': 'Number of Requests'})
ax.tick_params(axis='x', labelsize=10)
ax.tick_params(axis='y', labelsize=10)
ax.set_xlabel(f"Cycle Range ({nbins} bins of {bins[bins.index[0]].right - bins[bins.index[0]].left} Cycles)")
ax.set_ylabel(f"Cache Location (Y-X)")
ax.set_title(f"HammerBlade Spacetime Request Heatmap")

plt.tight_layout()
fig.savefig("request_heatmap.pdf")
plt.close(fig)



ldf = df.copy()
ldf = ldf[ldf.type != "write"]
ldf = ldf.fillna(0)
ldf.latency = ldf.latency.astype(int)

nbins = 1000
bins = pd.cut(ldf.start_cycle, bins=nbins, precision = 0)
# TODO: Find out why reported latency is so high on some of these requests.
ldf.latency = ldf.latency.apply(lambda x: 1000 if x > 1000 else x)
ldf = ldf.groupby([bins, "dest_y", "dest_x"]).latency.max()
ldf = ldf.unstack(level=0)
ldf = ldf.fillna(0)

# Rows per Inch
rpi = 4
height = len(stdf.index) / rpi
# Columns per inch
cpi = 18
width = len(stdf.columns) / cpi

fig = plt.figure(figsize=(width, height))
ax = sns.heatmap(ldf, cbar_kws={'label': 'Max Latency of Requests in Bin'})
ax.tick_params(axis='x', labelsize=10)
ax.tick_params(axis='y', labelsize=10)
ax.set_xlabel(f"Cycle Range ({nbins} bins of {bins[bins.index[0]].right - bins[bins.index[0]].left} Cycles)")
ax.set_ylabel(f"Cache Location (Y,X)")
ax.set_title(f"HammerBlade Spacetime Max Latency Heatmap")

plt.tight_layout()
fig.savefig("maxlat_heatmap.pdf")
plt.close(fig)




ldf = df.copy()
ldf = ldf[ldf.type != "write"]
ldf = ldf.fillna(0)
ldf.latency = ldf.latency.astype(int)

nbins = 1000
bins = pd.cut(ldf.start_cycle, bins=nbins, precision = 0)
ldf.latency = ldf.latency.apply(lambda x: 1000 if x > 1000 else x)
ldf = ldf.groupby([bins, "dest_y", "dest_x"]).latency.mean()
ldf = ldf.unstack(level=0)
ldf = ldf.fillna(0)

# Rows per Inch
rpi = 4
height = len(stdf.index) / rpi
# Columns per inch
cpi = 18
width = len(stdf.columns) / cpi

fig = plt.figure(figsize=(width, height))
ax = sns.heatmap(ldf, cbar_kws={'label': 'Mean Latency of Requests in Bin'})
ax.tick_params(axis='x', labelsize=10)
ax.tick_params(axis='y', labelsize=10)
ax.set_xlabel(f"Cycle Range ({nbins} bins of {bins[bins.index[0]].right - bins[bins.index[0]].left} Cycles)")
ax.set_ylabel(f"Cache Location (Y,X)")
ax.set_title(f"HammerBlade Spacetime Mean Latency Heatmap")

plt.tight_layout()
fig.savefig("meanlat_heatmap.pdf")
plt.close(fig)






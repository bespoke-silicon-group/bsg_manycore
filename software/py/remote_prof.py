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
parser.add_argument("--filename", default="./remote_load_trace.csv", type=str, help="Remote Load Trace CSV File")

# Figure formatting parameters
# Rows per Inch
ROWS_PER_INCH = 4
# Columns per inch
COLS_PER_INCH = 40
# Labelsize y/x
LABELSIZE_Y = 10
LABELSIZE_X = 8

# It isn't useful to show huge latencies since it changes the heatmap
# scale. Use this to cap the maximum latency in a bin when plotting.
MAX_LATENCY = 1000

# Writes (normalized) request heatmap. Assumes each cache can process
# 1 READ OR WRITE request on each cycle.
def write_heatmap_req(df, f):
    # Create Bins
    r = pd.interval_range(start = df.start_cycle.min(), end = df.start_cycle.max(), freq = f)
    bins = pd.cut(df.start_cycle, bins=r, precision=1)
    
    # Bin, and count number of requests in each bin
    df = df.groupby([bins, "dest_y", "dest_x"]).size()
    df = df.unstack(level=0)

    # Normalize by dividing by cache bandwidth
    df = 100.0 *(df/f)
    
    # Generate Figure
    height = len(df.index) / ROWS_PER_INCH
    width = len(df.columns) / COLS_PER_INCH
    
    fig = plt.figure(figsize=(width, height))
    ax = sns.heatmap(df, cbar_kws={'label': 'Percent of Cache Request Bandwidth (# Requests / # of Cycles in bin)'}, vmin =0, vmax=max(df.max().max(), 100.00))
    ax.tick_params(axis='x', labelsize=LABELSIZE_X)
    ax.tick_params(axis='y', labelsize=LABELSIZE_Y)
    
    ax.set_xlabel(f"Cycle Range ({len(df.columns)} bins of {f} Cycles)")
    ax.set_ylabel(f"Cache Location (Y-X)")
    ax.set_title(f"HammerBlade Spacetime Read & Write Request Heatmap")
    
    plt.tight_layout()
    fig.savefig("request_heatmap.pdf")
    plt.close(fig)


# Writes mean read latency heatmap. Takes the maximum write latency of
# each request in each bucket. Writes are ignored since there is no way
# to track the latency of write responses
def write_heatmap_maxlat(df, f):
    # Remove write requests, since they do not have a valid latency
    df = df[df.type != "write"]
    df = df.fillna(0)
    df.latency = df.latency.astype(int)

    # Create Bins
    r = pd.interval_range(start = df.start_cycle.min(), end = df.start_cycle.max(), freq = f)
    bins = pd.cut(df.start_cycle, bins = r, precision=0)

    # TODO: Find out why reported latency is so high on some of these requests.
    df.latency = df.latency.apply(lambda x: MAX_LATENCY if x > MAX_LATENCY else x)

    # Bin, and determine max in each bin
    df = df.groupby([bins, "dest_y", "dest_x"]).latency.max()
    df = df.unstack(level=0)
    df = df.fillna(0)

    # Generate Figure
    height = len(df.index) / ROWS_PER_INCH
    width = len(df.columns) / COLS_PER_INCH

    fig = plt.figure(figsize=(width, height))
    ax = sns.heatmap(df, cbar_kws={'label': 'Max Latency of Read Requests in Bin'})
    ax.tick_params(axis='x', labelsize=LABELSIZE_X)
    ax.tick_params(axis='y', labelsize=LABELSIZE_Y)
    ax.set_xlabel(f"Cycle Range ({len(df.columns)} bins of {f} Cycles)")
    ax.set_ylabel(f"Cache Location (Y,X)")
    ax.set_title(f"HammerBlade Spacetime Max Read Latency Heatmap")

    plt.tight_layout()
    fig.savefig("maxlat_heatmap.pdf")
    plt.close(fig)



# Writes max read latency heatmap. Takes the maximum write latency of
# each request in each bucket. Writes are ignored since there is no way
# to track the latency of write responses
def write_heatmap_meanlat(df, f):
    # Remove write requests, since they do not have a valid latency
    df = df[df.type != "write"]
    df = df.fillna(0)
    df.latency = df.latency.astype(int)

    # Create Bins
    r = pd.interval_range(start = df.start_cycle.min(), end = df.start_cycle.max(), freq = f)
    bins = pd.cut(df.start_cycle, bins = r, precision=0)

    # TODO: Find out why reported latency is so high on some of these requests.
    df.latency = df.latency.apply(lambda x: MAX_LATENCY if x > MAX_LATENCY else x)

    # Bin, and determine max in each bin
    df = df.groupby([bins, "dest_y", "dest_x"]).latency.mean()
    df = df.unstack(level=0)
    df = df.fillna(0)
    
    # Generate Figure
    height = len(df.index) / ROWS_PER_INCH
    width = len(df.columns) / COLS_PER_INCH
    
    fig = plt.figure(figsize=(width, height))
    ax = sns.heatmap(df, cbar_kws={'label': 'Mean Latency of Read Requests in Bin'})
    ax.tick_params(axis='x', labelsize=LABELSIZE_X)
    ax.tick_params(axis='y', labelsize=LABELSIZE_Y)
    ax.set_xlabel(f"Cycle Range ({len(df.columns)} bins of {f} Cycles)")
    ax.set_ylabel(f"Cache Location (Y,X)")
    ax.set_title(f"HammerBlade Spacetime Mean Read Latency Heatmap")
    
    plt.tight_layout()
    fig.savefig("meanlat_heatmap.pdf")
    plt.close(fig)


# Parse Arguments
args = parser.parse_args()
args.source = set(tuple(map(int, c.split(","))) for c in args.source)

if(args.cycbin and args.nbins):
    print("Error! Cannot specify --cycbin and --nbins simultaneously")
    exit(1)
if(not args.nbins):
    args.nbins = 1000

# Create DataFrame
df = pd.read_csv(args.filename)

# Filter requests.
# 1. Remove icache requests
# 2. Remove packets to host
# 3. Keep cache packets
df = df[df.type != "icache"]
df = df[df.dest_y != 0] # Filter host packets
df = df[(df.dest_y == df.dest_y.min()) | (df.dest_y == df.dest_y.max())]

# 4. Filter outside of first/last cycle
df = df[df.start_cycle > args.first]
df = df[df.start_cycle < args.last]

# If a source was specified, filter out all other sources
if(args.source != set()):
    srcs = (df.src_y.combine(df.src_x, lambda y,x: (int(y),int(x))))
    df = df[srcs.apply(lambda l: l in args.source)]

# Determine bin duration (aka Frequency)
if(args.cycbin):
    f = args.cycbin
else:
    f = int((df.start_cycle.max() - df.start_cycle.min()) / args.nbins)

write_heatmap_req(df, f)
write_heatmap_meanlat(df, f)
write_heatmap_maxlat(df, f)

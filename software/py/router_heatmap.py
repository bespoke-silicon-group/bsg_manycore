#!env python3
# Preliminary script.

# For now, run this script from inside of the directory that contains router_stat.csv

import pandas as pd

# Read the CSV into pandas
df = pd.read_csv("router_stat.csv")

# Find the minimum and maximum cycle 
cmin = df.global_ctr.min()
cmax = df.global_ctr.max()
# Keep only minimum and maximum entries
df = df[(df.global_ctr == df.global_ctr.min()) | (df.global_ctr == df.global_ctr.max())]
# Stringify the minimum and maximum entries
df["Type"] = df.global_ctr.map({cmax: "End", cmin:"Start"})

# Map the Request and Response directions
df.XY_order = df.XY_order.map({0:"Response", 1:"Request"})

# Drop unnecessary rows
p = df.drop(["timestamp", "global_ctr", "tag"], axis = 1)
duration = cmax - cmin
p.idle = 100.0 * p.idle / duration
p.utilized = 100.0 * p.utilized / duration
p.stalled = 100.0 * p.stalled / duration
p.arbitrated = 100.0 * p.arbitrated / duration
# Map output directions to human readable strings
p.output_dir = p.output_dir.map({0: "0 - P (Router Output)",
                                 1:"1 - W (Router Output)",
                                 2:"2 - E (Router Output)",
                                 3:"3 - N (Router Output)",
                                 4:"4 - S (Router Output)",
                                 5:"5 - RW (Router Output)",
                                 6 :"6 - RE (Router Output)",
                                 15: "0 - P (Router Input)"})

# Map Y indicies to "Index (Type)"
ys = p.y[p.y != 0].unique()
type_map = {y_i:f"{y_i:02d} (T)" for y_i in ys}
type_map[ys.max()] = f"{ys.max():02d} (V)"
type_map[ys.min()] = f"{ys.min():02d} (V)"
type_map[0] = "00 (H)"
p.y = p.y.map(type_map)

# Create a hierarchical index
p = p.set_index(["Type", "XY_order", "output_dir", "y", "x"])

# Select the columns we will print.
f = p[["utilized", "stalled", "arbitrated", "idle"]].copy()
f = f.loc[("End")] - f.loc[("Start")]
f.columns = f.columns.map(lambda x : f"{x:>11}")

with open("router_heatmap.rpt", "w") as fd:
    data = f.unstack()
    for n in list(data.index.get_level_values('XY_order').unique()):
        for d in list(data.index.get_level_values('output_dir').unique()):
            row = data.loc[(n, d)]
            s = row.to_string(float_format="%5.1f")
            if(d == "0 - P (Router Input)"):
                s = s.replace("arbitrated", "Stalled by Arbitration")
            else:
                s = s.replace("arbitrated", "Utilized by Arbitration")
            fd.write(f"{d}, {n} Network")
            fd.write(s)
            fd.write("\n\n")

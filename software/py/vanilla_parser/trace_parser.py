#
#   vanilla_trace_parser.py
#
#   this class reads the vanilla.log, and returns the trace in an object form (e.g. a list of trace objects)
#
#   @author tommy
#


import sys
import os
import re
from . import common
import argparse


class VanillaTraceParser:


  # main public method
  def parse(self, filename):
    traces = []
    with open(filename, "r") as f:
      lines = f.readlines()
      for line in lines:
        stripped = line.strip()
        trace = self.parse_line(stripped)
        traces.append(trace)

    return traces


  # helper function
  def parse_line(self, line):
    trace = {}
    columns = line.split("|")
    columns = list(map(lambda c: c.strip(), columns))

    # first column
    # timestamp, x, y
    time_x_y = columns[0].split()
    trace["timestamp"] = int(time_x_y[0])
    trace["x"] = int(time_x_y[1])
    trace["y"] = int(time_x_y[2])

    # second column
    # int_pc, int_instr, rd, rd_write_val, stall_reason
    match = re.search("([0-9a-f]{8}) ([0-9a-f]{8})", columns[1])
    if match:
      trace["int_pc"] = match.group(1)
      trace["int_instr"] = match.group(2)

    match = re.search("x([0-9]{2})=([0-9a-f]{8})", columns[1])
    if match:
      trace["int_rd"] = int(match.group(1))
      trace["int_rd_val"] = match.group(2)

    match = re.search("STALL=(\w+)", columns[1])
    if match:
      trace["stall_reason"] = match.group(1)

    # third column
    # fp_pc, fp_instr, fp_rd, fp_rd_val
    match = re.search("([0-9a-f]{8}) ([0-9a-f]{8})", columns[2])
    if match:
      trace["fp_pc"] = match.group(1)
      trace["fp_instr"] = match.group(2)

    match = re.search("f([0-9]{2})=([0-9a-f]{8})", columns[2])
    if match:
      trace["fp_rd"] = int(match.group(1))
      trace["fp_rd_val"] = match.group(2)

    # fourth column
    # branch_target, local load/store
    match = re.search("bt=([0-9a-f]{8})", columns[3])
    if match:
      trace["bt"] = match.group(1)

    match = re.search("LL=\[([0-9a-f]{3})\]=([0-9a-f]{8})", columns[3])
    if match:
      trace["ll_addr"] = match.group(1)
      trace["ll_val"] = match.group(2)
  
    match = re.search("LS=\[([0-9a-f]{3})\]=([0-9a-f]{8})", columns[3])
    if match:
      trace["ls_addr"] = match.group(1)
      trace["ls_val"] = match.group(2)

    # fifth column
    # remote load/store
    match = re.search("RS=\[([0-9a-f]{8})\]=([0-9a-f]{8})", columns[4])
    if match:
      trace["rs_addr"] = match.group(1)
      trace["rs_val"] = match.group(2)

    match = re.search("RL=\[([0-9a-f]{8})\]=", columns[4])
    if match:
      trace["rl_addr"] = match.group(1)

    return trace

def add_args(parser):
    pass

def main(args):
  parser = VanillaTraceParser()
  traces = parser.parse(args.log)
  for trace in traces:
    print(trace)
    
# main() is just for testing purpose.
if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Vanilla log Parser")
    common.add_args(parser)
    args = parser.parse_args()
    main(args)

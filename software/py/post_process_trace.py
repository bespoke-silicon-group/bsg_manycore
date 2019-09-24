#!/usr/bin/python3

# Script to post process cycle accurate trace to
# produce instruction result trace.
#
# Usage: post_process_trace.py <cycle accurate trace> <elf file> <path to objdump>
#
# Input trace format:
# <timing info>: <int pc> <int instr> <int reg write> ... | <float pc> <float instr> <float reg write> ... |
#
# Output format:
# <timing info>: <pc> ( <instr> ) [<reg write>] <disassembly of instr>
#
# Bandhav Veluri
# 8/2/2019


import sys
import os
import re
from vanilla_trace_parser import *
from objdump_parser import *


class PostProcessTrace:


  # default constructor
  def __init__(self, objdump):
    self.obj_parser = ObjdumpParser(objdump)
    self.trace_parser = VanillaTraceParser()

    
  # main public function
  def process(self, log, program):
    traces = self.trace_parser.parse(log)
    dasm = self.obj_parser.parse(program)
    
    # create dictionary from pc (int) to disassembly
    dasm_dict = {}
    for da in dasm:
      key = int(da["pc"],16)
      dasm_dict[key] = da["dasm"] 

    for trace in traces:
      if "int_pc" in trace:
        line =  "%10d %2d %2d: " % (trace["timestamp"], trace["x"], trace["y"])
        line += "%s ( %s ) " % (trace["int_pc"], trace["int_instr"])

        if "int_rd" in trace:
          line += "x%2d=%08x " % (trace["int_rd"], int(trace["int_rd_val"], 16))
        elif "bt" in trace:
          line += "bt =%s " % trace["bt"]
        else:
          line += " "*13


        k = int(trace["int_pc"], 16)
        line += dasm_dict[k]
        
        print(line)
    
        



# main()
if __name__ == "__main__":
  
  # parameter checking
  if len(sys.argv) != 4:
    print("Usage: post_process_trace.py <cycle accurate trace> <elf file> <path to objdump>")
    sys.exit()

  for f in sys.argv[1:]:
    if not os.path.exists(f):
      print("Error: cannot find", f)
      sys.exit()

  log = sys.argv[1]
  program = sys.argv[2]
  objdump = sys.argv[3]
  
  # run
  ppt = PostProcessTrace(objdump)
  ppt.process(log, program)

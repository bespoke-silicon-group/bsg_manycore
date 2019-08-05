#!/usr/bin/python3

# Script to post process cycle accurate trace to
# produce instruction result trace.
#
# Usage: post_process_trace.py <cycle accurate trace> <elf file> <path to objdump>
#
# Input trace format:
# <timing info>: <int pc> <int instr> <int reg write> ... | <float pc> <float instr> <float reg write> ... |
#
# Bandhav Veluri
# 8/2/2019


import sys
import os
import re


if len(sys.argv) != 4:
  print("Usage: post_process_trace.py <cycle accurate trace> <elf file> <path to objdump>")
  sys.exit()

for f in sys.argv[1:]:
  if not os.path.exists(f):
    print("Error: cannot find", f)
    sys.exit()

try:
  input_trace_file = open(sys.argv[1], "r")
  input_trace = input_trace_file.read().split('\n')
  input_trace_file.close()
except IOError:
  print("Cannot open", sys.argv[1])
  sys.exit()

# ELF file correspoding to the trace
program = sys.argv[2]

# Path to objdump
objdump = sys.argv[3]


###############################################################
# Regular expressions matching members of input trace format

info_re       = re.compile('^(.*?:)')                               # group 1 matches info

int_pc_re     = re.compile('^.*:\s*([0-9a-f]{8})\s*')               # group 1 matches int_pc
int_instr_re  = re.compile('^.*:\s*[0-9a-f]{8}\s*([0-9a-f]{8})\s*') # group 1 matches int instr
int_reg_wb_re = re.compile('^.*:\s*[0-9a-f]{8}\s*[0-9a-f]{8}\s'
                           'x(\d*)=([0-9a-f]{8})\s*')               # group 1 matches rd, 2 matches wb data

fp_pc_re      = re.compile('^.*:.*\|\s*([0-9a-f]{8})\s*')           # group 1 matches fp pc
fp_instr_re   = re.compile('^.*:.*\|\s*[0-9a-f]{8}\s*'
                           '([0-9a-f]{8})\s*')                      # group 1 matches fp instr
fp_reg_wb_re  = re.compile('^.*:.*\|\s*[0-9a-f]{8}\s*'
                           '[0-9a-f]{8}\s*'
                           'f(\d*)=([0-9a-f]{8})\s*')               # group 1 matches fp rd, 2 matches fb wb data


#####################
# Filter out bubbles
trace_list = []

for line in input_trace:
  if re.match(int_pc_re, line) or re.match(fp_pc_re, line):
    trace_list.append(line)


###################################
# Function to decode pc

def decode(pc):
  """
  This function returns a dict with disassembly and rd
  of the instruction corresponding to pc. If the instruction
  doesn't write-back, rd field is set to None.
  """

  instr = {
    'hex': None
    ,'str': None
    ,'rd' : None
  }

  rv32_branch_op = 0x63
  rv32_store_op = 0x23
  rv32_fstore_op = 0x27
  no_wb_ops = [rv32_branch_op, rv32_store_op, rv32_fstore_op]

  # Disassemble the pc using objdump
  dasm_parse_cmd = objdump + " -j .text.dram"\
      " -M numeric -D --start-address=" + str(pc) + \
      " --stop-address=" + str(pc+4) + \
      " " + program + \
      " | tail -n 1"
  pc_dasm = os.popen(dasm_parse_cmd).read()[:-1]
  pc_dasm_re = re.compile('\s*([0-9a-f]*):[\s\t]*([0-9a-f]{8})\s*(.*)$')

  instr['hex'] = re.sub(pc_dasm_re, r'\2', pc_dasm)
  instr['str'] = re.sub(pc_dasm_re, r'\3', pc_dasm)
  instr_opcode = int('0x' + instr['hex'], 0) & 0x0000007f
  instr_rd = (int('0x' + instr['hex'], 0) & 0x00000f80) >> 7

  if (instr_rd != 0) & (instr_opcode not in no_wb_ops):
    instr['rd'] = instr_rd

  return instr


def log_instr(info, pc, instr, trace_indx, int_not_fp):
  instr_decode = decode(int('0x' + pc, 0))
  dasm_out = instr_decode['str']
  reg_wb_re = int_reg_wb_re if int_not_fp else fp_reg_wb_re

  if instr_decode['rd'] == None:
    wb_out = '            '
  else:
    j = trace_indx

    while True:
      if re.match(reg_wb_re, trace_list[j]):
        rd = re.match(reg_wb_re, trace_list[j]).group(1)
        data = re.match(reg_wb_re, trace_list[j]).group(2)
        if int(rd) == int(instr_decode['rd']):
          break

      j += 1

      if j == len(trace_list):
        sys.exit()

    wb_out = ('x' if int_not_fp else 'f') + rd + '=' + data
  
  print(info, pc, '(', instr, ')',  wb_out, dasm_out)


for i in range(len(trace_list)-1):
  line = trace_list[i]
  next_line = trace_list[i+1]

  ### Parse the trace line ###

  info = re.match(info_re, line).group(1)

  if re.match(int_pc_re, line):
    int_pc = re.match(int_pc_re, line).group(1)
  else:
    int_pc = None

  if re.match(int_pc_re, next_line):
    next_pc = re.match(int_pc_re, next_line).group(1)
  else:
    next_pc = None

  if re.match(int_instr_re, line):
    int_instr = re.match(int_instr_re, line).group(1)
  else:
    int_instr = None

  if re.match(int_reg_wb_re, line):
    int_rd = re.match(int_reg_wb_re, line).group(1)
    int_wb_data = re.match(int_reg_wb_re, line).group(2)
  else:
    int_rd = None
    int_wb_data = None

  if re.match(fp_pc_re, line):
    fp_pc = re.match(fp_pc_re, line).group(1)
  else:
    fp_pc = None

  if re.match(fp_instr_re, line):
    fp_instr = re.match(fp_instr_re, line).group(1)
  else:
    fp_instr = None

  if re.match(fp_reg_wb_re, line):
    fp_rd = re.match(fp_reg_wb_re, line).group(1)
    fp_wb_data = re.match(fp_reg_wb_re, line).group(2)
  else:
    fp_rd = None
    fp_wb_data = None


  ### Build the execution trace, instruction by instruction ###

  if (int_pc == next_pc) and int_pc != None:
    # icache miss, ignored
    continue
  else:
    if fp_instr != None:
      log_instr(info, fp_pc, fp_instr, i, 0)

    if int_instr != None:
      log_instr(info, int_pc, int_instr, i, 1)

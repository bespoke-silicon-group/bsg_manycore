#!/usr/bin/python3

# Script to generate function call log from PC trace and ELF file.
# Usage: func_call_log.py <pc_trace_file> <elf_file>
# 
# PC trace format:
# <line no>: <pc value in hex>
# 
# eg.:
# 1:00000000
# 2:00000001
# ...
# 234:0000fe45
# ...
#
# Note: line numbers are prepended in the func log output so that 
# they can be matched with correspoding line in the pc trace file.
#
# Bandhav Veluri
# 7/31/19

import sys
import os
import bisect

if len(sys.argv) != 3:
  print("Usage: func_call_log.py <pc_trace_file> <elf_file>")
  sys.exit()


###########################################
# Parse ELF to extract function list

# Command to parse input ELF to 
# generate "<start_address> <function_name>" pairs.
elf_parse_cmd = "readelf -s " \
                  + sys.argv[2] \
                  + ' | grep FUNC | awk \'{print $2 " " $8}\''

# Prepend _start as it's not parsed as a function
func_list = ['00000000 _start'] + (os.popen(elf_parse_cmd).read()).split('\n')[:-1]

# Sort func_list accroding to it's start address 
func_list.sort(key=(lambda x : int('0x' + x.split(' ')[0], 0)))

# List of function pointers
func_ptrs = [int('0x' + i.split(' ')[0], 0) for i in func_list]

#print(func_list)
#print(func_ptrs[0:100])


###########################################
# Parse PC tarce to extract PCs in a list

pc_trace_parse_cmd = "cat " + sys.argv[1]
pc_list = (os.popen(pc_trace_parse_cmd).read()).split('\n')[:-1]

#print(pc_list[0:100])

j = -1
for pc in pc_list:
  i = bisect.bisect_right(func_ptrs, int('0x' + pc.split(':')[1], 0)); 
  if i != j: print(pc.split(':')[0] + ':' + func_list[i-1].split(' ')[1])
  j = i

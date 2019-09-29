#
#   generate_stats.py
#
#   vanilla core stats extractor
# 
#   input: vanilla_stats.log
#   output: execution_stats.log
#
#   @author Borna
#
#   How to use:
#   python3 generate_stats.py {vanilla_stats.log}
#
#


import sys
import os
import re
from enum import Enum


instructions_list = ['instr','fadd','fsub','fmul','fsgnj','fsgnjn',\
                     'fsgnjx','fmin','fmax','fcvt_s_w','fcvt_s_wu',\
                     'fmv_w_x','feq','flt','fle','fcvt_w_s','fcvt_wu_s',\
                     'fclass','fmv_x_w','local_ld','local_st',\
                     'remote_ld','remote_st','local_flw','local_fsw',\
                     'remote_flw','remote_fsw','lr','lr_aq',\
                     'swap_aq','swap_rl','beq','bne','blt','bge','bltu',\
                     'bgeu','jalr','jal', 'sll',\
                     'slli','srl','srli','sra','srai','add','addi','sub',\
                     'lui','auipc','xor','xori','or','ori','and','andi',\
                     'slt','slti','sltu','sltiu','mul','mulh','mulhsu',\
                     'mulhu','div','divu','rem','remu','fence']

unkonwns_list = ['icache_miss', 'beq_miss', 'bne_miss', 'blt_miss',\
                'bge_miss', 'bltu_miss', 'bgeu_miss', 'jalr_miss']

stalls_list = ['stall_fp_remote_load','stall_fp_local_load',\
               'stall_depend','stall_depend_remote_load',\
               'stall_depend_local_load','stall_force_wb',\
               'stall_ifetch_wait','stall_icache_store',\
               'stall_lr_aq','stall_md,stall_remote_req','stall_local_flw']



class Stats:

  # default constructor
  def __init__(self):

    self.max_tile_groups = 1024
    self.num_tile_groups = 0
    self.timing_start_list = [0] * self.max_tile_groups
    self.timing_end_list = [0] * self.max_tile_groups
    self.total_execution_time = 0
    self.execution_stats_file = open("execution_stats.log", "w")
    self.stats_list = []
    self.max_time = 0 # Used to find the last bsg_print_statement (latest in time)

  # Create a list of stat types
  def define_stats_list(self, tokens):
    for token in tokens:
      self.stats_list += [token]
    return


  # Calculate execution time for tile groups and total
  def generate_stats_timing(self, tokens):
    if (tokens[self.stats_list.index('x')] == '0' and tokens[self.stats_list.index('y')] == '1'):
      if (int(tokens[self.stats_list.index('tag')]) < 1000):
        self.timing_start_list[int(tokens[self.stats_list.index('tag')])] = int(tokens[self.stats_list.index('time')])
        self.num_tile_groups += 1
      else: 
        self.timing_end_list[int(tokens[self.stats_list.index('tag')]) - 1000] = int(tokens[self.stats_list.index('time')])


  # Generate instruction stats
#  def generate_instruction_stats(self, tokens): 
#    if (tokens[self.stats_list.index('time')] < self.max_time):
#      return
#    self.max_time = tokens[self.stats_list.index('time')]
#    for token in tokens:
#      if token in instruction_list

    
   

  # Print execution timing for all tile groups 
  def print_stats_timing(self):
    self.execution_stats_file.write("Timing Stats ==========================================\n")
    for i in range (0, self.num_tile_groups):
      self.execution_stats_file.write("Tile group {}:\t{}\n".format(i, self.timing_end_list[i] - self.timing_start_list[i]))
      self.total_execution_time += (self.timing_end_list[i] - self.timing_start_list[i])
    self.execution_stats_file.write("Total(cycles):\t{}\n".format(self.total_execution_time))
    self.execution_stats_file.write("=======================================================\n")





  # default stats generator
  def generate_stats(self, input_file):
    self.vanilla_stats_file = open (input_file, "r")
    if (self.vanilla_stats_file.mode == 'r'):
      self.vanilla_stats_lines = self.vanilla_stats_file.readlines()

      for idx,line in enumerate(self.vanilla_stats_lines):
        tokens = line.split(",")

        # first line is list of stats types
        if (idx == 0):
          self.define_stats_list(tokens)
          continue

        # Generate timing stats 
        self.generate_stats_timing(tokens)

        # Generate instruction stats
        #self.generate_instruction_stats(tokens)


    self.print_stats_timing()
    

    # cleanup
    self.vanilla_stats_file.close()
    self.execution_stats_file.close()


# main()
if __name__ == "__main__":

  if len(sys.argv) != 2:
    print("wrong number of arguments.")
    print("python vanilla.log")
    sys.exit()
 
  input_file = sys.argv[1]

  st = Stats();
  st.generate_stats(input_file)


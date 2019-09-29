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
#   python3 generate_stats.py {manycore_dim_y} {manycore_dim_x} {vanilla_stats.log}
#
#   ex) python3 generate_stats.py 4 4 vanilla_stats.log
#
#   {manycore_dim_y}  Mesh Y dimension of manycore
#   {manycore_dim_x}  Mesh X dimension of manycore



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

miss_list = ['icache_miss', 'beq_miss', 'bne_miss', 'blt_miss',\
                'bge_miss', 'bltu_miss', 'bgeu_miss', 'jalr_miss']

stalls_list = ['stall_fp_remote_load','stall_fp_local_load',\
               'stall_depend','stall_depend_remote_load',\
               'stall_depend_local_load','stall_force_wb',\
               'stall_ifetch_wait','stall_icache_store',\
               'stall_lr_aq','stall_md,stall_remote_req','stall_local_flw']



class Stats:

  # default constructor
  def __init__(self, manycore_dim_y, manycore_dim_x):

    self.manycore_dim_y = manycore_dim_y
    self.manycore_dim_x = manycore_dim_x
    self.manycore_dim = manycore_dim_y * manycore_dim_x

    self.execution_stats_file = open("execution_stats.log", "w")

    self.max_tile_groups = 1024
    self.num_tile_groups = 0

    self.timing_start_list = [0] * self.max_tile_groups
    self.timing_end_list = [0] * self.max_tile_groups

    self.total_execution_time = 0
    self.total_instr_cnt = 0
    self.total_stall_cnt = 0
    self.total_miss_cnt = 0

    self.stats_list = []

    self.stats_instr_dict = {}
    self.stats_stall_dict = {}
    self.stats_miss_dict = {}


  # Create a list of stat types
  def define_stats_list(self, tokens):
    for token in tokens:
      self.stats_list += [token]
      if token in instructions_list:
        self.stats_instr_dict.update ({token: 0})
      elif token in stalls_list:
        self.stats_stall_dict.update ({token: 0})
      elif token in miss_list:
        self.stats_miss_dict.update ({token: 0})
    return


  # Calculate execution time for tile groups and total
  def generate_stats_timing(self, tokens):
    if (tokens[self.stats_list.index('x')] == '0' and tokens[self.stats_list.index('y')] == '1'):
      if (int(tokens[self.stats_list.index('tag')]) < 1000):
        self.timing_start_list[int(tokens[self.stats_list.index('tag')])] = int(tokens[self.stats_list.index('time')])
        self.num_tile_groups += 1
      else: 
        self.timing_end_list[int(tokens[self.stats_list.index('tag')]) - 1000] = int(tokens[self.stats_list.index('time')])

  # Sum up all other stats for all tiles based on the last bsg_print_stat instr
  def generate_stats_all(self):
      #other stats are only read once per tile from the end of file
      #i.e. if mesh dimensions are 4x4, only last 16 lines are needed 
      for idx in range(len(self.vanilla_stats_lines) - self.manycore_dim, len(self.vanilla_stats_lines)):
        line = self.vanilla_stats_lines[idx]
        tokens = line.split(",")

        for idx, token in enumerate(tokens):
          if self.stats_list[idx] in instructions_list:
            self.stats_instr_dict[self.stats_list[idx]] += int(token)
          elif self.stats_list[idx] in stalls_list:
            self.stats_stall_dict[self.stats_list[idx]] += int(token)
          elif self.stats_list[idx] in miss_list:
            self.stats_miss_dict[self.stats_list[idx]] += int(token)



  # Print execution timing for all tile groups 
  def print_stats_timing(self):
    self.execution_stats_file.write("Timing Stats:\n" + \
                                    "=======================================================\n")
    for i in range (0, self.num_tile_groups):
      self.execution_stats_file.write("{:10}{:5}{:25}{}\n".format("Tile group", i, ":", self.timing_end_list[i] - self.timing_start_list[i]))
      self.total_execution_time += (self.timing_end_list[i] - self.timing_start_list[i])
    self.execution_stats_file.write("{:40}{}\n".format("Total (cycles):", self.total_execution_time))
    self.execution_stats_file.write("=======================================================\n\n")


  # Print instruction stats for all tiles and total
  def print_stats_instructions(self):
    self.execution_stats_file.write("Instruction Stats:\n" + \
                                    "=======================================================\n")
    for instr, cnt in self.stats_instr_dict.items():
       if instr != 'instr':
         self.total_instr_cnt += cnt
     
    for instr, cnt in self.stats_instr_dict.items():
       self.execution_stats_file.write("{:35}%{:0>5.2f}{:10}\n".format(instr, (100 * cnt / self.total_instr_cnt), cnt))

    self.execution_stats_file.write("{:41}{:10}\n".format("Total", self.total_instr_cnt))
    self.execution_stats_file.write("=======================================================\n\n")
    return


  # Print stall stats for all tiles and total
  def print_stats_stalls(self):
    self.execution_stats_file.write("Stalls Stats:\n" + \
                                    "=======================================================\n")
    for stall, cnt in self.stats_stall_dict.items():
         self.total_stall_cnt += cnt
     
    for stall, cnt in self.stats_stall_dict.items():
       self.execution_stats_file.write("{:35}%{:0>5.2f}{:10}\n".format(stall, (100 * cnt / self.total_stall_cnt), cnt))

    self.execution_stats_file.write("{:41}{:10}\n".format("Total", self.total_stall_cnt))
    self.execution_stats_file.write("=======================================================\n\n")
    return


  # Print miss stats for all tiles and total
  def print_stats_miss(self):
    self.execution_stats_file.write("Miss Stats:\n" + \
                                    "=======================================================\n")
    for miss, cnt in self.stats_miss_dict.items():
         self.total_miss_cnt += cnt
     
    for miss, cnt in self.stats_miss_dict.items():
       self.execution_stats_file.write("{:35}%{:0>5.2f}{:10}\n".format(miss, (100 * cnt / self.total_miss_cnt), cnt))

    self.execution_stats_file.write("{:41}{:10}\n".format("Total", self.total_miss_cnt))
    self.execution_stats_file.write("=======================================================\n\n")
    return


  def print_stats_all(self):
    self.print_stats_timing()
    self.print_stats_instructions()
    self.print_stats_stalls()
    self.print_stats_miss()




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

    # generate all other stats
    self.generate_stats_all()

    # print all stats
    self.print_stats_all()
  

    # cleanup
    self.vanilla_stats_file.close()
    self.execution_stats_file.close()


# main()
if __name__ == "__main__":

  if len(sys.argv) != 4:
    print("wrong number of arguments.")
    print("python vanilla.log")
    sys.exit()
 
  manycore_dim_y = int(sys.argv[1])
  manycore_dim_x = int(sys.argv[2])
  input_file = sys.argv[3]

  st = Stats(manycore_dim_y, manycore_dim_x)
  st.generate_stats(input_file)


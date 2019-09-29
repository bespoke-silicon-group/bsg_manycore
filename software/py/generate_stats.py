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

        self.generate_stats_timing(tokens)


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


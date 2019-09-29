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
    self.start_list = [0] * self.max_tile_groups
    self.end_list = [0] * self.max_tile_groups
    self.total_execution_time = 0
    self.execution_stats_file = open("execution_stats.log", "w")

  def define_stats(self, stat_tokens):
    return


  # default stats generator
  def generate_stats(self, input_file):
    self.vanilla_stats_file = open (input_file, "r")
    if (self.vanilla_stats_file.mode == 'r'):
      self.vanilla_stats_lines = self.vanilla_stats_file.readlines()

      for idx,line in enumerate(self.vanilla_stats_lines):
        tokens = line.split(",")

        if (idx == 0):
          self.define_stats(tokens)
          continue

        self.execution_stats_file.write("Time: {}\tX: {}\tY: {}\tTGID: {}\n".format(tokens[0], tokens[1], tokens[2], tokens[3]))
        if (tokens[1] == '0' and tokens[2] == '1'):
          if (int(tokens[3]) < 1000):
            self.start_list[int(tokens[3])] = int(tokens[0])
            self.num_tile_groups += 1
          else: 
            self.end_list[int(tokens[3]) - 1000] = int(tokens[0])

    self.execution_stats_file.write("Tile groups: {}\n".format(self.num_tile_groups))

    for i in range (0, self.num_tile_groups):
      self.total_execution_time += self.end_list[i] - self.start_list[i]

    self.execution_stats_file.write("Total Execution cycles: {}".format(self.total_execution_time))

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


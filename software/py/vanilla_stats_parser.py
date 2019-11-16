#
#   vanilla_stats_parser.py
#
#   vanilla core stats extractor
# 
#   input: vanilla_stats.log
#   output: manycore_stats.log
#   output: tile_stats/tile_#_stats.log for all tiles 
#
#   @author Borna
#
#   How to use:
#   python3 generate_stats.py --dim-y {manycore_dim_y}  --dim-x {manycore_dim_x} 
#                             --per_tile (optional) --input {vanilla_stats.log}
#
#   ex) python3 --input generate_stats.py --dim-y 4 --dim-x 4 --per_tile --input vanilla_stats.log
#
#   {manycore_dim_y}  Mesh Y dimension of manycore default = 4
#   {manycore_dim_x}  Mesh X dimension of manycore default = 4
#   {per_tile}        Generate separate stats file for each tile default = False
#   {input}           Vanilla stats input file     default = vanilla_stats.log



import sys
import argparse
import os
import re
import csv
from enum import Enum
from collections import Counter






# These values are used by the manycore library in bsg_print_stat instructions
# they are added to the tag value to determine the tile group that triggered the stat
# and also the type of stat (stand-alone stat, start, or end)
# the value of these paramters should match their counterpart inside 
# bsg_manycore/software/bsg_manycore_lib/bsg_manycore.h
# Formatting for bsg_cuda_print_stat instructions
# < stat_type >
# Section                 Stat type  -   tile group id   -        tag
# of bits                <----2----> -  <------14----->  -   <-----16----->
# Stat type value: {"stat":0, "start":1, "end":2}
bsg_STAT_TAG_BITS   = 16
bsg_STAT_TG_ID_BITS = 14
bsg_STAT_TYPE_BITS  = 2
bsg_STAT_TAG_MASK   = ((1 << bsg_STAT_TAG_BITS) - 1)
bsg_STAT_TG_ID_MASK = ((1 << bsg_STAT_TG_ID_BITS) - 1)
bsg_STAT_TYPE_STAT  = 0
bsg_STAT_TYPE_START = 1
bsg_STAT_TYPE_END   = 2


bsg_TILE_GROUP_ORG_X = 0
bsg_TILE_GROUP_ORG_Y = 1

# Default input values
DEFAULT_MANYCORE_DIM_Y = 4
DEFAULT_MANYCORE_DIM_X = 4
DEFAULT_MODE = "total"
DEFAULT_INPUT_FILE = "vanilla_stats.log"




class VanillaStatsParser:

  # default constructor
  def __init__(self, manycore_dim_y, manycore_dim_x, per_tile_stat, input_file):

    self.manycore_dim_y = manycore_dim_y
    self.manycore_dim_x = manycore_dim_x
    self.manycore_dim = manycore_dim_y * manycore_dim_x
    self.per_tile_stat = per_tile_stat


    self.max_tile_groups = 1024
    self.num_tile_groups = 0

    self.timing_stat = Counter()

    self.total_execution_time = 0
    self.total_instr_cnt = 0
    self.total_stall_cnt = 0
    self.total_miss_cnt = 0

    self.tile_stat = Counter() 
    self.manycore_stat = Counter()


    # formatting parameters for aligned printing
    type_format = {"name"      : "{:<35}",
                   "type"      : "{:>15}",
                   "int"       : "{:>15}",
                   "float"     : "{:>15.4f}",
                   "percent"   : "{:>15.2f}"
                  }


    self.print_format = {"timing_header": type_format["name"] + type_format["type"] + type_format["type"]    + "\n",
                         "timing_data"  : type_format["name"] + type_format["int"]  + type_format["percent"] + "\n",
                         "instr_header" : type_format["name"] + type_format["int"]  + type_format["type"]    + "\n",
                         "instr_data"   : type_format["name"] + type_format["int"]  + type_format["percent"] + "\n",
                         "stall_header" : type_format["name"] + type_format["type"] + type_format["type"]    + "\n",
                         "stall_data"   : type_format["name"] + type_format["int"]  + type_format["percent"] + "\n",
                         "miss_header"  : type_format["name"] + type_format["type"] + type_format["type"]    + type_format["type"]  + "\n",
                         "miss_data"    : type_format["name"] + type_format["int"]  + type_format["int"]     + type_format["float"] + "\n",
                         "line_break"   : '=' * 90 + "\n"
                        }



    # list of instructions, operations and events parsed from vanilla_stats.log
    # populated by reading the header of input file 
    self.stats_list  = []
    self.instr_list  = []
    self.miss_list   = []
    self.stalls_list = []


    # Call generate_stats after initialization
    self.generate_stats(input_file)
    return




  # print a line of stat into stats file based on stat type
  def __print_stat(self, stat_file, stat_type, *argv):
    stat_file.write(self.print_format[stat_type].format(*argv));
    return


  # Decodes the tag value of the stat to determine the type of 
  # stat, the tile group id of sending tile, and the tag value 
  def __decode_stat_val(self, stat_val):
    stat_type  = stat_val >> (bsg_STAT_TG_ID_BITS + bsg_STAT_TAG_BITS)
    stat_tg_id = (stat_val >> bsg_STAT_TAG_BITS) & bsg_STAT_TG_ID_MASK
    stat_tag   = stat_val & bsg_STAT_TAG_MASK
    return (stat_type, stat_tg_id, stat_tag)
    


  # go though the input traces and extract start and end time of 
  # each tile group execution, and subtract to create a list of 
  # timing status for each tile group
  # return number of tile groups and the timing stats
  def __generate_timing_stats(self, traces):

    timing_start = Counter()
    timing_end = Counter()
    timing_stat = Counter()
    num_tile_groups = 0

    for trace in traces:
      y = trace["y"]
      x = trace["x"]
      stat_val = trace["tag"]
      stat_type, stat_tg_id, stat_tag = self.__decode_stat_val(stat_val)
      # Only count those coming from the origin tile 
      # (bsg_TILE_GROUP_ORG_X,bsg_TILE_GROUP_ORG_Y)
      if (x == bsg_TILE_GROUP_ORG_X and y == bsg_TILE_GROUP_ORG_Y):
        # Separate depending on stat type (start or end)
        if(stat_type == bsg_STAT_TYPE_START):
          timing_start[stat_tg_id] = trace["time"]
          num_tile_groups += 1
        elif (stat_type == bsg_STAT_TYPE_END):
          timing_end[stat_tg_id] = trace["time"]

    # Generate execution time by subtracting start time from end time
    timing_stat = timing_end - timing_start

    return num_tile_groups, timing_stat


  # Generate a stats dictionary for each tile containing the stat and it's aggregate count
  # other than timing, tile stats are only read once per tile from the end of file
  # i.e. if mesh dimensions are 4x4, only last 16 lines are needed 
  def __generate_tile_stat (self, traces):
    tile_stat = [[Counter() for x in range(self.manycore_dim_x)] for y in range(self.manycore_dim_y)]
    trace_idx = len(traces)
    for y in range(self.manycore_dim_y):
      for x in range(self.manycore_dim_x):
        trace_idx -= 1
        trace = traces[trace_idx]
        for stat in self.stats_list:
          tile_stat[y][x][stat] = trace[stat]
        for instr in self.instr_list:
          tile_stat[y][x][instr] = trace[instr]
        for stall in self.stalls_list:
          tile_stat[y][x][stall] = trace[stall]
        for miss in self.miss_list:
          tile_stat[y][x][miss] = trace[miss]
    return tile_stat


  # print execution timing for the entire manycore 
  def __print_manycore_stats_timing(self, stat_file):
    # For total execution time, we only sum up the execution time of origin tile in tile groups
    # The origin tile's relative coordinates is always 0,0 
    stat_file.write("Timing Stats\n")
    self.__print_stat(stat_file, "timing_header", "tile group", "exec time(ps)", "share (%)")
    self.__print_stat(stat_file, "line_break")


    for i in range (0, self.num_tile_groups):
      self.__print_stat(stat_file, "timing_data", i,
                                   self.timing_stat[i],
                                   (self.timing_stat[i] / self.total_execution_time * 100))

    self.__print_stat(stat_file, "timing_data", "total",
                                 self.total_execution_time,
                                 (self.total_execution_time / self.total_execution_time * 100))
    self.__print_stat(stat_file, "line_break")
    return


  # print instruction stats for the entire manycore
  def __print_manycore_stats_instructions(self, stat_file):

    stat_file.write("Instruction Stats\n")
    self.__print_stat(stat_file, "instr_header", "instruction", "count", "share (%)")
    self.__print_stat(stat_file, "line_break")

   
    # Print instruction stats for manycore
    for instr in self.instr_list:
       self.__print_stat(stat_file, "instr_data", instr,
                                    self.manycore_stat[instr],
                                    (100 * self.manycore_stat[instr] / self.total_instr_cnt))

    self.__print_stat(stat_file, "instr_data", "instr_total",
                                 self.total_instr_cnt, 
                                 (100 * self.total_instr_cnt / self.total_instr_cnt))
    self.__print_stat(stat_file, "line_break")
    return


  # print instruction stats for each tile in a separate file 
  # y,x are tile coordinates 
  def __print_per_tile_stats_instructions(self, y, x, stat_file):

    stat_file.write("Instruction Stats\n")
    self.__print_stat(stat_file, "instr_header", "instruction", "count", " share (%)")
    self.__print_stat(stat_file, "line_break")

    # Calculate total instruction count for tile 
    tile_total_instr_cnt = 0
    for instr in self.instr_list:
      if (instr != "instr_total"):
        tile_total_instr_cnt += self.tile_stat[y][x][instr]
   
    # Print instruction stats for manycore
    for instr in self.instr_list:
       self.__print_stat(stat_file, "instr_data", instr,
                                    self.tile_stat[y][x][instr],
                                    (100 * self.tile_stat[y][x][instr] / tile_total_instr_cnt))

    self.__print_stat(stat_file, "instr_data", "instr_total",
                                 tile_total_instr_cnt, 
                                 (100 * tile_total_instr_cnt / tile_total_instr_cnt))
    self.__print_stat(stat_file, "line_break")
    return




  # print stall stats for the entire manycore
  def __print_manycore_stats_stalls(self, stat_file):
    stat_file.write("Stall Stats\n")
    self.__print_stat(stat_file, "stall_header", "stall", "cycles", "share (%)")
    self.__print_stat(stat_file, "line_break")

    # Print stall stats for manycore
    for stall in self.stalls_list:
       self.__print_stat(stat_file, "stall_data", stall,
                                    self.manycore_stat[stall],
                                    (100 * self.manycore_stat[stall] / self.total_stall_cnt))

    self.__print_stat(stat_file, "stall_data", "stall_total",
                                 self.total_stall_cnt,
                                 (100 * self.total_stall_cnt / self.total_stall_cnt))
    self.__print_stat(stat_file, "line_break")
    return


  # print stall stats for each tile in a separate file
  # y,x are tile coordinates 
  def __print_per_tile_stats_stalls(self, y, x, stat_file):
    stat_file.write("Stall Stats\n")
    self.__print_stat(stat_file, "stall_header", "stall", "cycles", "share (%)")
    self.__print_stat(stat_file, "line_break")

    # Calculate total stall count for tile
    tile_total_stall_cnt = 0
    for stall in self.stalls_list:
      tile_total_stall_cnt += self.tile_stat[y][x][stall]

    # Print stall stats for manycore
    for stall in self.stalls_list:
       self.__print_stat(stat_file, "stall_data", stall,
                                    self.tile_stat[y][x][stall],
                                    (100 * self.tile_stat[y][x][stall] / tile_total_stall_cnt))

    self.__print_stat(stat_file, "stall_data", "stall_total",
                                 tile_total_stall_cnt,
                                 (100 * tile_total_stall_cnt / tile_total_stall_cnt))
    self.__print_stat(stat_file, "line_break")
    return



  # print miss stats for the entire manycore
  def __print_manycore_stats_miss(self, stat_file):
    stat_file.write("Miss Stats\n")
    self.__print_stat(stat_file, "miss_header", "unit", "miss", "total", "hit rate")
    self.__print_stat(stat_file, "line_break")

    for miss in self.miss_list:
       # Find total number of operations for that miss
       # If operation is icache, the total is total # of instruction
       # otherwise, search for the specific instruction
       if (miss == "miss_icache"):
         operation = "icache"
         operation_cnt = self.manycore_stat["instr_total"]
       else:
         operation = miss.replace("miss_", "instr_")
         operation_cnt = self.manycore_stat[operation]
       miss_cnt = self.manycore_stat[miss]
       hit_rate = 1 if operation_cnt == 0 else (1 - miss_cnt/operation_cnt)
         
       self.__print_stat(stat_file, "miss_data", operation, miss_cnt, operation_cnt, hit_rate )
    self.__print_stat(stat_file, "line_break")
    return


  # print miss stats for each tile in a separate file
  # y,x are tile coordinates 
  def __print_per_tile_stats_miss(self, y, x, stat_file):
    stat_file.write("Miss Stats\n")
    self.__print_stat(stat_file, "miss_header", "unit", "miss", "total", "hit rate")
    self.__print_stat(stat_file, "line_break")

    for miss in self.miss_list:
       # Find total number of operations for that miss
       # If operation is icache, the total is total # of instruction
       # otherwise, search for the specific instruction
       if (miss == "miss_icache"):
         operation = "icache"
         operation_cnt = self.tile_stat[y][x]["instr_total"]
       else:
         operation = miss.replace("miss_", "instr_")
         operation_cnt = self.tile_stat[y][x][operation]
       miss_cnt = self.tile_stat[y][x][miss]
       hit_rate = 1 if operation_cnt == 0 else (1 - miss_cnt/operation_cnt)
         
       self.__print_stat(stat_file, "miss_data", operation, miss_cnt, operation_cnt, hit_rate )
    self.__print_stat(stat_file, "line_break")
    return


  # Calculate aggregate manycore stats dictionary by summing 
  # all per tile stats dictionaries
  def __generate_manycore_stat_all(self, tile_stat, timing_stat):

    # Create a dictionary and initialize elements to zero
    manycore_stat = Counter()
    total_instr_cnt = 0
    total_stall_cnt = 0
    total_miss_cnt = 0
    total_execution_time = 0

    for y in range(self.manycore_dim_y):
      for x in range(self.manycore_dim_x):

        # Calculate total instruction count for each tile and for manycore
        for instr in self.instr_list: 
          manycore_stat[instr] += tile_stat[y][x][instr]
          if (instr != "instr_total"):
            total_instr_cnt += tile_stat[y][x][instr]
        # Calculate total stall count for each tile and for manycore
        for stall in self.stalls_list: 
          manycore_stat[stall] += tile_stat[y][x][stall]
          total_stall_cnt += tile_stat[y][x][stall]

        # Calculate total miss count for each tile and for manycore
        for miss in self.miss_list: 
          manycore_stat[miss] += tile_stat[y][x][miss]
          total_miss_cnt += tile_stat[y][x][miss]

    # Sum up execution time for all tile groups to get total manycore execution time
    total_execution_time = sum(self.timing_stat.values())

    return total_execution_time, total_instr_cnt, total_stall_cnt, total_miss_cnt, manycore_stat
 


  # prints all four types of stats, timing, instruction,
  # miss and stall for the entire manycore 
  def print_manycore_stats_all(self):
    manycore_stats_file = open("manycore_stats.log", "w")
    self.__print_manycore_stats_timing(manycore_stats_file)
    self.__print_manycore_stats_miss(manycore_stats_file)
    self.__print_manycore_stats_stalls(manycore_stats_file)
    self.__print_manycore_stats_instructions(manycore_stats_file)
    manycore_stats_file.close()

  # prints all four types of stats, timing, instruction,
  # miss and stall for each tile in a separate file  
  def print_per_tile_stats_all(self):
    stats_path = os.getcwd() + "/tile_stats/"
    if not os.path.exists(stats_path):
      os.mkdir(stats_path)
    for y in range(self.manycore_dim_y):
      for x in range(self.manycore_dim_x):
        stat_file = open( (stats_path + "tile_" + str(y) + "_" + str(x) + "_stats.log"), "w")
        #self.print_per_tile_stats_timing(y, x, stat_file)
        self.__print_per_tile_stats_miss(y, x, stat_file)
        self.__print_per_tile_stats_stalls(y, x, stat_file)
        self.__print_per_tile_stats_instructions(y, x, stat_file)
        stat_file.close()


  # main public method
  # default stats generator
  def generate_stats(self, input_file):
    self.traces = []
    with open(input_file) as f:
      csv_reader = csv.DictReader (f, delimiter=",")

      # Generate list of instruction/miss/stall types
      header = csv_reader.fieldnames
      for item in header:
        if (item.startswith('instr_')):
          self.instr_list += [item]
        elif (item.startswith('miss_')):
          self.miss_list += [item]
        elif (item.startswith('stall_')):
          self.stalls_list += [item]
        else:
          self.stats_list += [item]


      for row in csv_reader:
        trace = {}
        for stat in self.stats_list:
          trace[stat] = int(row[stat])
        for instr in self.instr_list:
          trace[instr] = int(row[instr])
        for stall in self.stalls_list:
          trace[stall] = int(row[stall])
        for miss in self.miss_list:
          trace[miss] = int(row[miss])
        self.traces.append(trace)

    # generate timing stats for each tile group 
    self.num_tile_groups, self.timing_stat = self.__generate_timing_stats(self.traces)

    # generate per tile stat dictionary with stat type and count 
    self.tile_stat = self.__generate_tile_stat(self.traces)

    # Calculate total aggregate stats for manycore
    # By summing up per_tile stat counts
    (self.total_execution_time, self.total_instr_cnt, self.total_stall_cnt, self.total_miss_cnt, self.manycore_stat) = \
    self.__generate_manycore_stat_all(self.tile_stat, self.timing_stat)

    # return timing_stat (list of tile group execution times)
    # and per_tile stats dictionary
    return (self.timing_stat, self.manycore_stat, self.tile_stat)



# parses input arguments
def parse_args():
  parser = argparse.ArgumentParser(description="Vanilla Stats Parser")
  parser.add_argument("--input", default=DEFAULT_INPUT_FILE, type=str,
                      help="Vanilla stats log file")
  parser.add_argument("--per_tile", default=False, action='store_true',
                      help="Also generate separate stats files for each tile.")
  parser.add_argument("--dim-y", default=DEFAULT_MANYCORE_DIM_Y, type=int,
                      help="Manycore Y dimension")
  parser.add_argument("--dim-x", default=DEFAULT_MANYCORE_DIM_X, type=int,
                      help="Manycore X dimension")
  args = parser.parse_args()

  return args


# main()
if __name__ == "__main__":
  args = parse_args()
  
  st = VanillaStatsParser(args.dim_y, args.dim_x, args.per_tile, args.input)
  st.print_manycore_stats_all()
  if(st.per_tile_stat):
    st.print_per_tile_stats_all()

  


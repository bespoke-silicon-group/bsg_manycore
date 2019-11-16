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
# Section                 Stat type  -   y cord   -   x cord   -    tile group id   -        tag
# of bits                <----2----> -   <--6-->  -   <--6-->  -   <------10----->  -   <-----8----->
# Stat type value: {"stat":0, "start":1, "end":2}
bsg_STAT_TAG_BITS   = 8
bsg_STAT_TG_ID_BITS = 10
bsg_STAT_X_BITS     = 6
bsg_STAT_Y_BITS     = 6
bsg_STAT_TYPE_BITS  = 2
bsg_STAT_TAG_MASK   = ((1 << bsg_STAT_TAG_BITS) - 1)
bsg_STAT_TG_ID_MASK = ((1 << bsg_STAT_TG_ID_BITS) - 1)
bsg_STAT_X_MASK     = ((1 << bsg_STAT_X_BITS) - 1)
bsg_STAT_Y_MASK     = ((1 << bsg_STAT_Y_BITS) - 1)
bsg_STAT_TYPE_STAT  = 0
bsg_STAT_TYPE_START = 1
bsg_STAT_TYPE_END   = 2


bsg_TILE_GROUP_ORG_X = 0
bsg_TILE_GROUP_ORG_Y = 1
bsg_ORG_X = 0
bsg_ORG_Y = 1

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

    self.tile_group_timing_stat = Counter()
    self.tile_group_cycle_stat = Counter()

    self.tile_stat = Counter() 
    self.manycore_stat = Counter()


    # formatting parameters for aligned printing
    type_format = {"name"      : "{:<35}",
                   "type"      : "{:>15}",
                   "int"       : "{:>15}",
                   "float"     : "{:>15.4f}",
                   "percent"   : "{:>15.2f}",
                   "cord"      : "{},{:<33}",
                  }


    self.print_format = {"tg_timing_header": type_format["name"] + type_format["type"] + type_format["type"]    + type_format["type"]    + "\n",
                         "tg_timing_data"  : type_format["name"] + type_format["int"]  + type_format["int"]     + type_format["percent"] + "\n",
                         "timing_header"   : type_format["name"] + type_format["type"] + type_format["type"]    + type_format["type"]    + "\n",
                         "timing_data"     : type_format["cord"] + type_format["int"]  + type_format["int"]     + type_format["percent"] + "\n",
                         "instr_header"    : type_format["name"] + type_format["int"]  + type_format["type"]    + "\n",
                         "instr_data"      : type_format["name"] + type_format["int"]  + type_format["percent"] + "\n",
                         "stall_header"    : type_format["name"] + type_format["type"] + type_format["type"]    + "\n",
                         "stall_data"      : type_format["name"] + type_format["int"]  + type_format["percent"] + "\n",
                         "miss_header"     : type_format["name"] + type_format["type"] + type_format["type"]    + type_format["type"]  + "\n",
                         "miss_data"       : type_format["name"] + type_format["int"]  + type_format["int"]     + type_format["float"] + "\n",
                         "line_break"      : '=' * 90 + "\n"
                        }



    # list of instructions, operations and events parsed from vanilla_stats.log
    # populated by reading the header of input file 
    self.stats_list   = []
    self.instr_list   = []
    self.miss_list    = []
    self.stalls_list  = []
    self.all_ops_list = []

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
    stat_type   = (stat_val >> (bsg_STAT_TAG_BITS + bsg_STAT_TG_ID_BITS + bsg_STAT_X_BITS + bsg_STAT_Y_BITS))
    stat_y      = (stat_val >> (bsg_STAT_TAG_BITS + bsg_STAT_TG_ID_BITS + bsg_STAT_X_BITS)) & bsg_STAT_Y_MASK
    stat_x      = (stat_val >> (bsg_STAT_TAG_BITS + bsg_STAT_TG_ID_BITS)) & bsg_STAT_X_MASK
    stat_tg_id  = (stat_val >> (bsg_STAT_TAG_BITS)) & bsg_STAT_TG_ID_MASK
    stat_tag    = (stat_val) & bsg_STAT_TAG_MASK
    return (stat_type, stat_y, stat_x, stat_tg_id, stat_tag)
    


  # go though the input traces and extract start and end stats  
  # for each tile, and each tile group 
  # return number of tile groups, tile group timing stats, and the tile stats
  # this function only counts the portion between two print_stat_start and end messages
  # in theory, this excludes the time tiles are waiting to be loaded, etc.
  def __generate_tile_stats(self, traces):

    tile_group_timing_start = Counter()
    tile_group_timing_end = Counter()
    tile_group_timing_stat = Counter()
    tile_group_cycle_start = Counter()
    tile_group_cycle_end = Counter()
    tile_group_cycle_stat = Counter()
    num_tile_groups = 0

    tile_stat_start = [[Counter() for x in range(self.manycore_dim_x)] for y in range(self.manycore_dim_y)]
    tile_stat_end   = [[Counter() for x in range(self.manycore_dim_x)] for y in range(self.manycore_dim_y)]
    tile_stat       = [[Counter() for x in range(self.manycore_dim_x)] for y in range(self.manycore_dim_y)]

    for trace in traces:
      y = trace["y"]
      x = trace["x"]
      relative_y = y - bsg_ORG_Y
      relative_x = x - bsg_ORG_X
      stat_val = trace["tag"]
      stat_type, stat_y, stat_x, stat_tg_id, stat_tag = self.__decode_stat_val(stat_val)
      # Separate depending on stat type (start or end)
      if(stat_type == bsg_STAT_TYPE_START):
        # Only increase number of tile groups if haven't seen a trace from this tile group before
        if(not stat_tg_id in tile_group_timing_start.keys()):
          num_tile_groups += 1
        tile_group_timing_start[stat_tg_id] += trace["time"]
        tile_group_cycle_start[stat_tg_id] += trace["global_ctr"]
        for op in self.all_ops_list:
          tile_stat_start[relative_y][relative_x][op] = trace[op]

      elif (stat_type == bsg_STAT_TYPE_END):
        tile_group_timing_end[stat_tg_id] += trace["time"]
        tile_group_cycle_end[stat_tg_id] += trace["global_ctr"]
        for op in self.all_ops_list:
          tile_stat_end[relative_y][relative_x][op] = trace[op]


    # Generate execution time by subtracting start time from end time
    tile_group_timing_stat = tile_group_timing_end - tile_group_timing_start
    tile_group_cycle_stat = tile_group_cycle_end - tile_group_cycle_start

    # Generate all other types of stats by subtracting start time from end time
    for y in range(self.manycore_dim_y):
      for x in range(self.manycore_dim_x):
        tile_stat[y][x] = tile_stat_end[y][x] - tile_stat_start[y][x]


    # Generate total stats for each tile by summing all stats 
    for y in range(self.manycore_dim_y):
      for x in range(self.manycore_dim_x):
        for instr in self.instr_list:
          tile_stat[y][x]["instr_total"] += tile_stat[y][x][instr]
        for stall in self.stalls_list:
          tile_stat[y][x]["stall_total"] += tile_stat[y][x][stall]
        for miss in self.miss_list:
          tile_stat[y][x]["miss_total"] += tile_stat[y][x][miss]

    self.instr_list += ["instr_total"]
    self.stalls_list += ["stall_total"]
    self.miss_list += ["miss_total"]
    self.all_ops_list += ["instr_total", "stall_total", "miss_total"]

    return num_tile_groups, tile_group_timing_stat, tile_group_cycle_stat, tile_stat


  # Generate a stats dictionary for each tile containing the stat and it's aggregate count
  # other than timing, tile stats are only read once per tile from the end of file
  # i.e. if mesh dimensions are 4x4, only last 16 lines are needed 
  # Deprecated  -- might be used later if needed
  # This method count the aggregate stats (including the time tiles are waiting
  # for a program to be loaded)
  def __generate_inclusive_tile_stat (self, traces):
    tile_stat = [[Counter() for x in range(self.manycore_dim_x)] for y in range(self.manycore_dim_y)]
    trace_idx = len(traces)
    for y in range(self.manycore_dim_y):
      for x in range(self.manycore_dim_x):
        trace_idx -= 1
        trace = traces[trace_idx]
        for op in self.all_ops_list:
          tile_stat[y][x][op] = trace[op]
    return tile_stat


  # print execution timing for the entire manycore per tile group 
  def __print_manycore_stats_tile_group_timing(self, stat_file):
    # For total execution time, we only sum up the execution time of origin tile in tile groups
    # The origin tile's relative coordinates is always 0,0 
    stat_file.write("Tile Group Timing Stats\n")
    self.__print_stat(stat_file, "tg_timing_header", "tile group", "exec time(ps)", "cycle", "share (%)")
    self.__print_stat(stat_file, "line_break")

    for i in range (0, self.num_tile_groups):
      self.__print_stat(stat_file, "tg_timing_data", i,
                                   self.tile_group_timing_stat[i], self.tile_group_cycle_stat[i],
                                   (self.tile_group_timing_stat[i] / self.manycore_stat["time"] * 100))

    self.__print_stat(stat_file, "tg_timing_data", "total",
                                 self.manycore_stat["time"], self.manycore_stat["global_ctr"],
                                 (self.manycore_stat["time"] / self.manycore_stat["time"] * 100))
    self.__print_stat(stat_file, "line_break")
    return


  # print execution timing for the entire manycore per tile
  def __print_manycore_stats_tile_timing(self, stat_file):
    # For total execution time, we only sum up the execution time of origin tile in tile groups
    # The origin tile's relative coordinates is always 0,0 
    stat_file.write("Tile Timing Stats\n")
    self.__print_stat(stat_file, "timing_header", "tile", "exec time(ps)", "cycle", "share (%)")
    self.__print_stat(stat_file, "line_break")

    for y in range(self.manycore_dim_y):
      for x in range(self.manycore_dim_x):
        self.__print_stat(stat_file, "timing_data", y, x,
                                     self.tile_stat[y][x]["time"], self.tile_stat[y][x]["global_ctr"],
                                     (self.tile_stat[y][x]["time"] / self.manycore_stat["time"] * 100))

    self.__print_stat(stat_file, "tg_timing_data", "total",
                                 self.manycore_stat["time"], self.manycore_stat["global_ctr"],
                                 (self.manycore_stat["time"] / self.manycore_stat["time"] * 100))
    self.__print_stat(stat_file, "line_break")
    return



  # print timing stats for each tile in a separate file 
  # y,x are tile coordinates 
  def __print_per_tile_stats_timing(self, y, x, stat_file):
    stat_file.write("Timing Stats\n")
    self.__print_stat(stat_file, "timing_header", "tile", "exec time(ps)", "cycle", "share (%)")
    self.__print_stat(stat_file, "line_break")

    total_tile_execution_time = 0

    self.__print_stat(stat_file, "timing_data", y , x,
                                 self.tile_stat[y][x]["time"], self.tile_stat[y][x]["cycle"],
                                 (self.tile_stat[y][x]["time"] / self.manycore_stat["time"] * 100))
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
                                    (100 * self.manycore_stat[instr] / self.manycore_stat["instr_total"]))
    self.__print_stat(stat_file, "line_break")
    return


  # print instruction stats for each tile in a separate file 
  # y,x are tile coordinates 
  def __print_per_tile_stats_instructions(self, y, x, stat_file):

    stat_file.write("Instruction Stats\n")
    self.__print_stat(stat_file, "instr_header", "instruction", "count", " share (%)")
    self.__print_stat(stat_file, "line_break")

    # Print instruction stats for manycore
    for instr in self.instr_list:
       self.__print_stat(stat_file, "instr_data", instr,
                                    self.tile_stat[y][x][instr],
                                    (100 * self.tile_stat[y][x][instr] / self.tile_stat[y][x]["instr_total"]))
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
                                    (100 * self.manycore_stat[stall] / self.manycore_stat["stall_total"]))
    self.__print_stat(stat_file, "line_break")
    return


  # print stall stats for each tile in a separate file
  # y,x are tile coordinates 
  def __print_per_tile_stats_stalls(self, y, x, stat_file):
    stat_file.write("Stall Stats\n")
    self.__print_stat(stat_file, "stall_header", "stall", "cycles", "share (%)")
    self.__print_stat(stat_file, "line_break")

    # Print stall stats for manycore
    for stall in self.stalls_list:
       self.__print_stat(stat_file, "stall_data", stall,
                                    self.tile_stat[y][x][stall],
                                    (100 * self.tile_stat[y][x][stall] / self.tile_stat[y][x]["stall_total"]))
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
         
       self.__print_stat(stat_file, "miss_data", miss, miss_cnt, operation_cnt, hit_rate )
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
         
       self.__print_stat(stat_file, "miss_data", miss, miss_cnt, operation_cnt, hit_rate )
    self.__print_stat(stat_file, "line_break")
    return


  # Calculate aggregate manycore stats dictionary by summing 
  # all per tile stats dictionaries
  def __generate_manycore_stats_all(self, tile_stat):

    # Create a dictionary and initialize elements to zero
    manycore_stat = Counter()
    for y in range(self.manycore_dim_y):
      for x in range(self.manycore_dim_x):
        for op in self.all_ops_list:
          manycore_stat[op] += tile_stat[y][x][op]

    return manycore_stat
 


  # prints all four types of stats, timing, instruction,
  # miss and stall for the entire manycore 
  def print_manycore_stats_all(self):
    manycore_stats_file = open("manycore_stats.log", "w")
    self.__print_manycore_stats_tile_group_timing(manycore_stats_file)
    self.__print_manycore_stats_tile_timing(manycore_stats_file)
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
        self.__print_per_tile_stats_timing(y, x, stat_file)
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
          if (not item == 'instr_total'):
            self.instr_list += [item]
        elif (item.startswith('miss_')):
          self.miss_list += [item]
        elif (item.startswith('stall_')):
          self.stalls_list += [item]
        else:
          self.stats_list += [item]
      self.all_ops_list = self.stats_list + self.instr_list + self.miss_list + self.stalls_list

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
    self.num_tile_groups, self.tile_group_timing_stat, self.tile_group_cycle_stat, self.tile_stat = self.__generate_tile_stats(self.traces)

    # Calculate total aggregate stats for manycore
    # By summing up per_tile stat counts
    self.manycore_stat = self.__generate_manycore_stats_all(self.tile_stat)

    # return tile_group_timing_stat (list of tile group execution times)
    # and per_tile stats dictionary
    return (self.tile_group_timing_stat, self.manycore_stat, self.tile_stat)



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

  


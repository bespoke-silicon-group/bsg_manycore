#
#   vanilla_stats_parser.py
#
#   vanilla core stats extractor
# 
#   input: vanilla_stats.csv
#   output: stats/manycore_stats.log
#   output: stats/tile/tile_<x>_<y>_stats.log for all tiles 
#   output: stats/tile_group/tile_group_<tg_id>_stats.log for all tile groups
#
#   @author Borna Dustin
#
#   How to use:
#   python3 vanilla_stats_parser.py 
#                       --tile (optional) --tile_group (optional)
#                        --input {vanilla_stats.csv}
#
#   ex) python3 --input vanilla_stats_parser.py --tile --tile_group --input vanilla_stats.csv
#
#   {tile}            Generate separate stats file for each tile default = False
#   {tile_group}      Generate separate stats file for each tile group default = False
#   {input}           Vanilla stats input file     default = vanilla_stats.csv

import sys
import argparse
import os
import re
import csv
import numpy as np
from enum import Enum
from collections import Counter

# CudaStatTag class 
# Is instantiated by a packet tag value that is recieved from a 
# bsg_cuda_print_stat(tag) insruction
# Breaks down the tag into (type, y, x, tg_id, tag>
# type of tag could be start, end, stat
# x,y are coordinates of the tile that triggered the print_stat instruciton
# tg_id is the tile group id of the tile that triggered the print_stat instruction
# Formatting for bsg_cuda_print_stat instructions
# Section                 stat type  -   y cord   -   x cord   -    tile group id   -        tag
# of bits                <----2----> -   <--6-->  -   <--6-->  -   <------14----->  -   <-----4----->
# Stat type value: {"Kernel Start":0, "Kernel End": 1, "Tag Start":2, "Tag End":3}

# The CudaStatTag class encapsulates the tag argument used by bsg_cuda_print_stat_*
# commands inside of bsg_manycore/software/bsg_manycore_lib/bsg_manycore.h.
# There are four commands:

#  bsg_cuda_print_stat_kernel_start() - Annotates the start of the kernel being profiled
#  bsg_cuda_print_stat_kernel_end()   - Annotates the end of the kernel being profiled
#  bsg_cuda_print_stat_start(tag)     - Annotates the start of a tagged section of the kernel being profiled
#  bsg_cuda_print_stat_end(tag)       - Annotates the end of a tagged section of the kernel being profiled

# Calls to bsg_cuda_print_stat_start(tag) and bsg_cuda_print_stat_kernel_start()
# must be called first be paired with a matching call to
# bsg_cuda_print_stat_end(tag) and bsg_cuda_print_stat_kernel_end().
class CudaStatTag:
    # These values are used by the manycore library in bsg_print_stat instructions
    # they are added to the tag value to determine the tile group that triggered the stat
    # and also the type of stat (stand-alone stat, start, or end)
    # the value of these paramters should match their counterpart inside 
    # bsg_manycore/software/bsg_manycore_lib/bsg_manycore.h
    _TAG_WIDTH   = 4
    _TAG_INDEX   = 0
    _TAG_MASK   = ((1 << _TAG_WIDTH) - 1)
    _TG_ID_WIDTH = 14
    _TG_ID_INDEX = _TAG_WIDTH + _TAG_INDEX
    _TG_ID_MASK = ((1 << _TG_ID_WIDTH) - 1)
    _X_WIDTH     = 6
    _X_MASK     = ((1 << _X_WIDTH) - 1)
    _X_INDEX     = _TG_ID_WIDTH + _TG_ID_INDEX
    _Y_WIDTH     = 6
    _Y_INDEX     = _X_WIDTH + _X_INDEX
    _Y_MASK     = ((1 << _Y_WIDTH) - 1)
    _TYPE_WIDTH  = 2
    _TYPE_INDEX  = _Y_WIDTH + _Y_INDEX
    _TYPE_MASK   = ((1 << _TYPE_WIDTH) - 1)

    class StatType(Enum):
        START = 0
        END = 1
        KERNEL_START   = 2
        KERNEL_END     = 3

    def __init__(self, tag):
        """ Initialize a CudaStatTag object """
        self.__s = tag;
        self.__type = self.StatType((self.__s >> self._TYPE_INDEX) & self._TYPE_MASK)

    @property
    def tag(self):
        """ Get the tag associated with this object """
        return ((self.__s >> self._TAG_INDEX) & self._TAG_MASK)

    @property 
    def tg_id(self):
        """ Get the Tile-Group IP associated with this object """
        return ((self.__s >> self._TG_ID_INDEX) & self._TG_ID_MASK)

    @property 
    def x(self):
        """ Get the X Coordinate associated with this object """
        return ((self.__s >> self._X_INDEX) & self._X_MASK)

    @property 
    def y(self):
        """ Get the Y Coordinate associated with this object """
        return ((self.__s >> self._Y_INDEX) & self._Y_MASK)

    @property 
    def statType(self):
        """ Get the StatType that this object defines"""
        return self.__type

    @property 
    def isStart(self):
        """ Return true if this object corresponds to a call to
        bsg_cuda_print_stat_start """
        return (self.__type == self.StatType.START)

    @property 
    def isEnd(self):
        """ Return true if this object corresponds to a call to
        bsg_cuda_print_stat_end """
        return (self.__type == self.StatType.END)

    @property 
    def isKernelStart(self):
        """ Return true if this object corresponds to a call to
        bsg_cuda_print_stat_kernel_start """
        return (self.__type == self.StatType.KERNEL_START)

    @property 
    def isKernelEnd(self):
        """ Return true if this object corresponds to a call to
        bsg_cuda_print_stat_kernel_end """
        return (self.__type == self.StatType.KERNEL_END)

 
class VanillaStatsParser:
    # formatting parameters for aligned printing
    type_fmt = {"name"      : "{:<35}",
                "name-short": "{:<20}",
                "name_indt" : "  {:<33}",
                "type"      : "{:>20}",
                "int"       : "{:>20}",
                "float"     : "{:>20.4f}",
                "percent"   : "{:>20.2f}",
                "cord"      : "{:<2}, {:<31}",
                "tag"       : "Tag {:<8}",
               }


    print_format = {"tg_timing_header": type_fmt["name"]       + type_fmt["type"] + type_fmt["type"]    + type_fmt["type"]    + type_fmt["type"]    + type_fmt["type"]    + type_fmt["type"]    + "\n",
                    "tg_timing_data"  : type_fmt["name"]       + type_fmt["int"]  + type_fmt["int"]     + type_fmt["int"]     + type_fmt["float"]   + type_fmt["percent"] + type_fmt["percent"] + "\n",
                    "timing_header"   : type_fmt["name"]       + type_fmt["type"] + type_fmt["type"]    + type_fmt["type"]    + type_fmt["type"]    + type_fmt["type"]    + "\n",
                    "timing_data"     : type_fmt["cord"]       + type_fmt["int"]  + type_fmt["int"]     + type_fmt["float"]   + type_fmt["percent"] + type_fmt["percent"] + "\n",
                    "instr_header"    : type_fmt["name"]       + type_fmt["int"]  + type_fmt["type"]    + "\n",
                    "instr_data"      : type_fmt["name"]       + type_fmt["int"]  + type_fmt["percent"] + "\n",
                    "stall_header"    : type_fmt["name"]       + type_fmt["type"] + type_fmt["type"]    + type_fmt["type"]    + "\n",
                    "stall_data"      : type_fmt["name"]       + type_fmt["int"]  + type_fmt["percent"] + type_fmt["percent"] + "\n",
                    "stall_data_indt" : type_fmt["name_indt"]  + type_fmt["int"]  + type_fmt["percent"] + type_fmt["percent"] + "\n",
                    "bubble_header"   : type_fmt["name"]       + type_fmt["type"] + type_fmt["type"]    + type_fmt["type"]    + "\n",
                    "bubble_data"     : type_fmt["name"]       + type_fmt["int"]  + type_fmt["percent"] + type_fmt["percent"] + "\n",
                    "miss_header"     : type_fmt["name"]       + type_fmt["type"] + type_fmt["type"]    + type_fmt["type"]    + "\n",
                    "miss_data"       : type_fmt["name"]       + type_fmt["int"]  + type_fmt["int"]     + type_fmt["percent"]   + "\n",
                    "tag_header"      : type_fmt["name-short"] + type_fmt["type"] + type_fmt["type"]    + type_fmt["type"]    + type_fmt["type"]    + type_fmt["type"]    + type_fmt["type"] + type_fmt["type"]  + type_fmt["type"] + "\n",
                    "tag_data"        : type_fmt["name-short"] + type_fmt["int"]  + type_fmt["int"]     + type_fmt["int"]     + type_fmt["int"]     + type_fmt["int"]     + type_fmt["int"]  + type_fmt["float"] + type_fmt["percent"] + "\n",
                    "tag_separator"   : '-' * 83 + ' ' * 2     + type_fmt["tag"]  + ' ' * 2 + '-' * 83 + "\n",
                    "start_lbreak"    : '=' *182 + "\n",
                    "end_lbreak"      : '=' *182 + "\n\n",
                   }



    # default constructor
    def __init__(self, per_tile_stat, per_tile_group_stat, input_file):

        #self.manycore_dim_y = manycore_dim_y
        #self.manycore_dim_x = manycore_dim_x
        #self.manycore_dim = manycore_dim_y * manycore_dim_x
        self.per_tile_stat = per_tile_stat
        self.per_tile_group_stat = per_tile_group_stat

        self.traces = []

        self.max_tile_groups = 1 << CudaStatTag._TG_ID_WIDTH
        self.num_tile_groups = []

        self.max_tags = 1 << CudaStatTag._TAG_WIDTH

        tags = list(range(self.max_tags)) + ["kernel"]
        self.tile_stat = {tag:Counter() for tag in tags}
        self.tile_group_stat = {tag:Counter() for tag in tags}
        self.manycore_stat = {tag:Counter() for tag in tags}
        self.manycore_cycle_parallel_cnt = {tag: 0 for tag in tags}

        # list of instructions, operations and events parsed from vanilla_stats.csv
        # populated by reading the header of input file 
        self.stats_list = []
        self.instrs = []
        self.misses = []
        self.stalls = []
        self.bubbles = []
        self.all_ops = []

        # Parse input file's header to generate a list of all types of operations
        self.stats, self.instrs, self.misses, self.stalls, self.bubbles = self.parse_header(input_file)

        # bubble_fp_op is a bubble in the Integer pipeline "caused" by
        # an FP instruction executing. Don't count it in the bubbles
        # because the procesor is still doing "useful work". 
        self.notbubbles = ['bubble_fp_op'] 

        # Remove all notbubbles from the bubbles list
        for nb in self.notbubbles:
            self.bubbles.remove(nb)

        self.all_ops = self.stats + self.instrs + self.misses + self.stalls + self.bubbles

        # Use sets to determine the active tiles (without duplicates)
        active_tiles = set()

        # Parse stats file line by line, and append the trace line to traces list. 
        with open(input_file) as f:
            csv_reader = csv.DictReader (f, delimiter=",")
            for row in csv_reader:
                trace = {op:int(row[op]) for op in self.all_ops}
                active_tiles.add((trace['y'], trace['x']))
                self.traces.append(trace)

        # Raise exception and exit if there are no traces 
        if not self.traces:
            raise IOError("No Stats Found: Use bsg_cuda_print_stat_kernel_start/end to generate runtime statistics")

        # Save the active tiles in a list
        self.active = list(active_tiles)
        self.active.sort()

        # generate timing stats for each tile and tile group 
        self.num_tile_groups, self.tile_group_stat, self.tile_stat, self.manycore_cycle_parallel_cnt = self.__generate_tile_stats(self.traces, self.active)

        # Calculate total aggregate stats for manycore
        # By summing up per_tile stat counts
        self.manycore_stat = self.__generate_manycore_stats_all(self.tile_stat, self.manycore_cycle_parallel_cnt)

        return


    # print a line of stat into stats file based on stat type
    def __print_stat(self, stat_file, stat_type, *argv):
        stat_file.write(self.print_format[stat_type].format(*argv));
        return



    # print instruction count, stall count, execution cycles for the entire manycore for each tag
    def __print_manycore_stats_tag(self, stat_file):
        stat_file.write("Per-Tag Stats\n")
        self.__print_stat(stat_file, "tag_header"
                                     ,"Tag ID"
                                     ,"Aggr Instructions"
                                     ,"Aggr I$ Misses"
                                     ,"Aggr Stall Cycles"
                                     ,"Aggr Bubble Cycles"
                                     ,"Aggr Total Cycles"
                                     ,"Abs Total Cycles"
                                     ,"IPC"
                                     ,"    % of Kernel Cycles")
        self.__print_stat(stat_file, "start_lbreak")

        for tag in self.manycore_stat.keys():
            if(self.manycore_stat[tag]["global_ctr"]):
                self.__print_stat(stat_file, "tag_data"
                                             ,tag
                                             ,self.manycore_stat[tag]["instr_total"]
                                             ,self.manycore_stat[tag]["miss_icache"]
                                             ,self.manycore_stat[tag]["stall_total"]
                                             ,self.manycore_stat[tag]["bubble_total"]
                                             ,self.manycore_stat[tag]["global_ctr"]
                                             ,self.manycore_stat[tag]["cycle_parallel_cnt"]
                                             ,(np.float64(self.manycore_stat[tag]["instr_total"]) / self.manycore_stat[tag]["global_ctr"])
                                             ,np.float64(100 * self.manycore_stat[tag]["global_ctr"]) / self.manycore_stat["kernel"]["global_ctr"])
        self.__print_stat(stat_file, "end_lbreak")
        return




    # print instruction count, stall count, execution cycles 
    # for each tile group in a separate file for each tag
    def __print_per_tile_group_stats_tag(self, tg_id, stat_file):
        stat_file.write("Per-Tile-Group Tag Stats\n")
        self.__print_stat(stat_file, "tag_header"
                                     ,"Tag ID"
                                     ,"Aggr Instructions"
                                     ,"Aggr I$ Misses"
                                     ,"Aggr Stall Cycles"
                                     ,"Aggr Bubble Cycles"
                                     ,"Aggr Total Cycles"
                                     ,"Abs Total Cycles"
                                     ,"IPC"
                                     ,"    % of Kernel Cycles")
        self.__print_stat(stat_file, "start_lbreak")

        for tag in self.tile_group_stat.keys():
            if(self.tile_group_stat[tag][tg_id]["global_ctr"]):
                self.__print_stat(stat_file, "tag_data"
                                             ,tag
                                             ,self.tile_group_stat[tag][tg_id]["instr_total"]
                                             ,self.tile_group_stat[tag][tg_id]["miss_icache"]
                                             ,self.tile_group_stat[tag][tg_id]["stall_total"]
                                             ,self.tile_group_stat[tag][tg_id]["bubble_total"]
                                             ,self.tile_group_stat[tag][tg_id]["global_ctr"]
                                             ,self.tile_group_stat[tag][tg_id]["cycle_parallel_cnt"]
                                             ,(np.float64(self.tile_group_stat[tag][tg_id]["instr_total"]) / self.tile_group_stat[tag][tg_id]["global_ctr"])
                                             ,(np.float64(100 * self.tile_group_stat[tag][tg_id]["global_ctr"]) / self.tile_group_stat["kernel"][tg_id]["global_ctr"]))
        self.__print_stat(stat_file, "end_lbreak")
        return




    # print instruction count, stall count, execution cycles 
    # for each tile in a separate file for each tag
    def __print_per_tile_stats_tag(self, tile, stat_file):
        stat_file.write("Per-Tile Stats\n")
        self.__print_stat(stat_file, "tag_header"
                                     ,"Tag ID"
                                     ,"Aggr Instructions"
                                     ,"Aggr I$ Misses"
                                     ,"Aggr Stall Cycles"
                                     ,"Aggr Bubble Cycles"
                                     ,"Aggr Total Cycles"
                                     ,"Abs Total Cycles"
                                     ,"IPC"
                                     ,"    % of Kernel Cycles")
        self.__print_stat(stat_file, "start_lbreak")

        for tag in self.tile_stat.keys():
            if(self.tile_stat[tag][tile]["global_ctr"]):
                self.__print_stat(stat_file, "tag_data"
                                             ,tag
                                             ,self.tile_stat[tag][tile]["instr_total"]
                                             ,self.tile_stat[tag][tile]["miss_icache"]
                                             ,self.tile_stat[tag][tile]["stall_total"]
                                             ,self.tile_stat[tag][tile]["bubble_total"]
                                             ,self.tile_stat[tag][tile]["global_ctr"]
                                             ,self.tile_stat[tag][tile]["global_ctr"]
                                             ,(np.float64(self.tile_stat[tag][tile]["instr_total"]) / self.tile_stat[tag][tile]["global_ctr"])
                                             ,(np.float64(100 * self.tile_stat[tag][tile]["global_ctr"]) / self.tile_stat["kernel"][tile]["global_ctr"]))
        self.__print_stat(stat_file, "end_lbreak")
        return




    # print execution timing for the entire manycore per tile group for a certain tag
    def __print_manycore_tag_stats_tile_group_timing(self, stat_file, tag):
        self.__print_stat(stat_file, "tag_separator", tag)

        for tg_id in range (0, self.num_tile_groups[tag]):
            self.__print_stat(stat_file, "tg_timing_data"
                                         ,tg_id
                                         ,(self.tile_group_stat[tag][tg_id]["instr_total"])
                                         ,(self.tile_group_stat[tag][tg_id]["global_ctr"])
                                         ,(self.tile_group_stat[tag][tg_id]["cycle_parallel_cnt"])
                                         ,(np.float64(self.tile_group_stat[tag][tg_id]["instr_total"]) / self.tile_group_stat[tag][tg_id]["global_ctr"])
                                         ,(np.float64(100.0 * self.tile_group_stat[tag][tg_id]["global_ctr"]) / self.manycore_stat[tag]["global_ctr"])
                                         ,(np.float64(100.0 * self.tile_group_stat[tag][tg_id]["global_ctr"]) / self.tile_group_stat["kernel"][tg_id]["global_ctr"]))

        self.__print_stat(stat_file, "tg_timing_data"
                                     ,"total"
                                     ,(self.manycore_stat[tag]["instr_total"])
                                     ,(self.manycore_stat[tag]["global_ctr"])
                                     ,(self.manycore_stat[tag]["cycle_parallel_cnt"])
                                     ,(self.manycore_stat[tag]["instr_total"] / self.manycore_stat[tag]["global_ctr"])
                                     ,(100 * self.manycore_stat[tag]["instr_total"] / self.manycore_stat[tag]["instr_total"])
                                     ,(np.float64(100 * self.manycore_stat[tag]["global_ctr"]) / self.manycore_stat["kernel"]["global_ctr"]))
        return


    # Prints manycore timing stats per tile group for all tags 
    def __print_manycore_stats_tile_group_timing(self, stat_file):
        stat_file.write("Per-Tile-Group Timing Stats\n")
        self.__print_stat(stat_file, "tg_timing_header"
                                     ,"Tile Group ID"
                                     ,"Aggr Instructions"
                                     ,"Aggr Total Cycles"
                                     ,"Abs Total Cycle"
                                     ,"IPC"
                                     ,"   TG / Tag-Total (%)"
                                     ,"   TG / Kernel-Total(%)")
        self.__print_stat(stat_file, "start_lbreak")
        for tag in self.manycore_stat.keys():
            if(self.manycore_stat[tag]["global_ctr"]):
                self.__print_manycore_tag_stats_tile_group_timing(stat_file, tag)
        self.__print_stat(stat_file, "end_lbreak")
        return   




    # print execution timing for the entire manycore per tile
    def __print_manycore_tag_stats_tile_timing(self, stat_file, tag, tiles):
        self.__print_stat(stat_file, "tag_separator", tag)

        for tile in tiles:
            self.__print_stat(stat_file, "timing_data"
                              ,tile[0]
                              ,tile[1]
                              ,(self.tile_stat[tag][tile]["instr_total"])
                              ,(self.tile_stat[tag][tile]["global_ctr"])
                              ,(np.float64(self.tile_stat[tag][tile]["instr_total"]) / self.tile_stat[tag][tile]["global_ctr"])
                              ,(100 * self.tile_stat[tag][tile]["global_ctr"] / self.manycore_stat[tag]["global_ctr"])
                              ,(100 * np.float64(self.tile_stat[tag][tile]["global_ctr"]) / self.tile_stat["kernel"][tile]["global_ctr"]))

        self.__print_stat(stat_file, "tg_timing_data"
                                     ,"total"
                                     ,(self.manycore_stat[tag]["instr_total"])
                                     ,(self.manycore_stat[tag]["global_ctr"])
                                     ,0
                                     ,(self.manycore_stat[tag]["instr_total"] / self.manycore_stat[tag]["global_ctr"])
                                     ,(np.float64(100 * self.manycore_stat[tag]["global_ctr"]) / self.manycore_stat[tag]["global_ctr"])
                                     ,(np.float64(100 * self.manycore_stat[tag]["global_ctr"]) / self.manycore_stat["kernel"]["global_ctr"]))
        return


    # Prints manycore timing stats per tile group for all tags 
    def __print_manycore_stats_tile_timing(self, stat_file, tiles):
        stat_file.write("Per-Tile Timing Stats\n")
        self.__print_stat(stat_file, "timing_header", "Relative Tile Coordinate (Y,X)", "Instructions", "Cycles", "IPC", "   Tile / Tag-Total (%)", "   Tile / Kernel-Total(%)")
        self.__print_stat(stat_file, "start_lbreak")
        for tag in self.manycore_stat.keys():
            if(self.manycore_stat[tag]["global_ctr"]):
                self.__print_manycore_tag_stats_tile_timing(stat_file, tag, tiles)
        self.__print_stat(stat_file, "end_lbreak")
        return   




    # print timing stats for each tile group in a separate file 
    # tg_id is tile group id 
    def __print_per_tile_group_tag_stats_timing(self, tg_id, stat_file, tag):
        self.__print_stat(stat_file, "tag_separator", tag)

        self.__print_stat(stat_file, "tg_timing_data"
                                     ,tg_id
                                     ,(self.tile_group_stat[tag][tg_id]["instr_total"])
                                     ,(self.tile_group_stat[tag][tg_id]["global_ctr"])
                                     ,(self.tile_group_stat[tag][tg_id]["cycle_parallel_cnt"])
                                     ,(np.float64(self.tile_group_stat[tag][tg_id]["instr_total"]) / self.tile_group_stat[tag][tg_id]["global_ctr"])
                                     ,(100 * self.tile_group_stat[tag][tg_id]["global_ctr"] / self.manycore_stat[tag]["global_ctr"])
                                     ,(100 * np.float64(self.tile_group_stat[tag][tg_id]["instr_total"]) / self.tile_group_stat["kernel"][tg_id]["instr_total"]))
        return


    # Print timing stat for each tile group in separate file for all tags 
    def __print_per_tile_group_stats_timing(self, tg_id, stat_file):
        stat_file.write("Per-Tile-Group Timing Stats\n")
        self.__print_stat(stat_file, "tg_timing_header"
                                     ,"Tile Group ID"
                                     ,"Aggr Instructions"
                                     ,"Aggr Total Cycles"
                                     ,"Abs Total Cycle"
                                     ,"IPC"
                                     ,"   TG / Tag-Total (%)"
                                     ,"   TG / Kernel-Total(%)")
        self.__print_stat(stat_file, "start_lbreak")
        for tag in self.tile_group_stat.keys():
            if(self.tile_group_stat[tag][tg_id]["global_ctr"]):
                self.__print_per_tile_group_tag_stats_timing(tg_id, stat_file, tag)
        self.__print_stat(stat_file, "end_lbreak")
        return   




    # print timing stats for each tile in a separate file 
    # y,x are tile coordinates 
    def __print_per_tile_tag_stats_timing(self, tile, stat_file, tag):
        self.__print_stat(stat_file, "tag_separator", tag)

        self.__print_stat(stat_file, "timing_data"
                                     ,tile[0]
                                     ,tile[1]
                                     ,(self.tile_stat[tag][tile]["instr_total"])
                                     ,(self.tile_stat[tag][tile]["global_ctr"])
                                     ,(np.float64(self.tile_stat[tag][tile]["instr_total"]) / self.tile_stat[tag][tile]["global_ctr"])
                                     ,(np.float64(100 * self.tile_stat[tag][tile]["global_ctr"]) / self.manycore_stat[tag]["global_ctr"])
                                     ,(np.float64(100 * self.tile_stat[tag][tile]["global_ctr"]) / self.tile_stat["kernel"][tile]["global_ctr"]))

        return


    # print timing stats for each tile in a separate file for all tags 
    def __print_per_tile_stats_timing(self, tile, stat_file):
        stat_file.write("Per-Tile Timing Stats\n")
        self.__print_stat(stat_file, "timing_header", "Relative Tile Coordinate (Y,X)", "instr", "cycle", "IPC", "    Tile / Tag-Total (%)", "    Tile / Kernel-Total (%)")
        self.__print_stat(stat_file, "start_lbreak")
        for tag in self.tile_stat.keys():
            if(self.tile_stat[tag][tile]["global_ctr"]):
                self.__print_per_tile_tag_stats_timing(tile, stat_file, tag)
        self.__print_stat(stat_file, "end_lbreak")
        return   




    # print instruction stats for the entire manycore
    def __print_manycore_tag_stats_instr(self, stat_file, tag):
        self.__print_stat(stat_file, "tag_separator", tag)
   
        # Print instruction stats for manycore
        for instr in self.instrs:
            self.__print_stat(stat_file, "instr_data", instr,
                                         self.manycore_stat[tag][instr]
                                         ,(100 * self.manycore_stat[tag][instr] / self.manycore_stat[tag]["instr_total"]))
        return


    # Prints manycore instruction stats per tile group for all tags 
    def __print_manycore_stats_instr(self, stat_file):
        stat_file.write("Per-Tag Instruction Stats\n")
        self.__print_stat(stat_file, "instr_header", "Instruction", "Count", "% of Instructions")
        self.__print_stat(stat_file, "start_lbreak")
        for tag in self.manycore_stat.keys():
            if(self.manycore_stat[tag]["global_ctr"]):
                self.__print_manycore_tag_stats_instr(stat_file, tag)
        self.__print_stat(stat_file, "end_lbreak")
        return   




    # print instruction stats for each tile group in a separate file 
    # tg_id is tile group id 
    def __print_per_tile_group_tag_stats_instr(self, tg_id, stat_file, tag):
        self.__print_stat(stat_file, "tag_separator", tag)

        # Print instruction stats for manycore
        for instr in self.instrs:
            self.__print_stat(stat_file, "instr_data", instr,
                                         self.tile_group_stat[tag][tg_id][instr]
                                         ,(100 * self.tile_group_stat[tag][tg_id][instr] / self.tile_group_stat[tag][tg_id]["instr_total"]))
        return


    # Print instruction stat for each tile group in separate file for all tags 
    def __print_per_tile_group_stats_instr(self, tg_id, stat_file):
        stat_file.write("Per-Tile-Group Instruction Stats\n")
        self.__print_stat(stat_file, "instr_header", "Instruction", "Count", "% of Instructions")
        self.__print_stat(stat_file, "start_lbreak")
        for tag in self.tile_group_stat.keys():
            if(self.tile_group_stat[tag][tg_id]["global_ctr"]):
                self.__print_per_tile_group_tag_stats_instr(tg_id, stat_file, tag)
        self.__print_stat(stat_file, "end_lbreak")
        return   




    # print instruction stats for each tile in a separate file 
    # y,x are tile coordinates 
    def __print_per_tile_tag_stats_instr(self, tile, stat_file, tag):
        self.__print_stat(stat_file, "tag_separator", tag)

        # Print instruction stats for manycore
        for instr in self.instrs:
            self.__print_stat(stat_file, "instr_data", instr,
                                         self.tile_stat[tag][tile][instr]
                                         ,(100 * np.float64(self.tile_stat[tag][tile][instr]) / self.tile_stat[tag][tile]["instr_total"]))
        return


    # print instr stats for each tile in a separate file for all tags 
    def __print_per_tile_stats_instr(self, tile, stat_file):
        stat_file.write("Instruction Stats\n")
        self.__print_stat(stat_file, "instr_header", "Instruction", "Count", "% of Instructions")
        self.__print_stat(stat_file, "start_lbreak")
        for tag in self.tile_stat.keys():
            if(self.tile_stat[tag][tile]["global_ctr"]):
                self.__print_per_tile_tag_stats_instr(tile, stat_file, tag)
        self.__print_stat(stat_file, "end_lbreak")
        return   




    # print stall stats for the entire manycore
    def __print_manycore_tag_stats_stall(self, stat_file, tag):
        self.__print_stat(stat_file, "tag_separator", tag)

        # Print stall stats for manycore
        for stall in self.stalls:
            stall_format = "stall_data_indt" if stall.startswith('stall_depend_') else "stall_data"
            self.__print_stat(stat_file, stall_format, stall,
                                         self.manycore_stat[tag][stall],
                                         (100 * np.float64(self.manycore_stat[tag][stall]) / self.manycore_stat[tag]["stall_total"])
                                         ,(100 * np.float64(self.manycore_stat[tag][stall]) / self.manycore_stat[tag]["global_ctr"]))

        return


    # Prints manycore stall stats per tile group for all tags 
    def __print_manycore_stats_stall(self, stat_file):
        stat_file.write("Per-Tag Stall Stats\n")
        self.__print_stat(stat_file, "stall_header", "Stall Type", "Cycles", " % Stall Cycles", " % Total Cycles")
        self.__print_stat(stat_file, "start_lbreak")
        for tag in self.manycore_stat.keys():
            if(self.manycore_stat[tag]["global_ctr"]):
                self.__print_manycore_tag_stats_stall(stat_file, tag)
        self.__print_stat(stat_file, "end_lbreak")
        return   




    # print stall stats for each tile group in a separate file
    # tg_id is tile group id  
    def __print_per_tile_group_tag_stats_stall(self, tg_id, stat_file, tag):
        self.__print_stat(stat_file, "tag_separator", tag)

        # Print stall stats for manycore
        for stall in self.stalls:
            stall_format = "stall_data_indt" if stall.startswith('stall_depend_') else "stall_data"
            self.__print_stat(stat_file, stall_format
                                         ,stall
                                         ,self.tile_group_stat[tag][tg_id][stall]
                                         ,(100 * np.float64(self.tile_group_stat[tag][tg_id][stall]) / self.tile_group_stat[tag][tg_id]["stall_total"])
                                         ,(100 * np.float64(self.tile_group_stat[tag][tg_id][stall]) / self.tile_group_stat[tag][tg_id]["global_ctr"]))
        return


    # Print stall stat for each tile group in separate file for all tags 
    def __print_per_tile_group_stats_stall(self, tg_id, stat_file):
        stat_file.write("Per-Tile-Group Stall Stats\n")
        self.__print_stat(stat_file, "stall_header", "Stall Type", "Cycles", "% of Stall Cycles", " % of Total Cycles")
        self.__print_stat(stat_file, "start_lbreak")
        for tag in self.tile_group_stat.keys():
            if(self.tile_group_stat[tag][tg_id]["global_ctr"]):
                self.__print_per_tile_group_tag_stats_stall(tg_id, stat_file, tag)
        self.__print_stat(stat_file, "end_lbreak")
        return   




    # print stall stats for each tile in a separate file
    # y,x are tile coordinates 
    def __print_per_tile_tag_stats_stall(self, tile, stat_file, tag):
        self.__print_stat(stat_file, "tag_separator", tag)

        # Print stall stats for manycore
        for stall in self.stalls:
            stall_format = "stall_data_indt" if stall.startswith('stall_depend_') else "stall_data"
            self.__print_stat(stat_file, stall_format, stall,
                                         self.tile_stat[tag][tile][stall],
                                         (100 * np.float64(self.tile_stat[tag][tile][stall]) / self.tile_stat[tag][tile]["stall_total"])
                                         ,(100 * np.float64(self.tile_stat[tag][tile][stall]) / self.tile_stat[tag][tile]["global_ctr"]))
        return


    # print stall stats for each tile in a separate file for all tags 
    def __print_per_tile_stats_stall(self, tile, stat_file):
        stat_file.write("Per-Tile Stall Stats\n")
        self.__print_stat(stat_file, "stall_header", "Stall Type", "Cycles", "% of Stall Cycles", "% of Total Cycles")
        self.__print_stat(stat_file, "start_lbreak")
        for tag in self.tile_stat.keys():
            if(self.tile_stat[tag][tile]["global_ctr"]):
                self.__print_per_tile_tag_stats_stall(tile, stat_file, tag)
        self.__print_stat(stat_file, "start_lbreak")
        return   




    # print bubble stats for the entire manycore
    def __print_manycore_tag_stats_bubble(self, stat_file, tag):
        self.__print_stat(stat_file, "tag_separator", tag)

        # Print bubble stats for manycore
        for bubble in self.bubbles:
            self.__print_stat(stat_file, "bubble_data", bubble,
                                         self.manycore_stat[tag][bubble],
                                         (100 * np.float64(self.manycore_stat[tag][bubble]) / self.manycore_stat[tag]["bubble_total"])
                                         ,(100 * self.manycore_stat[tag][bubble] / self.manycore_stat[tag]["global_ctr"]))
        return


    # Prints manycore bubble stats per tile group for all tags 
    def __print_manycore_stats_bubble(self, stat_file):
        stat_file.write("Per-Tag Bubble Stats\n")
        self.__print_stat(stat_file, "bubble_header", "Bubble Type", "Cycles", "% of Bubbles", "% of Total Cycles")
        self.__print_stat(stat_file, "start_lbreak")
        for tag in self.manycore_stat.keys():
            if(self.manycore_stat[tag]["global_ctr"]):
                self.__print_manycore_tag_stats_bubble(stat_file, tag)
        self.__print_stat(stat_file, "end_lbreak")
        return   




    # print bubble stats for each tile group in a separate file
    # tg_id is tile group id  
    def __print_per_tile_group_tag_stats_bubble(self, tg_id, stat_file, tag):
        self.__print_stat(stat_file, "tag_separator", tag)

        # Print bubble stats for manycore
        for bubble in self.bubbles:
            self.__print_stat(stat_file, "bubble_data"
                                         ,bubble
                                         ,self.tile_group_stat[tag][tg_id][bubble]
                                         ,(100 * np.float64(self.tile_group_stat[tag][tg_id][bubble]) / self.tile_group_stat[tag][tg_id]["bubble_total"])
                                         ,(100 * self.tile_group_stat[tag][tg_id][bubble] / self.tile_group_stat[tag][tg_id]["global_ctr"]))
        return


    # Print bubble stat for each tile group in separate file for all tags 
    def __print_per_tile_group_stats_bubble(self, tg_id, stat_file):
        stat_file.write("Per-Tile-Group Bubble Stats\n")
        self.__print_stat(stat_file, "bubble_header", "Bubble Type", "Cycles", "% of Bubbles", "% of Total Cycles")
        self.__print_stat(stat_file, "start_lbreak")
        for tag in self.tile_group_stat.keys():
            if(self.tile_group_stat[tag][tg_id]["global_ctr"]):
                self.__print_per_tile_group_tag_stats_bubble(tg_id, stat_file, tag)
        self.__print_stat(stat_file, "end_lbreak")
        return   




    # print bubble stats for each tile in a separate file
    # y,x are tile coordinates 
    def __print_per_tile_tag_stats_bubble(self, tile, stat_file, tag):
        self.__print_stat(stat_file, "tag_separator", tag)

        # Print bubble stats for manycore
        for bubble in self.bubbles:
            self.__print_stat(stat_file, "bubble_data", bubble,
                                         self.tile_stat[tag][tile][bubble],
                                         (100 * np.float64(self.tile_stat[tag][tile][bubble]) / self.tile_stat[tag][tile]["bubble_total"])
                                         ,(100 * np.float64(self.tile_stat[tag][tile][bubble]) / self.tile_stat[tag][tile]["global_ctr"]))
        return


    # print bubble stats for each tile in a separate file for all tags 
    def __print_per_tile_stats_bubble(self, tile, stat_file):
        stat_file.write("Per-Tile Bubble Stats\n")
        self.__print_stat(stat_file, "bubble_header", "Bubble Type", "Cycles", "% of Bubbles", "% of Total Cycles")
        self.__print_stat(stat_file, "start_lbreak")
        for tag in self.tile_stat.keys():
            if(self.tile_stat[tag][tile]["global_ctr"]):
                self.__print_per_tile_tag_stats_bubble(tile, stat_file, tag)
        self.__print_stat(stat_file, "start_lbreak")
        return   





    # print miss stats for the entire manycore
    def __print_manycore_tag_stats_miss(self, stat_file, tag):
        self.__print_stat(stat_file, "tag_separator", tag)

        for miss in self.misses:
            # Find total number of operations for that miss If
            # operation is icache, the total is total # of instruction
            # otherwise, search for the specific instruction
            if (miss == "miss_icache"):
                operation = "icache"
                operation_cnt = self.manycore_stat[tag]["instr_total"]
            else:
                operation = miss.replace("miss_", "instr_")
                operation_cnt = self.manycore_stat[tag][operation]
            miss_cnt = self.manycore_stat[tag][miss]
            hit_rate = 100.0 if operation_cnt == 0 else 100.0*(1 - miss_cnt/operation_cnt)
         
            self.__print_stat(stat_file, "miss_data", miss, miss_cnt, operation_cnt, hit_rate )
        return


    # Prints manycore miss stats per tile group for all tags 
    def __print_manycore_stats_miss(self, stat_file):
        stat_file.write("Per-Tag Miss Stats\n")
        self.__print_stat(stat_file, "miss_header", "Miss Type", "Misses", "Accesses", "Hit Rate (%)")
        self.__print_stat(stat_file, "start_lbreak")
        for tag in self.manycore_stat.keys():
            if(self.manycore_stat[tag]["global_ctr"]):
                self.__print_manycore_tag_stats_miss(stat_file, tag)
        self.__print_stat(stat_file, "end_lbreak")
        return   




    # print miss stats for each tile group in a separate file
    # tg_id is tile group id  
    def __print_per_tile_group_tag_stats_miss(self, tg_id, stat_file, tag):
        self.__print_stat(stat_file, "tag_separator", tag)

        for miss in self.misses:
            # Find total number of operations for that miss
            # If operation is icache, the total is total # of instruction
            # otherwise, search for the specific instruction
            if (miss == "miss_icache"):
                operation = "icache"
                operation_cnt = self.tile_group_stat[tag][tg_id]["instr_total"]
            else:
                operation = miss.replace("miss_", "instr_")
                operation_cnt = self.tile_group_stat[tag][tg_id][operation]
            miss_cnt = self.tile_group_stat[tag][tg_id][miss]
            hit_rate = 100.0 if operation_cnt == 0 else 100.0*(1 - miss_cnt/operation_cnt)

            self.__print_stat(stat_file, "miss_data", miss, miss_cnt, operation_cnt, hit_rate )

        return

    # Print miss stat for each tile group in separate file for all tags 
    def __print_per_tile_group_stats_miss(self, tg_id, stat_file):
        stat_file.write("Per-Tile-Group Miss Stats\n")
        self.__print_stat(stat_file, "miss_header", "Miss Type", "Misses", "Accesses", "Hit Rate (%)")
        self.__print_stat(stat_file, "start_lbreak")
        for tag in self.tile_group_stat.keys():
            if(self.tile_group_stat[tag][tg_id]["global_ctr"]):
                self.__print_per_tile_group_tag_stats_miss(tg_id, stat_file, tag)
        self.__print_stat(stat_file, "end_lbreak")
        return   




    # print miss stats for each tile in a separate file
    # y,x are tile coordinates 
    def __print_per_tile_tag_stats_miss(self, tile, stat_file, tag):
        self.__print_stat(stat_file, "tag_separator", tag)

        for miss in self.misses:
            # Find total number of operations for that miss
            # If operation is icache, the total is total # of instruction
            # otherwise, search for the specific instruction
            if (miss == "miss_icache"):
                operation = "icache"
                operation_cnt = self.tile_stat[tag][tile]["instr_total"]
            else:
                operation = miss.replace("miss_", "instr_")
                operation_cnt = self.tile_stat[tag][tile][operation]
            miss_cnt = self.tile_stat[tag][tile][miss]
            hit_rate = 1 if operation_cnt == 0 else (1 - miss_cnt/operation_cnt)
         
            self.__print_stat(stat_file, "miss_data", miss, miss_cnt, operation_cnt, hit_rate )

        return


    # print stall miss for each tile in a separate file for all tags 
    def __print_per_tile_stats_miss(self, tile, stat_file):
        stat_file.write("Per-Tile Miss Stats\n")
        self.__print_stat(stat_file, "miss_header", "Miss Type", "miss", "total", "hit rate")
        self.__print_stat(stat_file, "start_lbreak")
        for tag in self.tile_stat.keys():
            if(self.tile_stat[tag][tile]["global_ctr"]):
                self.__print_per_tile_tag_stats_miss(tile, stat_file, tag)
        self.__print_stat(stat_file, "end_lbreak")
        return   




    # prints all four types of stats, timing, instruction,
    # miss and stall for the entire manycore 
    def print_manycore_stats_all(self):
        stats_path = os.getcwd() + "/stats/"
        if not os.path.exists(stats_path):
            os.mkdir(stats_path)
        manycore_stats_file = open( (stats_path + "manycore_stats.log"), "w")
        self.__print_manycore_stats_tag(manycore_stats_file)
        self.__print_manycore_stats_tile_group_timing(manycore_stats_file)
        self.__print_manycore_stats_miss(manycore_stats_file)
        self.__print_manycore_stats_stall(manycore_stats_file)
        self.__print_manycore_stats_bubble(manycore_stats_file)
        self.__print_manycore_stats_instr(manycore_stats_file)
        self.__print_manycore_stats_tile_timing(manycore_stats_file, self.active)
        manycore_stats_file.close()
        return

    # prints all four types of stats, timing, instruction,
    # miss and stall for each tile group in a separate file  
    def print_per_tile_group_stats_all(self):
        stats_path = os.getcwd() + "/stats/tile_group/"
        if not os.path.exists(stats_path):
            os.mkdir(stats_path)
        
        for tg_id in range(max(self.num_tile_groups.values())):
            stat_file = open( (stats_path + "tile_group_" + str(tg_id) + "_stats.log"), "w")
            self.__print_per_tile_group_stats_tag(tg_id, stat_file)
            self.__print_per_tile_group_stats_timing(tg_id, stat_file)
            self.__print_per_tile_group_stats_miss(tg_id, stat_file)
            self.__print_per_tile_group_stats_stall(tg_id, stat_file)
            self.__print_per_tile_group_stats_bubble(tg_id, stat_file)
            self.__print_per_tile_group_stats_instr(tg_id, stat_file)
            stat_file.close()
        return



    # prints all four types of stats, timing, instruction,
    # miss and stall for each tile in a separate file  
    def print_per_tile_stats_all(self):
        stats_path = os.getcwd() + "/stats/tile/"
        if not os.path.exists(stats_path):
            os.mkdir(stats_path)
        for tile in self.active:
            stat_file = open( (stats_path + "tile_" + str(tile[0]) + "_" + str(tile[1]) + "_stats.log"), "w")
            self.__print_per_tile_stats_tag(tile, stat_file)
            self.__print_per_tile_stats_timing(tile, stat_file)
            self.__print_per_tile_stats_miss(tile, stat_file)
            self.__print_per_tile_stats_stall(tile, stat_file)
            self.__print_per_tile_stats_bubble(tile, stat_file)
            self.__print_per_tile_stats_instr(tile, stat_file)
            stat_file.close()







    # go though the input traces and extract start and end stats  
    # for each tile, and each tile group 
    # return number of tile groups, tile group timing stats, tile stats, and cycle parallel cnt
    # this function only counts the portion between two print_stat_start and end messages
    # in practice, this excludes the time in between executions,
    # i.e. when tiles are waiting to be loaded by the host.
    # cycle parallel cnt is the absolute cycles (not aggregate), i.e. the longest interval 
    # among tiles that participate in a certain tag 
    def __generate_tile_stats(self, traces, tiles):
        tags = list(range(self.max_tags)) + ["kernel"]
        num_tile_groups = {tag:0 for tag in tags}

        tile_stat_start = {tag: {tile:Counter() for tile in tiles} for tag in tags}
        tile_stat_end   = {tag: {tile:Counter() for tile in tiles} for tag in tags}
        tile_stat       = {tag: {tile:Counter() for tile in tiles} for tag in tags}

        tile_group_stat_start = {tag: [Counter() for tg_id in range(self.max_tile_groups)] for tag in tags}
        tile_group_stat_end   = {tag: [Counter() for tg_id in range(self.max_tile_groups)] for tag in tags}
        tile_group_stat       = {tag: [Counter() for tg_id in range(self.max_tile_groups)] for tag in tags}


        # For calculating the absolute cycle count across the manycore or tile groups
        # Contrary to the manycore_stats and tile_group_stats that sum the cycne count
        # of all tiles involved in running a kernel or a tile group, this structure
        # calculates the absolute cycle count. In other words, if multiple tiles run a
        # kernel or a tile group in `parallel`, this structure calculates the interval from
        # when the earliest tile starts running, until when the latest tile stops running
        # manycore_cycle_parallel_earliest_start: minimum start cycle among all tiles involved in a tag
        # cycle_parallel_latest_test   : maximum end cycle among all tiles involved in a tag
        # cycle_parlalel_interval      : manycore_cycle_parallel_latest_end - manycore_cycle_parallel_earliest_start
        # For calculating manycore stats, all tiles are considerd to be involved
        # For calculating tile group stats, only tiles inside the tile group are considered
        # For manycore (all tiles that participate in tag are included)
        manycore_cycle_parallel_earliest_start = {tag: 0 for tag in tags}
        manycore_cycle_parallel_latest_end     = {tag: 0 for tag in tags}
        manycore_cycle_parallel_cnt       = {tag: 0 for tag in tags}

        # For each tile group (only tiles in a tile group that participate in a tag are included)
        tile_group_cycle_parallel_earliest_start = {tag: [10000000 for tg_id in range(self.max_tile_groups)] for tag in tags}
        tile_group_cycle_parallel_latest_end     = {tag: [0 for tg_id in range(self.max_tile_groups)] for tag in tags}
        tile_group_cycle_parallel_cnt            = {tag: [0 for tg_id in range(self.max_tile_groups)] for tag in tags}


        tag_seen = {tag: {tile:False for tile in tiles} for tag in tags}


        for trace in traces:
            cur_tile = (trace['y'], trace['x'])

            # instantiate a CudaStatTag object with the tag value
            cst = CudaStatTag(trace["tag"])

            # Separate depending on stat type (start or end)
            if(cst.isStart):
                if(tag_seen[cst.tag][cur_tile]):
                    print ("Warning: missing end stat for tag {}, tile {},{}.".format(cst.tag, relative_x, relative_y))                    
                tag_seen[cst.tag][cur_tile] = True;

                # Only increase number of tile groups if haven't seen a trace from this tile group before
                if(not tile_group_stat_start[cst.tag][cst.tg_id]):
                    num_tile_groups[cst.tag] += 1 

                for op in self.all_ops:
                    tile_stat_start[cst.tag][cur_tile][op] = trace[op]
                    tile_group_stat_start[cst.tag][cst.tg_id][op] += trace[op]

                    # if op is cycle, find the earliest start cycle in tag among tiles in a tile group for parallel cycle stats
                    if (op == "global_ctr"):
                        tile_group_cycle_parallel_earliest_start[cst.tag][cst.tg_id] = min (trace[op], tile_group_cycle_parallel_earliest_start[cst.tag][cst.tg_id])


            elif (cst.isEnd):
                if(not tag_seen[cst.tag][cur_tile]):
                    print ("Warning: missing start stat for tag {}, tile {},{}.".format(cst.tag, relative_x, relative_y))
                tag_seen[cst.tag][cur_tile] = False;

                for op in self.all_ops:
                    tile_stat_end[cst.tag][cur_tile][op] = trace[op]
                    tile_group_stat_end[cst.tag][cst.tg_id][op] += trace[op]

                    # if op is cycle, find the latest end cycle in tag among tiles in a tile group for parallel cycle stats
                    if (op == "global_ctr"):
                        tile_group_cycle_parallel_latest_end[cst.tag][cst.tg_id] = max (trace[op], tile_group_cycle_parallel_latest_end[cst.tag][cst.tg_id])


                tile_stat[cst.tag][cur_tile] += tile_stat_end[cst.tag][cur_tile] - tile_stat_start[cst.tag][cur_tile]

            # And depending on kernel start/end
            if(cst.isKernelStart):
                if(tag_seen["kernel"][cur_tile]):
                    print ("Warning: missing Kernel End, tile: {}.".format(cur_tile))
                tag_seen["kernel"][cur_tile] = True;

                # Only increase number of tile groups if haven't seen a trace from this tile group before
                if(not tile_group_stat_start["kernel"][cst.tg_id]):
                    num_tile_groups["kernel"] += 1

                for op in self.all_ops:
                    tile_stat_start["kernel"][cur_tile][op] = trace[op]
                    tile_group_stat_start["kernel"][cst.tg_id][op] += trace[op]

                    # if op is cycle, find the earliest start cycle in kernel among tiles in a tile group for parallel cycle stats
                    if (op == "global_ctr"):
                        tile_group_cycle_parallel_earliest_start["kernel"][cst.tg_id] = min (trace[op], tile_group_cycle_parallel_earliest_start["kernel"][cst.tg_id])


            elif (cst.isKernelEnd):
                if(not tag_seen["kernel"][cur_tile]):
                    print ("Warning: missing Kernel Start, tile {}.".format(cur_tile))
                tag_seen["kernel"][cur_tile] = False;

                for op in self.all_ops:
                    tile_stat_end["kernel"][cur_tile][op] = trace[op]
                    tile_group_stat_end["kernel"][cst.tg_id][op] += trace[op]

                    # if op is cycle, find the latest end cycle in kernel among tiles in a tile group for parallel cycle stats
                    if (op == "global_ctr"):
                        tile_group_cycle_parallel_latest_end["kernel"][cst.tg_id] = max (trace[op], tile_group_cycle_parallel_latest_end["kernel"][cst.tg_id])


                tile_stat["kernel"][cur_tile] += tile_stat_end["kernel"][cur_tile] - tile_stat_start["kernel"][cur_tile]



        # Calculates the longest parallel cycle interval among all tiles that have
        # called print_stat with a certain tag, in other words, for all tiles that
        # run in parallel in a certain tag section, we calculate the parallel inteval
        # between when the earliest tile starts that section, until when the latest
        # tile finishes that section. Contrary to the manycore or tile group stats
        # that calculate the aggregate cycle count, this structure calcualtes the 
        # absolute cycle count it takes to execute a tagged section in parallel
        # manycore_cycle_parallel_earliest_start: minimum start cycle among all tiles involved in a tag
        # cycle_parallel_latest_test   : maximum end cycle among all tiles involved in a tag
        # cycle_parlalel_interval      : manycore_cycle_parallel_latest_end - manycore_cycle_parallel_earliest_start
        for tag in tags:
            manycore_cycle_parallel_earliest_start[tag] = min ([tile_stat_start[tag][tile]["global_ctr"] for tile in tiles])
            manycore_cycle_parallel_latest_end[tag]     = max ([tile_stat_end  [tag][tile]["global_ctr"] for tile in tiles])
            manycore_cycle_parallel_cnt[tag]       = manycore_cycle_parallel_latest_end[tag] - manycore_cycle_parallel_earliest_start[tag]


        # Generate all tile group stats by subtracting start time from end time
        for tag in tags:
            for tg_id in range(num_tile_groups[tag]):
                tile_group_stat[tag][tg_id] = tile_group_stat_end[tag][tg_id] - tile_group_stat_start[tag][tg_id]

                # also generate parallel cycle count (not aggregate, but the longest parallel interval) 
                # for each tile group by subtracting the earliest start cycle from the latest end cycle 
                tile_group_cycle_parallel_cnt[tag][tg_id] = tile_group_cycle_parallel_latest_end[tag][tg_id] - tile_group_cycle_parallel_earliest_start[tag][tg_id]

        # Generate total stats for each tile by summing all stats 
        for tag in tags:
            for tile in tiles:
                for instr in self.instrs:
                    tile_stat[tag][tile]["instr_total"] += tile_stat[tag][tile][instr]
                for stall in self.stalls:
                    # stall_depend count includes all stall_depend_ types, so all
                    # stall_depend_ subcategories are excluded to avoid double-counting
                    if (not stall.startswith('stall_depend_')):
                        tile_stat[tag][tile]["stall_total"] += tile_stat[tag][tile][stall]
                for bubble in self.bubbles:
                    tile_stat[tag][tile]["bubble_total"] += tile_stat[tag][tile][bubble]
                for miss in self.misses:
                    tile_stat[tag][tile]["miss_total"] += tile_stat[tag][tile][miss]

        # Generate total stats for each tile group by summing all stats 
        for tag in tags:
            for tg_id in range(num_tile_groups[tag]):
                for instr in self.instrs:
                    tile_group_stat[tag][tg_id]["instr_total"] += tile_group_stat[tag][tg_id][instr]
                for stall in self.stalls:
                    # stall_depend count includes all stall_depend_ types, so all
                    # stall_depend_ subcategories are excluded to avoid double-counting
                    if (not stall.startswith('stall_depend_')):
                        tile_group_stat[tag][tg_id]["stall_total"] += tile_group_stat[tag][tg_id][stall]
                for bubble in self.bubbles:
                    tile_group_stat[tag][tg_id]["bubble_total"] += tile_group_stat[tag][tg_id][bubble]
                for miss in self.misses:
                    tile_group_stat[tag][tg_id]["miss_total"] += tile_group_stat[tag][tg_id][miss]

                # Add the parallel cycle stats (not the aggregate, i.e. the longest parallel interval)
                # to the tile group stats manually
                tile_group_stat[tag][tg_id]["cycle_parallel_cnt"] = tile_group_cycle_parallel_cnt[tag][tg_id]

        self.instrs  += ["instr_total"]
        self.stalls  += ["stall_total"]
        self.bubbles += ["bubble_total"]
        self.misses  += ["miss_total"]
        self.all_ops += ["instr_total", "stall_total", "bubble_total", "miss_total"]

        return num_tile_groups, tile_group_stat, tile_stat, manycore_cycle_parallel_cnt

    # Calculate aggregate manycore stats dictionary by summing 
    # all per tile stats dictionaries
    def __generate_manycore_stats_all(self, tile_stat, manycore_cycle_parallel_cnt):
        # Create a dictionary and initialize elements to zero
        tags = list(range(self.max_tags)) + ["kernel"]
        manycore_stat = {tag: Counter() for tag in tags}
        for tag in tags:
            for tile in self.active:
                for op in self.all_ops:
                    manycore_stat[tag][op] += tile_stat[tag][tile][op]
            # The parallel cycle count (not aggregate), i.e. the longest 
            # interval among tiles that participate in a tag in parallel 
            # is generated in __generate_tile_stats and passed to this function
            # and is added as a new entry "cycle_parallel_cnt" to the manycore_stats
            manycore_stat[tag]["cycle_parallel_cnt"] = manycore_cycle_parallel_cnt[tag]

        return manycore_stat
 


    # Parses stat file's header to generate list of all 
    # operations based on type (stat, instruction, miss, stall)
    def parse_header(self, f):
        # Generate lists of stats/instruction/miss/stall names
        instrs  = []
        misses  = []
        stalls  = []
        bubbles = []
        stats   = []
        with open(f) as fp:
            rdr = csv.DictReader (fp, delimiter=",")
      
            header = rdr.fieldnames
            for item in header:
                if (item.startswith('instr_')):
                    if (not item == 'instr_total'):
                        instrs += [item]
                elif (item.startswith('miss_')):
                    misses += [item]
                elif (item.startswith('stall_')):
                    stalls += [item]
                elif (item.startswith('bubble_')):
                    bubbles += [item]
                else:
                    stats += [item]
        return (stats, instrs, misses, stalls, bubbles)


# parses input arguments
def parse_args():
    parser = argparse.ArgumentParser(description="Vanilla Stats Parser")
    parser.add_argument("--input", default="vanilla_stats.csv", type=str,
                        help="Vanilla stats log file")
    parser.add_argument("--tile", default=False, action='store_true',
                        help="Also generate separate stats files for each tile.")
    parser.add_argument("--tile_group", default=False, action='store_true',
                        help="Also generate separate stats files for each tile group.")
    args = parser.parse_args()
    return args


# main()
if __name__ == "__main__":
    np.seterr(divide='ignore', invalid='ignore')
    args = parse_args()
  
    st = VanillaStatsParser(args.tile, args.tile_group, args.input)
    st.print_manycore_stats_all()
    if(st.per_tile_stat):
        st.print_per_tile_stats_all()
    if(st.per_tile_group_stat):
        st.print_per_tile_group_stats_all()

  


#
#   vanilla_pc_histogram.py
#
#   vanilla_core PC execution count profiler
# 
#   input: vanilla_operation_trace.csv
#   output: PC Histogram stats pc_stats/manycore_pc_histogram.log 
#
#   @author Borna behsani@cs.washington.edu
#
#   How to use:
#   python vanilla_pc_histogram.py --trace {vanilla_ operation_trace.csv}
#                                  --tile (optional)
#
#   {tile}    also generate PC histogram for each tile in a separate file


import os
import sys
import csv
import argparse
from itertools import chain
from collections import Counter


class PCHistogram:

    _BSG_PC_ADDR_SHIFT = 2
    _BSG_PC_ADDR_STEP = 1 << _BSG_PC_ADDR_SHIFT


    # formatting parameters for aligned printing
    type_fmt = {"name"      : "{:<21}",
                "type"      : "{:>25}",
                "pc_start"  : "[{:>08x}",
                "pc_end"    : "{:>08x}]",
                "separator" : " - ",
                "cnt"       : "{:>25}"
               }


    print_format = {"pc_header"       : type_fmt["name"]     + type_fmt["type"]      + type_fmt["type"]   + type_fmt["type"] + type_fmt["type"] + "\n",
                    "pc_data"         : type_fmt["pc_start"] + type_fmt["separator"] + type_fmt["pc_end"] + type_fmt["cnt"]  + type_fmt["cnt"]  + type_fmt["cnt"] + type_fmt["cnt"] + "\n",
                    "lbreak"          : '=' * 121 + "\n",
                   }



    # default constructor
    def __init__(self, per_tile_stat, trace_file):

        self.per_tile_stat = per_tile_stat

        # Parse operation trace file and extract traces 
        self.traces, self.manycore_dim_y, self.manycore_dim_x = self.__parse_traces (trace_file)

        # Generate per tile PC count and tile PC cycle dictionary
        self.tile_pc_cnt, self.tile_pc_cycle = self.__generate_tile_pc_cnt(self.traces)

        # Generate per tile PC histogram by parsing the per tile PC execution count
        self.tile_pc_histogram_cnt, self.tile_pc_histogram_cycle = self.__generate_tile_pc_histogram(self.tile_pc_cnt, self.tile_pc_cycle)

        # Generate PC count dictionary for the entire network
        self.manycore_pc_cnt, self.manycore_pc_cycle = self.__generate_manycore_pc_cnt(self.tile_pc_cnt, self.tile_pc_cycle)

        # Generate PC histogram for the entire network by traversing total PC execution count
        self.manycore_pc_histogram_cnt, self.manycore_pc_histogram_cycle = self.__generate_pc_histogram(self.manycore_pc_cnt, self.manycore_pc_cycle)

        return


    # parse trace file and extract traces
    def __parse_traces(self, trace_file):
        traces = []
        unorigin = (0,0)
        with open(trace_file) as f:
            csv_reader = csv.DictReader(f, delimiter=",")
            for row in csv_reader:
                trace = {}
                trace["x"] = int(row["x"])
                trace["y"] = int(row["y"])  
                trace["operation"] = row["operation"]
                trace["cycle"] = int(row["cycle"])
                trace["pc"] = int(row["pc"], 16)
                unorigin = max((trace['y'], trace['x']), unorigin)
                traces.append(trace)

        manycore_dim_y = unorigin[0] + 1
        manycore_dim_x = unorigin[1] + 1

        return traces, manycore_dim_y, manycore_dim_x



    # print a line of stat into stats file based on stat type
    def __print_stat(self, stat_file, stat_type, *argv):
        stat_file.write(self.print_format[stat_type].format(*argv));
        return



    # Go through input file traces and count 
    # how many times each pc has been executed for each tile (tile_pc_cnt)
    # and how many cycles has been spent on each PC (tile_pc_cycle)
    def __generate_tile_pc_cnt(self, traces):
   
        # Number of times each PC is executed 
        tile_pc_cnt = [[Counter() for x in range(self.manycore_dim_x)] for y in range(self.manycore_dim_y)]
        # Number of cycles spent on each PC 
        tile_pc_cycle = [[Counter() for x in range(self.manycore_dim_x)] for y in range(self.manycore_dim_y)]

        for trace in traces:
            x = trace["x"]
            y = trace["y"]

            # Only add to pc count if at this cycle the processor is not stalled
            if(not (trace["operation"].startswith('stall_') or trace["operation"].endswith('_miss') or trace["operation"] == 'bubble')):
                tile_pc_cnt[y][x][trace["pc"]] += 1

            # But count towards the total number of cycles spend on this PC anyway
            tile_pc_cycle[y][x][trace["pc"]] += 1

        return tile_pc_cnt, tile_pc_cycle




    # Sum pc count and PC cycle  for all tiles to generate manycore pc count/cycle
    def __generate_manycore_pc_cnt(self, tile_pc_cnt, tile_pc_cycle):
        manycore_pc_cnt = Counter()
        manycore_pc_cycle = Counter()
        for y in range(self.manycore_dim_y):
            for x in range(self.manycore_dim_x):
                manycore_pc_cnt += tile_pc_cnt[y][x]
                manycore_pc_cycle += tile_pc_cycle[y][x]
        return manycore_pc_cnt, manycore_pc_cycle




    # For each tile x,y in the manycore 
    # Iterate over it's PC count dictionary and generate
    # PC histogram by calling self.__generate_pc_histogram
    def __generate_tile_pc_histogram(self, tile_pc_cnt, tile_pc_cycle):
        # Number of times each basic block is executed
        tile_pc_histogram_cnt = [[Counter() for x in range(self.manycore_dim_x)] for y in range(self.manycore_dim_y)]
        # Total number of cycles spent on each basic block
        tile_pc_histogram_cycle = [[Counter() for x in range(self.manycore_dim_x)] for y in range(self.manycore_dim_y)]

        for y in range(self.manycore_dim_y):
            for x in range(self.manycore_dim_x):
                tile_pc_histogram_cnt[y][x], tile_pc_histogram_cycle[y][x] = self.__generate_pc_histogram(tile_pc_cnt[y][x], tile_pc_cycle[y][x])

        return tile_pc_histogram_cnt, tile_pc_histogram_cycle


        


    # Iterate over the dictionary of {PC : # of execution}
    # and create basic blocks of adjacent PC's with the 
    # same number of execution 
    # Return a dictionary of {(start PC, end PC): # of execution}
    def __generate_pc_histogram(self, pc_cnt, pc_cycle):
        # Create a sorted list of all PC's executed 
        pc_list = sorted(pc_cnt.keys())
        histogram_cnt = Counter()
        histogram_cycle = Counter()

        start = 0
        end = 1

        # Sliding Window
        # Iterate over all PC's in order
        # Continue adding to a basic block as long as the current PC is immediately after 
        # the previous one, and the number of times current PC has been executed is 
        # equal to that of previous PC
        # Once this condition no longer holds, add basic block to histogram and repeat
        while (end < len(pc_list)):
            if (not (pc_cnt[pc_list[start]] == pc_cnt[pc_list[end]]
                     and pc_list[end] - pc_list[end-1] == self._BSG_PC_ADDR_STEP) ):
                
                # Number of times basic block is executed
                block_pc_cnt = pc_cnt[pc_list[start]]

                # Number of cycles spend on executing this basic block                
                block_pc_cycle = 0
                for idx in range(start, end):
                    block_pc_cycle += pc_cycle[pc_list[idx]] 


                histogram_cnt[(pc_list[start], pc_list[end-1])] = block_pc_cnt
                histogram_cycle[(pc_list[start], pc_list[end-1])] = block_pc_cycle
                start = end
            end += 1

        # Repeat once more for the last basic block 
        # Number of times basic block is executed
        block_pc_cnt = pc_cnt[pc_list[start]]

        # Number of cycles spend on executing this basic block                
        block_pc_cycle = 0
        for idx in range(start, end):
            block_pc_cycle += pc_cycle[pc_list[idx]] 


        histogram_cnt[(pc_list[start], pc_list[end-1])] = block_pc_cnt
        histogram_cycle[(pc_list[start], pc_list[end-1])] = block_pc_cycle




        return histogram_cnt, histogram_cycle



    # Given a PC histogram dictionary and an output file,
    # traverse the dictionary and print out every range of PC 
    # and it's number of execution in order 
    def __print_pc_histogram(self, stat_file, pc_histogram_cnt, pc_histogram_cycle):

        self.__print_stat(stat_file, "pc_header", "PC Block", "Exe Cnt", "Block Size", "Total Intrs Exe Cnt", "Total Cycles");
        self.__print_stat(stat_file, "lbreak");
       
        range_list = sorted(pc_histogram_cnt.keys())

        for range in range_list:
            # Print once more for the last basic block 
            start = range[0]
            end = range[1]
            pc_cnt = pc_histogram_cnt[range]
            block_size = ((end - start) >> self._BSG_PC_ADDR_SHIFT) + 1
            exe_cnt = pc_cnt * block_size
            cycle_cnt = pc_histogram_cycle[range]
    
            self.__print_stat(stat_file, "pc_data"
                                       , start
                                       , end
                                       , pc_cnt
                                       , block_size
                                       , exe_cnt
                                       , cycle_cnt);
        return
   


    # Prints the pc histogram for each tile in a separate file
    def print_per_tile_stats_all(self):
        stats_path = os.getcwd() + "/pc_stats/tile/"
        if not os.path.exists(stats_path):
            os.mkdir(stats_path)
        for y in range(self.manycore_dim_y):
            for x in range(self.manycore_dim_x):
                stat_file = open( (stats_path + "tile_" + str(y) + "_" + str(x) + "_pc_histogram.log"), "w")
                self.__print_pc_histogram(stat_file, self.tile_pc_histogram_cnt[y][x], self.tile_pc_histogram_cycle[y][x]);
                stat_file.close()
        return



    # Prints the pc histogram for the entire manycore 
    def print_manycore_stats_all(self):
        stats_path = os.getcwd() + "/pc_stats/"
        if not os.path.exists(stats_path):
            os.mkdir(stats_path)
        stats_file = open( (stats_path + "manycore_pc_histogram.log"), "w")
        self.__print_pc_histogram(stats_file, self.manycore_pc_histogram_cnt, self.manycore_pc_histogram_cycle);
        stats_file.close()
        return




# Parse input arguments and options 
def parse_args():  
    parser = argparse.ArgumentParser(description="Argument parser for vanilla_pc_histogram.py")
    parser.add_argument("--trace", default="vanilla_operation_trace.csv.log", type=str,
                        help="Vanilla operation log file")
    parser.add_argument("--tile", default=False, action='store_true',
                        help="Also generate separate pc histogram files for each tile.")

    args = parser.parse_args()
    return args




# main()
if __name__ == "__main__":
    args = parse_args()
    pch = PCHistogram(args.tile, args.trace)

    # Print PC histogram for the entire network
    pch.print_manycore_stats_all()

    # Print PC histogram for each tile in a separate file 
    if(args.tile):
        pch.print_per_tile_stats_all()



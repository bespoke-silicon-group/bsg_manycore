#
#   blood_graph.py
#
#   vanilla_core execution visualizer.
# 
#   input: vanilla_operation_trace.csv.log
#   output: bitmap file (blood.bmp)
#
#   @author Tommy Borna
#
#   How to use:
#   python blood_graph.py --cycle {start_cycle@end_cycle}  
#                         --abstract {optional} --input {vanilla_operation_trace.csv.log}
#
#   ex) python blood_graph.py --cycle 10000@150000  
#                             --abstract --input vanilla_operation_trace.csv.log
#
#   {cycle}       start_cycle@end_cycle of execution
#   {abstract}    used for abstract simplifed bloodgraph


import os
import sys
import csv
import argparse
from itertools import chain
from collections import Counter


class PCHistogram:
    _DEFAULT_START_CYCLE = 0 
    _DEFAULT_END_CYCLE   = 500000

    # Default coordinates of origin tile
    _BSG_ORIGIN_X = 0
    _BSG_ORIGIN_Y = 1

    _BSG_PC_MIN = 0x0000
    _BSG_PC_MAX = 0x2000

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


    print_format = {"pc_header"       : type_fmt["name"]     + type_fmt["type"]      + type_fmt["type"]   + type_fmt["type"] +  "\n",
                    "pc_data"         : type_fmt["pc_start"] + type_fmt["separator"] + type_fmt["pc_end"] + type_fmt["cnt"]  + type_fmt["cnt"]  + type_fmt["cnt"] + "\n",
                    "lbreak"          : '=' * 100 + "\n",
                   }



    # default constructor
    def __init__(self, manycore_dim_y, manycore_dim_x, per_tile_stat, input_file):

        self.manycore_dim_y = manycore_dim_y
        self.manycore_dim_x = manycore_dim_x
        self.manycore_dim = manycore_dim_y * manycore_dim_x
        self.per_tile_stat = per_tile_stat

        self.traces = []
        self.manycore_pc_cnt = Counter()
        self.tile_pc_cnt = Counter()
        self.min_pc_val = self._BSG_PC_MIN
        self.max_pc_val = self._BSG_PC_MAX


       # parse vanilla_operation_trace.log
        with open(input_file) as f:
            csv_reader = csv.DictReader(f, delimiter=",")
            for row in csv_reader:
                trace = {}
                trace["x"] = int(row["x"])  
                trace["y"] = int(row["y"])  
                trace["operation"] = row["operation"]
                trace["cycle"] = int(row["cycle"])
                trace["pc"] = int(row["pc"], 16)

                # update min and max pc read from traces 
                #self.max_pc_val = max(self.max_pc_val, trace["pc"])
                #self.min_pc_val = min(self.min_pc_val, trace["pc"])

                if (trace["pc"] >= self._BSG_PC_MIN and trace["pc"] <= self._BSG_PC_MAX):
                    self.traces.append(trace)

        self.tile_pc_cnt = self.__generate_tile_pc_cnt(self.traces)
        self.manycore_pc_cnt = self.__generate_manycore_pc_cnt(self.tile_pc_cnt)

        self.__print_manycore_stats_all(self.manycore_pc_cnt)
        if(self.per_tile_stat):
            self.__print_per_tile_stats_all(self.tile_pc_cnt)
        return 

    # print a line of stat into stats file based on stat type
    def __print_stat(self, stat_file, stat_type, *argv):
        stat_file.write(self.print_format[stat_type].format(*argv));
        return




    # Go through input file traces and count 
    # how many times each pc has been executed for each tile
    def __generate_tile_pc_cnt(self, traces):
   
        tile_pc_cnt = [[Counter() for x in range(self.manycore_dim_x)] for y in range(self.manycore_dim_y)]
        for trace in traces:
            relative_x = trace["x"] - self._BSG_ORIGIN_X
            relative_y = trace["y"] - self._BSG_ORIGIN_Y

            # Only add to pc count if at this cycle the processor is not stalled
            if(not (trace["operation"].startswith('stall_') or trace["operation"].endswith('_miss') or trace["operation"] == 'bubble')):
                tile_pc_cnt[relative_y][relative_x][trace["pc"]] += 1
        return tile_pc_cnt


    # Sum pc counts for all tiles to generate manycore pc count
    def __generate_manycore_pc_cnt(self, tile_pc_cnt):
        manycore_pc_cnt = Counter()
        for y in range(self.manycore_dim_y):
            for x in range(self.manycore_dim_x):
                manycore_pc_cnt += tile_pc_cnt[y][x]
        return manycore_pc_cnt

                



    # Traverse the pc counter in order for a specific tile 
    # and prints number of executions for every range
    def __print_per_tile_pc_histogram(self, y, x, stat_file, tile_pc_cnt):
        pc_start = self.min_pc_val 
        pc_end   = self.min_pc_val

        self.__print_stat(stat_file, "pc_header", "PC Block", "Exe Cnt", "Block Size", "Total Intrs Exe Cnt");
        self.__print_stat(stat_file, "lbreak");

        while (pc_start <= self.max_pc_val and pc_end <= self.max_pc_val):
            if(tile_pc_cnt[y][x][pc_start] == 0):
                pc_start += self._BSG_PC_ADDR_STEP
                pc_end += self._BSG_PC_ADDR_STEP
            elif (tile_pc_cnt[y][x][pc_start] == tile_pc_cnt[y][x][pc_end]):
                 pc_end += self._BSG_PC_ADDR_STEP
            else:
                 start = pc_start
                 end = pc_end - self._BSG_PC_ADDR_STEP
                 pc_cnt = tile_pc_cnt[y][x][start]
                 block_size = ((end - start) >> self._BSG_PC_ADDR_SHIFT) + 1
                 exe_cnt = pc_cnt * block_size

                 self.__print_stat(stat_file, "pc_data"
                                            , start
                                            , end
                                            , pc_cnt
                                            , block_size
                                            , exe_cnt);
                 pc_start = pc_end

        if(pc_start < self.max_pc_val - self._BSG_PC_ADDR_STEP):
            if (tile_pc_cnt[y][x][pc_start] > 0):
                 start = pc_start
                 end = pc_end - self._BSG_PC_ADDR_STEP
                 pc_cnt = tile_pc_cnt[y][x][start]
                 block_size = ((end - start) >> self._BSG_PC_ADDR_SHIFT) + 1
                 exe_cnt = pc_cnt * block_size

                 self.__print_stat(stat_file, "pc_data"
                                            , start
                                            , end
                                            , pc_cnt
                                            , block_size
                                            , exe_cnt);
        return


    # Prints the pc histogram for each tile in a separate file
    def __print_per_tile_stats_all(self, tile_pc_cnt):
        stats_path = os.getcwd() + "/pc_stats/tile/"
        if not os.path.exists(stats_path):
            os.mkdir(stats_path)
        for y in range(self.manycore_dim_y):
            for x in range(self.manycore_dim_x):
                stat_file = open( (stats_path + "tile_" + str(y) + "_" + str(x) + "_pc_histogram.log"), "w")
                self.__print_per_tile_pc_histogram(y, x, stat_file, tile_pc_cnt);
                stat_file.close()
        return






    # Traverse the pc counter in order for the entire manycore
    # and prints number of executions for every range
    def __print_manycore_pc_histogram(self, stat_file, manycore_pc_cnt):
        pc_start = self.min_pc_val 
        pc_end   = self.min_pc_val

        self.__print_stat(stat_file, "pc_header", "PC Block", "Exe Cnt", "Block Size", "Total Intrs Exe Cnt");
        self.__print_stat(stat_file, "lbreak");

        while (pc_start <= self.max_pc_val and pc_end <= self.max_pc_val):
            if (manycore_pc_cnt[pc_start] == 0):
                pc_start += self._BSG_PC_ADDR_STEP
                pc_end += self._BSG_PC_ADDR_STEP
            elif (manycore_pc_cnt[pc_start] == manycore_pc_cnt[pc_end]):
                 pc_end += self._BSG_PC_ADDR_STEP
            else:
                 start = pc_start
                 end = pc_end - self._BSG_PC_ADDR_STEP
                 pc_cnt = manycore_pc_cnt[start]
                 block_size = ((end - start) >> self._BSG_PC_ADDR_SHIFT) + 1
                 exe_cnt = pc_cnt * block_size

                 self.__print_stat(stat_file, "pc_data"
                                            , start
                                            , end
                                            , pc_cnt
                                            , block_size
                                            , exe_cnt);
                 pc_start = pc_end

        if(pc_start < self.max_pc_val - self._BSG_PC_ADDR_STEP):
            if (manycore_pc_cnt[pc_start] > 0):
                 start = pc_start
                 end = pc_end - self._BSG_PC_ADDR_STEP
                 pc_cnt = manycore_pc_cnt[start]
                 block_size = ((end - start) >> self._BSG_PC_ADDR_SHIFT) + 1
                 exe_cnt = pc_cnt * block_size

                 self.__print_stat(stat_file, "pc_data"
                                            , start
                                            , end
                                            , pc_cnt
                                            , block_size
                                            , exe_cnt);
        return


    # Prints the pc histogram for the entire manycore 
    def __print_manycore_stats_all(self, manycore_pc_cnt):
        stats_path = os.getcwd() + "/pc_stats/"
        if not os.path.exists(stats_path):
            os.mkdir(stats_path)
        stats_file = open( (stats_path + "manycore_pc_histogram.log"), "w")
        self.__print_manycore_pc_histogram(stats_file, manycore_pc_cnt);
        stats_file.close()
        return





# Parse input arguments and options 
def parse_args():  
    parser = argparse.ArgumentParser(description="Argument parser for vanilla_pc_histogram.py")
    parser.add_argument("--input", default="vanilla_operation_trace.csv.log", type=str,
                        help="Vanilla operation log file")
    parser.add_argument("--tile", default=False, action='store_true',
                        help="Also generate separate pc histogram files for each tile.")
    parser.add_argument("--dim-y", required=1, type=int,
                        help="Manycore Y dimension")
    parser.add_argument("--dim-x", required=1, type=int,
                        help="Manycore X dimension")

    args = parser.parse_args()
    return args


# main()
if __name__ == "__main__":
    args = parse_args()
    pch = PCHistogram(args.dim_y, args.dim_x, args.tile, args.input)

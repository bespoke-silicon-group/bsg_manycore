#
#   vcache_stall_graph.py
#
#   vcache execution visualizer.
# 
#   input:  vcache_operation_trace.csv
#           vcache_stats.csv (for timing)
#   output: stall graph file (vcache_stall_abstrat/detailed.png)
#           stall graph key  (vcache_key_abstract/detailed.png)
#
#   @author Tommy, Borna
#
#   How to use:
#   python vcache_stall_graph.py --trace {vcache_operation_trace.csv}
#                                --stats {vcache_stats.csv}
#                                --abstract {optional}
#                                --generate-key {optional}
#                                --cycle {start_cycle@end_cycle} (deprecated)
#
#   ex) python vcache_stall_graph.py --trace vcache_operation_trace.csv
#                                    --stats vcache_stats.csv
#                                    --abstract --generate-key
       #                             --cycle 10000@20000
#
#   {timing-stat}  used for extracting the timing window for stall graph
#   {abstract}     used for abstract simplifed stallgraph
#   {generate-key} also generates a color key for the stall graph
#   {cycle}        used for user-specified custom timing window 
#
#
#   Note: You can use the "Digital Color Meter" in MacOS in order to compare
#   the values from the color key to the values in the stallgraph, if you are
#   having trouble distinguishing a color.

import sys
import csv
import argparse
import warnings
import os.path
from PIL import Image, ImageDraw, ImageFont
from itertools import chain
from . import common


class VcacheStallGraph:
    # for generating the key
    _KEY_WIDTH  = 512
    _KEY_HEIGHT = 512


    # List of operations performed by vcache
    _OPERATION_LIST   = ["ld",
                         "ld_ld",
                         "ld_ldu",
                         "ld_lw",
                         "ld_lwu",
                         "ld_lh",
                         "ld_lhu",
                         "ld_lb",
                         "ld_lbu",
                                          
                         "st",     
                         "sm_sd",
                         "sm_sw",
                         "sm_sh",
                         "sm_sb",
                                          
                         "tagst",  
                         "tagfl",  
                         "taglv",  
                         "tagla",  
                         "afl",    
                         "aflinv", 
                         "ainv",   
                         "alock",  
                         "aunlock",
                         "atomic", 
                         "amoswap",
                         "amoor",  
                         "miss_ld",
                         "miss_st",
                         "dma_read_req",
                         "dma_write_req",
                         "idle",
                         "miss"]



    # coloring scheme for different types of operations
    # For abstract mode
    _ABSTRACT_OPERATION_COLOR = {"ld"              : (0x00, 0xff, 0x00) , ## green
                                 "ld_ld"           : (0x00, 0xff, 0x00) , ## green
                                 "ld_ldu"          : (0x00, 0xff, 0x00) , ## green
                                 "ld_lw"           : (0x00, 0xff, 0x00) , ## green
                                 "ld_lwu"          : (0x00, 0xff, 0x00) , ## green
                                 "ld_lh"           : (0x00, 0xff, 0x00) , ## green
                                 "ld_lhu"          : (0x00, 0xff, 0x00) , ## green
                                 "ld_lb"           : (0x00, 0xff, 0x00) , ## green
                                 "ld_lbu"          : (0x00, 0xff, 0x00) , ## green
                                 "st"              : (0x00, 0x00, 0xff) , ## blue
                                 "sm_sd"           : (0x00, 0x00, 0xff) , ## blue
                                 "sm_sw"           : (0x00, 0x00, 0xff) , ## blue
                                 "sm_sh"           : (0x00, 0x00, 0xff) , ## blue
                                 "sm_sb"           : (0x00, 0x00, 0xff) , ## blue
                                 "tagst"           : (0x00, 0x00, 0x00) , ## white 
                                 "tagfl"           : (0x00, 0x00, 0x00) , ## white 
                                 "taglv"           : (0x00, 0x00, 0x00) , ## white 
                                 "tagla"           : (0x00, 0x00, 0x00) , ## white 
                                 "afl"             : (0x00, 0x00, 0x00) , ## white 
                                 "aflinv"          : (0x00, 0x00, 0x00) , ## white 
                                 "ainv"            : (0x00, 0x00, 0x00) , ## white 
                                 "alock"           : (0x00, 0x00, 0x00) , ## white 
                                 "aunlock"         : (0x00, 0x00, 0x00) , ## white 
                                 "atomic"          : (0x00, 0x00, 0x00) , ## white 
                                 "amoswap"         : (0x00, 0x00, 0x00) , ## white 
                                 "amoor"           : (0x00, 0x00, 0x00) , ## white 
                                 "miss_ld"         : (0x00, 0xff, 0x00) , ## green
                                 "miss_st"         : (0x00, 0x00, 0xff) , ## blue 
                                 "dma_read_req"    : (0xff, 0xff, 0xff) , ## white 
                                 "dma_write_req"   : (0xff, 0xff, 0xff) , ## white 
                                 "idle"            : (0x40, 0x40, 0x40) , ## gray
                                 "miss"            : (0xff, 0x00, 0x00) , ## red
                                }



    # coloring scheme for different types of operations
    # For abstract mode
    _DETAILED_OPERATION_COLOR = {"ld"              : (0x00, 0xff, 0x00) , ## green
                                 "ld_ld"           : (0x00, 0xff, 0x00) , ## green
                                 "ld_ldu"          : (0x00, 0xff, 0x00) , ## green
                                 "ld_lw"           : (0x00, 0xff, 0x00) , ## green
                                 "ld_lwu"          : (0x00, 0xff, 0x00) , ## green
                                 "ld_lh"           : (0x00, 0xff, 0x00) , ## green
                                 "ld_lhu"          : (0x00, 0xff, 0x00) , ## green
                                 "ld_lb"           : (0x00, 0xff, 0x00) , ## green
                                 "ld_lbu"          : (0x00, 0xff, 0x00) , ## green
                                 "st"              : (0x00, 0x00, 0xff) , ## blue
                                 "sm_sd"           : (0x00, 0x00, 0xff) , ## blue
                                 "sm_sw"           : (0x00, 0x00, 0xff) , ## blue
                                 "sm_sh"           : (0x00, 0x00, 0xff) , ## blue
                                 "sm_sb"           : (0x00, 0x00, 0xff) , ## blue
                                 "tagst"           : (0x00, 0x00, 0x00) , ## white 
                                 "tagfl"           : (0x00, 0x00, 0x00) , ## white 
                                 "taglv"           : (0x00, 0x00, 0x00) , ## white 
                                 "tagla"           : (0x00, 0x00, 0x00) , ## white 
                                 "afl"             : (0x00, 0x00, 0x00) , ## white 
                                 "aflinv"          : (0x00, 0x00, 0x00) , ## white 
                                 "ainv"            : (0x00, 0x00, 0x00) , ## white 
                                 "alock"           : (0x00, 0x00, 0x00) , ## white 
                                 "aunlock"         : (0x00, 0x00, 0x00) , ## white 
                                 "atomic"          : (0x00, 0x00, 0x00) , ## white 
                                 "amoswap"         : (0x00, 0x00, 0x00) , ## white 
                                 "amoor"           : (0x00, 0x00, 0x00) , ## white 
                                 "miss_ld"         : (0x00, 0xff, 0x00) , ## green
                                 "miss_st"         : (0x00, 0x00, 0xff) , ## blue 
                                 "dma_read_req"    : (0xff, 0xff, 0xff) , ## white 
                                 "dma_write_req"   : (0xff, 0xff, 0xff) , ## white 
                                 "idle"            : (0x40, 0x40, 0x40) , ## gray
                                 "miss"            : (0xff, 0x00, 0x00) , ## red
                                } 



    # default constructor
    def __init__(self, trace_file, stats_file, cycle, abstract, no_stall_graph):

        self.abstract = abstract
        self.no_stall_graph = no_stall_graph

        # Determine coloring rules based on mode {abstract / detailed}
        if (self.abstract):
            self.operation_color     = self._ABSTRACT_OPERATION_COLOR
        else:
            self.operation_color     = self._DETAILED_OPERATION_COLOR


        # If trace file is missing exit with warning
        if not os.path.exists(trace_file):
            print("Warning: vcache trace file not found, skipping victim cache stall graph generation.")
            self.no_stall_graph = True
            return


        # Parse vcache operation trace file to generate traces
        self.traces = self.__parse_traces(trace_file)

        # Parse vcache stats file to generate timing stats 
        self.stats = self.__parse_stats(stats_file)

        # get number of victim cache banks
        self.__get_vcache_dim(self.traces)

        # get the timing window (start and end cycle) for stall graph
        self.start_cycle, self.end_cycle = self.__get_timing_window(self.traces, self.stats, cycle)


    # parses vcache_operation_trace.csv to generate operation traces
    def __parse_traces(self, trace_file):
        traces = []
        with open(trace_file) as f:
            csv_reader = csv.DictReader(f, delimiter=",")
            for row in csv_reader:
                trace = {}
                vcache = row["vcache"]
                trace["vcache"] = int (vcache[vcache.find("[")+1 : vcache.find("]")])
                trace["operation"] = row["operation"]
                trace["cycle"] = int(row["cycle"])
                traces.append(trace)
        return traces


    # Parses vcache_stats.csv to generate timing stats 
    # to gather start and end cycle of entire graph
    def __parse_stats(self, stats_file):
        stats = []
        if(stats_file):
            if (os.path.isfile(stats_file)):
                with open(stats_file) as f:
                    csv_reader = csv.DictReader(f, delimiter=",")
                    for row in csv_reader:
                        stat = {}
                        stat["global_ctr"] = int(row["global_ctr"])
                        stat["time"] = int(row["time"])
                        stats.append(stat)
            else:
                warnings.warn("Stats file not found, overriding stall graph's start/end cycle with traces.")
        return stats


    # look through the input file to get the number of vcache banks
    def __get_vcache_dim(self, traces):
        vcaches = [t["vcache"] for t in traces]
        self.vcache_max = max(vcaches)
        self.vcache_min = min(vcaches)
        self.vcache_dim = self.vcache_max - self.vcache_min +1
        return


    # Determine the timing window (start and end) cycle of graph 
    # The timing window will be calculated using:
    # Custom input: if custom start cycle is given by using the --cycle argument
    # Vcache stats file: otherwise if vcache stats file is given as input
    # Traces: otherwise the entire course of simulation 
    def __get_timing_window(self, traces, stats, cycle):
        custom_start, custom_end = cycle.split('@')

        if (custom_start):
            start = int(custom_start)
        elif (stats):
            start = stats[0]["global_ctr"]
        else:
            start = traces[0]["cycle"]


        if (custom_end):
            end = int(custom_end)
        elif (stats):
            end = stats[-1]["global_ctr"]
        else:
            end = traces[-1]["cycle"]

        return start, end


  
    # main public method
    def generate(self):
  

        # init image
        self.__init_image()

        # create image
        for trace in self.traces:
            self.__mark_trace(trace)

        #self.img.show()
        mode = "abstract" if self.abstract else "detailed"
        self.img.save(("vcache_stall_" + mode + ".png"))
        return

    # public method to generate key for vcache stall graph
    # called if --generate-key argument is true
    def generate_key(self, key_image_fname = "vcache_key"):
        img  = Image.new("RGB", (self._KEY_WIDTH, self._KEY_HEIGHT), "black")
        draw = ImageDraw.Draw(img)
        font = ImageFont.load_default()
        # the current row position of our key
        yt = 0

        # for each color in stalls...
        for operation in self.operation_color.keys():
            # get the font size
            (font_height,font_width) = font.getsize(operation)
            # draw a rectangle with color fill
            yb = yt + font_width
            # [0, yt, 64, yb] is [top left x, top left y, bottom right x, bottom left y]
            draw.rectangle([0, yt, 64, yb], self.operation_color[operation])
            # write the label for this color in white
            # (68, yt) = (top left x, top left y)
            # (255, 255, 255) = white
            draw.text((68, yt), operation, (255,255,255))
            # create the new row's y-coord
            yt += font_width

        # save the key
        mode = "abstract" if self.abstract else "detailed"
        img.save("{}.png".format(key_image_fname + "_" + mode))
        return

    # initialize image
    def __init_image(self):
        self.img_width = 2048   # default
        self.img_height = (((self.end_cycle-self.start_cycle)+self.img_width)//self.img_width)*(2+(self.vcache_dim))
        self.img = Image.new("RGB", (self.img_width, self.img_height), "black")
        self.pixel = self.img.load()
        return  


    # mark the trace on output image
    def __mark_trace(self, trace):

        # ignore trace outside the cycle range
        if trace["cycle"] < self.start_cycle or trace["cycle"] >= self.end_cycle:
            return

        # determine pixel location
        cycle = (trace["cycle"] - self.start_cycle)
        col = cycle % self.img_width
        floor = cycle // self.img_width
        vcache = trace["vcache"]
        row = floor*(2+(self.vcache_dim)) + (vcache)


        # determine color
        if trace["operation"] in self.operation_color.keys():
            self.pixel[col,row] = self.operation_color[trace["operation"]]
        else:
            raise Exception('Invalid operation in vcache operation trace log {}'.format(trace["operation"]))
        return

 
# Parse input arguments and options 
def add_args(parser):  
    parser.add_argument("--no-stall-graph", default=False, action='store_true',
                        help="Skip stall graph generation")

def main(args): 
    bg = VcacheStallGraph(args.vcache_trace, args.vcache_stats, args.cycle, args.abstract, args.no_stall_graph)
    if not args.no_stall_graph:
        bg.generate()
    if args.generate_key:
        bg.generate_key()

# main()
if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Argument parser for stall_graph.py")
    common.add_args(parser)
    add_args(parser)
    args = parser.parse_args()
    main(args)

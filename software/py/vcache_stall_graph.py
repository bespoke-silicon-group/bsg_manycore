#
#   vcache_stall_graph.py
#
#   victim cache execution visualizer.
# 
#   input: vcache_operation_trace.csv.log
#          vcache_stats.csv (for timing)
#   output: stall graph file (vcache_stall_abstrat/detailed.png)
#           stall graph key  (vcache_key_abstract/detailed.png)
#
#   @author Borna Tommy
#
#   How to use:
#   python vcache_stallgraph.py --input {vcache_operation_trace.csv}
#                               --timing-stat {vcache_stats.csv}
#                               --abstract {optional}
#                               --generate-key {optional}
#
#   ex) python vcache_stall_graph.py --input vcache_operation_trace.csv
#                                    --timing-stat vcache_stats.csv
#                                    --abstract --generate-key
#
#   {timing-stat}  used for extracting the timing window for stall graph
#   {abstract}     used for abstract simplifed stall graph
#   {generate-key} also generates a color key for the stall graph


import sys
import csv
import argparse
from PIL import Image, ImageDraw, ImageFont
from itertools import chain




class VCacheStallGraph:
    # for generating the key
    _KEY_WIDTH  = 512
    _KEY_HEIGHT = 512
    _DEFAULT_START_CYCLE = 0 
    _DEFAULT_END_CYCLE   = 200000

    # default constructor
    def __init__(self, timing_stats_file, abstract):

        self.timing_stats_file = timing_stats_file
        self.abstract = abstract

        # List of operations performed
        self.operation_list = ["ld",     
                               "st",     
                               "mask",   
                               "sigext", 
                               "tagst",  
                               "tagfl",  
                               "taglv",  
                               "tagla",  
                               "afl",    
                               "aflinv", 
                               "ainv",   
                               "alock",  
                               "aunlock",
                               "tag_read",
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
        self.abstract_operation_color = {"ld"              : (0x00, 0xff, 0x00) , ## green
                                         "st"              : (0x00, 0x00, 0xff) , ## blue
                                         "mask"            : (0x00, 0x00, 0x00) , ## white 
                                         "sigext"          : (0x00, 0x00, 0x00) , ## white 
                                         "tagst"           : (0x00, 0x00, 0x00) , ## white 
                                         "tagfl"           : (0x00, 0x00, 0x00) , ## white 
                                         "taglv"           : (0x00, 0x00, 0x00) , ## white 
                                         "tagla"           : (0x00, 0x00, 0x00) , ## white 
                                         "afl"             : (0x00, 0x00, 0x00) , ## white 
                                         "aflinv"          : (0x00, 0x00, 0x00) , ## white 
                                         "ainv"            : (0x00, 0x00, 0x00) , ## white 
                                         "alock"           : (0x00, 0x00, 0x00) , ## white 
                                         "aunlock"         : (0x00, 0x00, 0x00) , ## white 
                                         "tag_read"        : (0x00, 0x00, 0x00) , ## white 
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
        # For detailed mode
        self.detailed_operation_color = {"ld"              : (0x00, 0xff, 0x00) , ## green
                                         "st"              : (0x00, 0x00, 0xff) , ## blue
                                         "mask"            : (0x00, 0x00, 0x00) , ## white 
                                         "sigext"          : (0x00, 0x00, 0x00) , ## white 
                                         "tagst"           : (0x00, 0x00, 0x00) , ## white 
                                         "tagfl"           : (0x00, 0x00, 0x00) , ## white 
                                         "taglv"           : (0x00, 0x00, 0x00) , ## white 
                                         "tagla"           : (0x00, 0x00, 0x00) , ## white 
                                         "afl"             : (0x00, 0x00, 0x00) , ## white 
                                         "aflinv"          : (0x00, 0x00, 0x00) , ## white 
                                         "ainv"            : (0x00, 0x00, 0x00) , ## white 
                                         "alock"           : (0x00, 0x00, 0x00) , ## white 
                                         "aunlock"         : (0x00, 0x00, 0x00) , ## white 
                                         "tag_read"        : (0x00, 0x00, 0x00) , ## white 
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




        # Determine coloring rules based on mode {abstract / detailed}
        if (self.abstract):
            self.operation_color     = self.abstract_operation_color
        else:
            self.operation_color     = self.detailed_operation_color


        # Parse timing stat file vcache_stats.csv
        # to gather start and end cycle of entire graph
        self.timing_stats = []
        try:
            with open(self.timing_stats_file) as f:
                csv_reader = csv.DictReader(f, delimiter=",")
                for row in csv_reader:
                    timing_stat = {}
                    timing_stat["global_ctr"] = int(row["global_ctr"])
                    self.timing_stats.append(timing_stat)

            # If there are at least two stats recovered from vcache_stats.csv for start and end cycle
            if (len(self.timing_stats) >= 2):
                self.start_cycle = self.timing_stats[0]["global_ctr"]
                self.end_cycle = self.timing_stats[-1]["global_ctr"]
            else:
                self.start_cycle = self._DEFAULT_START_CYCLE
                self.end_cycle = self._DEFAULT_END_CYCLE
            return

        # If the vcache_stats.csv file has not been given as input
        # Use the default values for start and end cycles
        except IOError as e:
            self.start_cycle = self._DEFAULT_START_CYCLE
            self.end_cycle = self._DEFAULT_END_CYCLE

        return



  
    # main public method
    def generate(self, input_file):
        # parse vcache_operation_trace.csv
        traces = []
        with open(input_file) as f:
            csv_reader = csv.DictReader(f, delimiter=",")
            for row in csv_reader:
                trace = {}
                vcache = row["vcache"]
                trace["vcache"] = int (vcache[vcache.find("[")+1 : vcache.find("]")])
                trace["operation"] = row["operation"]
                trace["cycle"] = int(row["cycle"])
                traces.append(trace)
  
        # get number of victim cache banks
        self.__get_vcache_dim(traces)

        # init image
        self.__init_image()

        # create image
        for trace in traces:
            self.__mark_trace(trace)

        #self.img.show()
        mode = "abstract" if self.abstract else "detailed"
        self.img.save(("vcache_stall_" + mode + ".png"))
        return

    # public method to generate key for vcache stall graph
    # called if --generate-key argument is true
    def generate_key(self, key_image_fname = "key"):
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

    # look through the input file to get the number of vcache banks
    def __get_vcache_dim(self, traces):
        vcaches = list(map(lambda t: t["vcache"], traces))
        self.vcache_max = max(vcaches)
        self.vcache_min = min(vcaches)
        self.vcache_dim = self.vcache_max - self.vcache_min +1
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


# Deprecated: We no longer pass in the cycles by hand 
# The appliation parses the start/end cycles from vcache_stats.csv file
# The action to take in two input arguments for start and 
# end cycle of execution in the form of start_cycle@end_cycle
class CycleAction(argparse.Action):
    def __call__(self, parser, namespace, cycle, option_string=None):
        start_str,end_str = cycle.split("@")

        # Check if start cycle is given as input
        if(not start_str):
            start_cycle = BloodGraph._DEFAULT_START_CYCLE
        else:
            start_cycle = int(start_str)

        # Check if end cycle is given as input
        if(not end_str):
            end_cycle = BloodGraph._DEFAULT_END_CYCLE
        else:
            end_cycle = int(end_str)

        # check if start cycle is before end cycle
        if(start_cycle > end_cycle):
            raise ValueError("start cycle {} cannot be larger than end cycle {}.".format(start_cycle, end_cycle))

        setattr(namespace, "start", start_cycle)
        setattr(namespace, "end", end_cycle)
 
# Parse input arguments and options 
def parse_args():  
    parser = argparse.ArgumentParser(description="Argument parser for vcache_stall_graph.py")
    parser.add_argument("--input", default="vcache_operation_trace.csv", type=str,
                        help="VCache operation log file")
    parser.add_argument("--timing-stats", default="vcache_stats.csv", type=str,
                        help="VCache stats log file")
    parser.add_argument("--cycle", nargs='?', required=0, action=CycleAction, 
                        const = (str(VCacheStallGraph._DEFAULT_START_CYCLE)+"@"+str(VCacheStallGraph._DEFAULT_END_CYCLE)),
                        help="Cycle window of stall graph as start_cycle@end_cycle.")
    parser.add_argument("--abstract", default=False, action='store_true',
                        help="Type of stall graph - abstract / detailed")
    parser.add_argument("--generate-key", default=False, action='store_true',
                        help="Generate a key image")
    parser.add_argument("--no-stall-graph", default=False, action='store_true',
                        help="Skip stall graph generation")

    args = parser.parse_args()
    return args


# main()
if __name__ == "__main__":
    args = parse_args()
  
    bg = VCacheStallGraph(args.timing_stats, args.abstract)
    if not args.no_stall_graph:
        bg.generate(args.input)
    if args.generate_key:
        bg.generate_key()


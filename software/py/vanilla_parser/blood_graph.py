#
#   blood_graph.py
#
#   vanilla_core execution visualizer.
#
#   input:  vanilla_operation_trace.csv
#           vanilla_stats.csv (for timing)
#   output: blood graph file (blood_abstrat/detailed.png)
#           blood graph key  (key_abstract/detailed.png)
#
#   @author Tommy, Borna
#
#   How to use:
#   python blood_graph.py --trace {vanilla_operation_trace.csv}
#                         --stats {vanilla_stats.csv}
#                         --abstract {optional}
#                         --generate-key {optional}
#                         --cycle {start_cycle@end_cycle}
#
#   ex) python blood_graph.py --trace vanilla_operation_trace.csv
#                             --stats vanilla_stats.csv
#                             --abstract --generate-key
#                             --cycle 10000@20000
#
#
#   {stats}        used for extracting the timing window for blood graph
#   {abstract}     used for abstract simplifed bloodgraph
#   {generate-key} also generates a color key for the blood graph
#   {cycle}        used for user-specified custom timing window
#
#
#   Note: You can use the "Digital Color Meter" in MacOS in order to compare
#   the values from the color key to the values in the bloodgraph, if you are
#   having trouble distinguishing a color.


import sys
import csv
import argparse
import warnings
import os.path
from PIL import Image, ImageDraw, ImageFont
from itertools import chain
from . import common


class BloodGraph:
    # for generating the key
    _KEY_WIDTH  = 512
    _KEY_HEIGHT = 512


    # List of types of stalls incurred by the core
    _STALLS_LIST   = ["stall_depend_dram_load",
                      "stall_depend_group_load",
                      "stall_depend_global_load",
                      "stall_depend_idiv",
                      "stall_depend_fdiv",
                      "stall_depend_local_load",
                      "stall_depend_imul",
                      "stall_amo_aq",
                      "stall_amo_rl",
                      "stall_bypass",
                      "stall_lr_aq",
                      "stall_fence",
                      "stall_remote_req",
                      "stall_remote_credit",
                      "stall_fdiv_busy",
                      "stall_idiv_busy",
                      "stall_fcsr",
                      "stall_remote_ld",
                      "stall_ifetch_wait",
                      "stall_remote_flw_wb",
                      "bubble_branch_miss",
                      "bubble_jalr_miss",
                      "bubble_icache_miss"]


    # List of types of integer instructions executed by the core
    _INSTRS_LIST    = [
                       "local_ld",
                       "local_st",
                       "remote_ld_dram",
                       "remote_ld_global",
                       "remote_ld_group",
                       "remote_ld_shared",
                       "remote_st_dram",
                       "remote_st_global",
                       "remote_st_group",
                       "remote_st_shared",
                       "local_flw",
                       "local_fsw",
                       "remote_flw_dram",
                       "remote_flw_global",
                       "remote_flw_group",
                       "remote_flw_shared",
                       "remote_fsw_dram",
                       "remote_fsw_global",
                       "remote_fsw_group",
                       "remote_fsw_shared",
                       # icache_miss is no longer treated as an instruction
                       # but treated the same as stall_ifetch_wait
                       # "icache_miss",
                       "lr",
                       "lr_aq",
                       "amoswap",
                       "amoor", 
                       "beq",
                       "bne",
                       "blt",
                       "bge",
                       "bltu",
                       "bgeu",
                       "jal",
                       "jalr",
                       "beq_miss",
                       "bne_miss",
                       "blt_miss",
                       "bge_miss",
                       "bltu_miss",
                       "bgeu_miss",
                       "jalr_miss",
                       "sll", 
                       "slli", 
                       "srl", 
                       "srli", 
                       "sra", 
                       "srai",          
                       "add",      
                       "addi",    
                       "sub",      
                       "lui",      
                       "auipc",  
                       "xor",      
                       "xori",    
                       "or",        
                       "ori",      
                       "and",      
                       "andi",    
                       "slt",      
                       "slti",    
                       "sltu",    
                       "sltiu",  
                       "div",      
                       "divu",    
                       "rem",      
                       "remu",    
                       "mul",      
                       "fence",  
                       "csrrw",  
                       "csrrs",  
                       "csrrc",  
                       "csrrwi",
                       "csrrsi",
                       "csrrci",
                       "unknown"]


    # List of types of floating point instructions executed by the core
    _FP_INSTRS_LIST = ["fadd",
                       "fsub",
                       "fmul",
                       "fsgnj",
                       "fsgnjn",
                       "fsgnjx",
                       "fmin",
                       "fmax",
                       "fcvt_s_w",
                       "fcvt_s_wu",
                       "fmv_w_x",
                       "fmadd",
                       "fmsub",
                       "fnmsub",
                       "fnmadd",
                       "feq",
                       "flt",
                       "fle",
                       "fcvt_w_s",
                       "fcvt_wu_s",
                       "fclass",
                       "fmv_x_w",
                       "fdiv",
                       "fsqrt"]


    # Coloring scheme for different types of operations
    # For detailed mode
    # i_cache miss is treated the same is stall_ifetch_wait
    _DETAILED_STALL_BUBBLE_COLOR = {
                                     "stall_depend_dram_load"    : (0xff, 0x00, 0x00), ## red
                                     "stall_depend_group_load"   : (0x00, 0xff, 0x00), ## green
                                     "stall_depend_shared_load"  : (0x00, 0xff, 0x00), ## green
                                     "stall_depend_global_load"  : (0x00, 0x55, 0x00), ## dark green
                                     "stall_depend_local_load"   : (0x00, 0xff, 0xff), ## cyan
                                     
                                     "stall_depend_idiv"         : (0xff, 0xf0, 0xa0), ## light orange
                                     "stall_depend_fdiv"         : (0xff, 0xf0, 0xa0), ## light orange
                                     "stall_depend_imul"         : (0xff, 0xf0, 0xa0), ## light orange
                                     
                                     "stall_fdiv_busy"           : (0x00, 0xaa, 0xff), ## dark cyan
                                     "stall_idiv_busy"           : (0x00, 0xaa, 0xff), ## dark cyan

                                     "stall_amo_aq"              : (0x8b, 0x45, 0x13), ## brown
                                     "stall_amo_rl"              : (0x8b, 0x45, 0x13), ## brown
                                     
                                     "stall_bypass"              : (0xff, 0x00, 0xff), ## pink
                                     "stall_lr_aq"               : (0x40, 0x40, 0x40), ## dark gray
                                     "stall_fence"               : (0x00, 0x00, 0x80), ## navy blue
                                     "stall_remote_req"          : (0xff, 0xff, 0x00), ## yellow
                                     "stall_remote_credit"       : (0x80, 0x00, 0x00), ## maroon
                                     
                                     
                                     "stall_fcsr"                : (0x00, 0x55, 0xff), ## dark blue
                                     "stall_remote_ld"           : (0xaa, 0x00, 0x00), ## dark red

                                     "stall_remote_flw_wb"       : (0xff, 0xff, 0x80), ## light yellow
                                     
                                     "bubble_branch_miss"        : (0x80, 0x00, 0x80), ## purple
                                     "bubble_jalr_miss"          : (0xff, 0xa5, 0x00), ## orange

                                     "icache_miss"               : (0x00, 0x00, 0xff), ## blue
                                     "bubble_icache_miss"        : (0x00, 0x00, 0xff), ## blue
                                     "stall_ifetch_wait"         : (0x00, 0x00, 0xff), ## blue
                                  }
    _DETAILED_UNIFIED_INSTR_COLOR    =                             (0xff, 0xff, 0xff)  ## white
    _DETAILED_UNIFIED_FP_INSTR_COLOR =                             (0xff, 0xaa, 0xff)  ## light pink


    # Coloring scheme for different types of operations
    # For abstract mode
    # i_cache miss is treated the same is stall_ifetch_wait
    _ABSTRACT_STALL_BUBBLE_COLOR = {
                                     "stall_depend_dram_load"    : (0xff, 0x00, 0x00), ## red
                                     "stall_depend_group_load"   : (0x00, 0xff, 0x00), ## green
                                     "stall_depend_shared_load"  : (0x00, 0xff, 0x00), ## green
                                     "stall_depend_global_load"  : (0x00, 0xff, 0x00), ## green
                                     "stall_depend_local_load"   : (0x00, 0xff, 0xff), ## cyan
                                     
                                     "stall_depend_idiv"         : (0xff, 0xff, 0xff), ## white
                                     "stall_depend_fdiv"         : (0xff, 0xff, 0xff), ## white
                                     "stall_depend_imul"         : (0xff, 0xff, 0xff), ## white

                                     "stall_fdiv_busy"           : (0xff, 0xff, 0xff), ## white
                                     "stall_idiv_busy"           : (0xff, 0xff, 0xff), ## white
                                     
                                     "stall_amo_aq"              : (0x00, 0x00, 0x00), ## black
                                     "stall_amo_rl"              : (0x00, 0x00, 0x00), ## black
                                     
                                     "stall_bypass"              : (0x00, 0x00, 0x00), ## black
                                     "stall_lr_aq"               : (0x40, 0x40, 0x40), ## dark gray
                                     "stall_fence"               : (0x00, 0x00, 0x00), ## black
                                     "stall_remote_req"          : (0x00, 0x00, 0x00), ## black
                                     "stall_remote_credit"       : (0x00, 0x00, 0x00), ## black
                                     
                                     "stall_fcsr"                : (0x00, 0x00, 0x00), ## black
                                     "stall_remote_ld"           : (0x00, 0x00, 0x00), ## black

                                     "stall_remote_flw_wb"       : (0x00, 0x00, 0x00), ## black
                                     
                                     "bubble_branch_miss"        : (0x00, 0x00, 0x00), ## black
                                     "bubble_jalr_miss"          : (0x00, 0x00, 0x00), ## black

                                     "icache_miss"               : (0x00, 0x00, 0xff), ## blue
                                     "bubble_icache_miss"        : (0x00, 0x00, 0xff), ## blue
                                     "stall_ifetch_wait"         : (0x00, 0x00, 0xff), ## blue
                                   }
    _ABSTRACT_UNIFIED_INSTR_COLOR    =                             (0xff, 0xff, 0xff)  ## white
    _ABSTRACT_UNIFIED_FP_INSTR_COLOR =                             (0xff, 0xff, 0xff)  ## white



    # default constructor
    def __init__(self, trace_file, stats_file, cycle, abstract):

        self.abstract = abstract

        # Determine coloring rules based on mode {abstract / detailed}
        if (self.abstract):
            self.stall_bubble_color     = self._ABSTRACT_STALL_BUBBLE_COLOR
            self.unified_instr_color    = self._ABSTRACT_UNIFIED_INSTR_COLOR
            self.unified_fp_instr_color = self._ABSTRACT_UNIFIED_INSTR_COLOR
        else:
            self.stall_bubble_color     = self._DETAILED_STALL_BUBBLE_COLOR
            self.unified_instr_color    = self._DETAILED_UNIFIED_INSTR_COLOR
            self.unified_fp_instr_color = self._DETAILED_UNIFIED_INSTR_COLOR


        # Parse vanilla operation trace file to generate traces
        self.traces = self.__parse_traces(trace_file)

        # Parse vanilla stats file to generate timing stats
        self.stats = self.__parse_stats(stats_file)

        # get tile group diemsnions
        self.__get_tile_group_dim(self.traces)

        # get the timing window (start and end cycle) for blood graph
        self.start_cycle, self.end_cycle = self.__get_timing_window(self.traces, self.stats, cycle)


    # parses vanilla_operation_trace.csv to generate operation traces
    def __parse_traces(self, trace_file):
        traces = []
        with open(trace_file) as f:
            csv_reader = csv.DictReader(f, delimiter=",")
            for row in csv_reader:
                trace = {}
                trace["x"] = int(row["x"])
                trace["y"] = int(row["y"])
                trace["operation"] = row["operation"]
                trace["cycle"] = int(row["cycle"])
                traces.append(trace)
        return traces


    # Parses vanilla_stats.csv to generate timing stats
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
                warnings.warn("Stats file not found, overriding blood graph's start/end cycle with traces.")
        return stats


    # look through the input file to get the tile group dimension (x,y)
    def __get_tile_group_dim(self, traces):
        xs = [t["x"] for t in traces]
        ys = [t["y"] for t in traces]
        self.xmin = min(xs)
        self.xmax = max(xs)
        self.ymin = min(ys)
        self.ymax = max(ys)

        self.xdim = self.xmax-self.xmin+1
        self.ydim = self.ymax-self.ymin+1
        return


    # Determine the timing window (start and end) cycle of graph
    # The timing window will be calculated using:
    # Custom input: if custom start cycle is given by using the --cycle argument
    # Vanilla stats file: otherwise if vanilla stats file is given as input
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
        self.img.save(("blood_" + mode + ".png"))
        return

    # public method to generate key for bloodgraph
    # called if --generate-key argument is true
    def generate_key(self, key_image_fname = "key"):
        img  = Image.new("RGB", (self._KEY_WIDTH, self._KEY_HEIGHT), "black")
        draw = ImageDraw.Draw(img)
        font = ImageFont.load_default()
        # the current row position of our key
        yt = 0
        # for each color in stalls...
        for (operation,color) in chain([(stall_bubble, self.stall_bubble_color[stall_bubble]) for stall_bubble in self._STALLS_LIST],
                                 [("unified_instr"    ,self.unified_instr_color),
                                  ("unified_fp_instr" ,self.unified_fp_instr_color)]):

            # get the font size
            (font_height,font_width) = font.getsize(operation)
            # draw a rectangle with color fill
            yb = yt + font_width
            # [0, yt, 64, yb] is [top left x, top left y, bottom right x, bottom left y]
            draw.rectangle([0, yt, 64, yb], color)
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
        self.img_height = (((self.end_cycle-self.start_cycle)+self.img_width)//self.img_width)*(2+(self.xdim*self.ydim))
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
        tg_x = trace["x"] - self.xmin
        tg_y = trace["y"] - self.ymin
        row = floor*(2+(self.xdim*self.ydim)) + (tg_x+(tg_y*self.xdim))


        # determine color
        if trace["operation"] in self.stall_bubble_color.keys():
            self.pixel[col,row] = self.stall_bubble_color[trace["operation"]]
        elif trace["operation"] in self._INSTRS_LIST:
            self.pixel[col,row] = self.unified_instr_color
        elif trace["operation"] in self._FP_INSTRS_LIST:
            self.pixel[col,row] = self.unified_fp_instr_color
        else:
            raise Exception('Invalid operation in vanilla operation trace log {}'.format(trace["operation"]))
        return



# Parse input arguments and options
def add_args(parser):
    parser.add_argument("--no-blood-graph", default=False, action='store_true',
                        help="Skip blood graph generation")

def main(args):
    bg = BloodGraph(args.trace, args.stats, args.cycle, args.abstract)
    if not args.no_blood_graph:
        bg.generate()
    if args.generate_key:
        bg.generate_key()

# main()
if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Argument parser for blood_graph.py")
    common.add_args(parser)
    add_args(parser)
    args = parser.parse_args()
    main(args)

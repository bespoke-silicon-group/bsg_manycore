#
#   blood_graph.py
#
#   vanilla_core execution visualizer.
# 
#   input: vanilla_operation_trace.log
#   output: bitmap file (blood.bmp)
#
#   @author tommy and borna
#
#   How to use:
#   python blood_graph.py --time {start_time@end_time} --timestamp{timestep} 
#                         --abstract {optional} --input {vanilla_operation_trace.log}
#
#   ex) python blood_graph.py --time 6000000@15000000 --timestamp 20 
#                             --abstract --input vanilla_operation_trace.log
#
#   {time}        start_time@end_time in picosecond
#   {timestep}    Distance between two consecutive traces (clock period) in picoseconds
#   {abstract}    used for abstract simplifed bloodgraph
# 


import sys
import csv
import argparse
from PIL import Image, ImageDraw, ImageFont
from itertools import chain


DEFAULT_START_TIME = 18000000000
DEFAULT_END_TIME   = 20000000000
DEFAULT_TIMESTAMP  = 8000
DEFAULT_MODE       = "detailed"
DEFAULT_INPUT_FILE = "vanilla_operation_trace.log"


class BloodGraph:
  # for generating the key
  KEY_WIDTH  = 256
  KEY_HEIGHT = 256
  # default constructor
  def __init__(self, start_time, end_time, timestep, abstract):

    self.start_time = start_time
    self.end_time = end_time
    self.timestep = timestep
    self.abstract = abstract

    # List of types of stalls incurred by the core 
    self.stalls_list   = {"stall_depend",
                          "stall_depend_local_load",
                          "stall_depend_remote_load",
                          "stall_depend_local_remote_load",
                          "stall_fp_local_load",
                          "stall_fp_remote_load",
                          "stall_force_wb",
                          "stall_ifetch_wait",
                          "stall_icache_store",
                          "stall_lr_aq",
                          "stall_md",
                          "stall_remote_req",
                          "stall_local_flw" }


    # List of types of integer instructions executed by the core 
    self.instr_list    = {"local_ld",
                          "local_st",
                          "remote_ld",
                          "remote_st",
                          "local_flw",
                          "local_fsw",
                          "remote_flw",
                          "remote_fsw",
                          # icache_miss is no longer treated as an instruction
                          # but treated the same as stall_ifetch_wait
                          #"icache_miss",
                          "lr",
                          "lr_aq",
                          "swap_aq",
                          "swap_rl",
                          "beq",
                          "bne",
                          "blt",
                          "bge",
                          "bltu",
                          "bgeu",
                          "jalr",
                          "jal",
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
                          "mul",
                          "mulh",
                          "mulhsu",
                          "mulhu",
                          "div",
                          "divu",
                          "rem",
                          "remu",
                          "fence" }


    # List of types of floating point instructions executed by the core
    self.fp_instr_list = {"fadd",
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
                          "feq",
                          "flt",
                          "fle",
                          "fcvt_w_s",
                          "fcvt_wu_s",
                          "fclass",
                          "fmv_x_w" }

    # List of unknown operation by the core 
    self.unknown_list  = ["unknown"]


    # Coloring scheme for different types of operations
    # For detailed mode 
    # i_cache miss is treated the same is stall_ifetch_wait
    self.detailed_stall_bubble_color = { "stall_depend"                   : (0xff, 0xff, 0xff), ## white
                                         "stall_depend_local_load"        : (0x00, 0x66, 0x00), ## dark green
                                         "stall_depend_remote_load"       : (0x00, 0xff, 0x00), ## green
                                         "stall_depend_local_remote_load" : (0x00, 0xcc, 0xcc), ## dark cyan
                                         "stall_fp_local_load"            : (0x66, 0x00, 0x66), ## dark puprle
                                         "stall_fp_remote_load"           : (0xcc, 0x00, 0xcc), ## purple
                                         "stall_force_wb"                 : (0xff, 0x66, 0xff), ## pink
                                         "icache_miss"                    : (0x00, 0x00, 0xff), ## blue
                                         "stall_ifetch_wait"              : (0x00, 0x00, 0xff), ## blue
                                         "stall_icache_store"             : (0xcc, 0x80, 0x00), ## dark orange
                                         "stall_lr_aq"                    : (0x40, 0x40, 0x40), ## dark gray
                                         "stall_md"                       : (0xff, 0xa5, 0x00), ## light orange
                                         "stall_remote_req"               : (0xff, 0xff, 0x00), ## yellow
                                         "stall_local_flw"                : (0x99, 0xff, 0xff), ## light cyan
                                         "bubble"                         : (0x00, 0x99, 0x99)  ## dark cyan
                                       }
    self.detailed_unified_instr_color    =                                  (0xff, 0x00, 0x00)  ## red
    self.detailed_unified_fp_instr_color =                                  (0xff, 0x80, 0x00)  ## orange
    self.detailed_unknown_color  =                                          (0xff, 0xd7, 0x00)  ## gold



    # Coloring scheme for different types of operations
    # For abstract mode 
    # i_cache miss is treated the same is stall_ifetch_wait
    self.abstract_stall_bubble_color = { "stall_depend"                   : (0xff, 0xff, 0xff), ## white 
                                         "stall_depend_local_load"        : (0xff, 0xff, 0xff), ## white
                                         "stall_depend_remote_load"       : (0x00, 0xff, 0x00), ## green
                                         "stall_depend_local_remote_load" : (0x00, 0xff, 0x00), ## green
                                         "stall_fp_local_load"            : (0xff, 0xff, 0xff), ## white
                                         "stall_fp_remote_load"           : (0x00, 0xff, 0x00), ## green
                                         "stall_force_wb"                 : (0xff, 0xff, 0xff), ## white
                                         "icache_miss"                    : (0x00, 0x00, 0xff), ## blue
                                         "stall_ifetch_wait"              : (0x00, 0x00, 0xff), ## blue
                                         "stall_icache_store"             : (0xff, 0xff, 0xff), ## white
                                         "stall_lr_aq"                    : (0x40, 0x40, 0x40), ## dark gray
                                         "stall_md"                       : (0xff, 0x00, 0x00), ## red
                                         "stall_remote_req"               : (0xff, 0xff, 0x00), ## yellow
                                         "stall_local_flw"                : (0xff, 0xff, 0xff), ## white
                                         "bubble"                         : (0xff, 0xff, 0xff)  ## white
                                       }
    self.abstract_unified_instr_color    =                                  (0xff, 0x00, 0x00)  ## red
    self.abstract_unified_fp_instr_color =                                  (0xff, 0x00, 0x00)  ## red
    self.abstract_unknown_color  =                                          (0xff, 0x00, 0x00)  ## red



    # Determine coloring rules based on mode {abstract / detailed}
    if (self.abstract):
      self.stall_bubble_color     = self.abstract_stall_bubble_color
      self.unified_instr_color    = self.abstract_unified_instr_color
      self.unified_fp_instr_color = self.abstract_unified_instr_color
      self.unknown_color          = self.abstract_unknown_color
    else:
      self.stall_bubble_color     = self.detailed_stall_bubble_color
      self.unified_instr_color    = self.detailed_unified_instr_color
      self.unified_fp_instr_color = self.detailed_unified_instr_color
      self.unknown_color          = self.detailed_unknown_color

    return

  
  # main public method
  def generate(self, input_file):
    # parse vanilla_operation_trace.log
    traces = []
    with open(input_file) as f:
      csv_reader = csv.DictReader(f, delimiter=",")
      for row in csv_reader:
        trace = {}
        trace["x"] = int(row["x"])  
        trace["y"] = int(row["y"])  
        trace["operation"] = row["operation"]
        trace["timestamp"] = int(row["timestamp"])
        traces.append(trace)
  
    # get tile-group dim
    self.get_tg_dim(traces)

    # init image
    self.init_image()

    # create image
    for trace in traces:
      self.mark_trace(trace)

    #self.img.show()
    self.img.save("blood.bmp")
    return

  # public method to generate key for bloodgraph
  # called if --generate-key argument is true
  def generate_key(self, key_image_fname = "key"):
    img  = Image.new("RGB", (self.KEY_WIDTH, self.KEY_HEIGHT), "black")
    draw = ImageDraw.Draw(img)
    font = ImageFont.load_default()
    # the current row position of our key
    yt = 0
    # for each color in stalls...
    for (operation,color) in chain(self.stall_bubble_color.iteritems(),
                             [("unified_instr"    ,self.unified_instr_color),
                              ("unified_fp_instr" ,self.unified_fp_instr_color),
                              ("unknown"          ,self.unknown_color)]):
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
    img.save("{}.bmp".format(key_image_fname))
    return

  # private method
  # look through the input file to get the tile group dimension (x,y)
  def get_tg_dim(self, traces):
    xs = list(map(lambda t: t["x"], traces))
    ys = list(map(lambda t: t["y"], traces))
    self.xmin = min(xs)
    self.xmax = max(xs)
    self.ymin = min(ys)
    self.ymax = max(ys)
    
    self.xdim = self.xmax-self.xmin+1
    self.ydim = self.ymax-self.ymin+1
    return


  # private method
  # initialize image
  def init_image(self):
    self.img_width = 1024   # default
    self.img_height = ((((self.end_time-self.start_time)//self.timestep)+self.img_width)//self.img_width)*(2+(self.xdim*self.ydim))
    self.img = Image.new("RGB", (self.img_width, self.img_height), "black")
    self.pixel = self.img.load()
    return  
  
  # private method
  # mark the trace on output image
  def mark_trace(self, trace):

    # ignore trace outside the time range
    if trace["timestamp"] < self.start_time or trace["timestamp"] >= self.end_time:
      return

    # determine pixel location
    cycle = (trace["timestamp"]-self.start_time)//self.timestep
    col = cycle % self.img_width
    floor = cycle // self.img_width
    tg_x = trace["x"] - self.xmin 
    tg_y = trace["y"] - self.ymin
    row = floor*(2+(self.xdim*self.ydim)) + (tg_x+(tg_y*self.xdim))


    # determine color
    if trace["operation"] in self.stall_bubble_color.keys():
      self.pixel[col,row] = self.stall_bubble_color[trace["operation"]]
    elif trace["operation"] in self.instr_list:
      self.pixel[col,row] = self.unified_instr_color
    elif trace["operation"] in self.fp_instr_list:
      self.pixel[col,row] = self.unified_fp_instr_color
    elif trace["operation"] in self.unknown_list:
      self.pixel[col,row] = self.unknown_color
    else:
      print ("Error: invalid operaiton in operation log: " + trace["operation"])
      sys.exit()
    return


class TimeAction(argparse.Action):
  def __call__(self, parser, namespace, time, option_string=None):
    start_str,end_str = time.split("@")

    # Check if start time is given as input
    if(not start_str):
      start_time = DEFAULT_START_TIME
    else:
      start_time = int(start_str)

    # Check if end time is given as input
    if(not end_str):
      end_time = DEFAULT_END_TIME
    else:
      end_time = int(end_str)

    # check if start time is before end time
    if(start_time > end_time):
      raise ValueError("start time {} cannot be larger than end time {}.".format(start_time, end_time))

    setattr(namespace, "start", start_time)
    setattr(namespace, "end", end_time)
 

def parse_args():  
  parser = argparse.ArgumentParser(description="Argument parser for blood_graph.py")
  parser.add_argument("--input", default=DEFAULT_INPUT_FILE, type=str,
                      help="Vanilla operation log file")
  parser.add_argument("--time", nargs='?', required=1, action=TimeAction, 
                      const = (str(DEFAULT_START_TIME)+"@"+str(DEFAULT_END_TIME)),
                      help="Time window of bloodgraph as start_time@end_time in picoseconds")
  parser.add_argument("--abstract", default=False, action='store_true',
                      help="Type of bloodgraph - abstract / detailed")
  parser.add_argument("--timestamp", default=DEFAULT_TIMESTAMP, type=int,
                      help="Distance between each trace (clock period) in picoseconds")
  parser.add_argument("--generate-key", default=False, action='store_true',
                      help="Generate a key image")
  parser.add_argument("--no-blood-graph", default=False, action='store_true',
                      help="Skip blood graph generation")

  args = parser.parse_args()
  return args


# main()
if __name__ == "__main__":
  args = parse_args()
  
  bg = BloodGraph(args.start, args.end, args.timestamp, args.abstract)
  if not args.no_blood_graph:
    bg.generate(args.input)
  if args.generate_key:
    bg.generate_key()


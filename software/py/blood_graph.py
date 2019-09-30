#
#   blood_graph.py
#
#   vanilla_core execution visualizer.
# 
#   input: vanilla.log
#   output: bitmap file (blood.bmp)
#
#   @author tommy
#
#   How to use:
#   python blood_graph.py {start_time} {end_time} {timestep} {vanilla.log}
#
#   ex) python blood_graph.py 6000000 15000000 20 vanilla.log
#
#   {start_time}  start_time in picosecond
#   {end_time}    end_time in picosecond
#   {timestep}    time step in picosecond
# 
#   Color Code:  
#   int_executed  = ffffff (white)
#   fp_executed   = 006400 (green)
#   bubble        = ff1493 (pink)
#   ifetch        = ff0000 (red)
#   lr_aq         = ffbf7f (orange)
#   istore        = ffff00 (yellow)
#   fence         = a52a2a (brown)
#   muldiv        = 800080 (purple)
#   loadwb        = dc143c (crimson)
#   memreq        = 2f4f4f (grey)
#   flw           = 8b0000 (dark red)
#


import sys
from PIL import Image
from vanilla_trace_parser import *


class BloodGraph:

  # default constructor
  def __init__(self, start_time, end_time, timestep):

    self.start_time = start_time
    self.end_time = end_time
    self.timestep = timestep

    self.parser = VanillaTraceParser()

  
  # main public method
  def generate(self, input_file):
    # parse vanilla.log
    traces = self.parser.parse(input_file)

    # get tile-group dim
    self.get_tg_dim(traces)

    # init image
    self.init_image()

    # create image
    for trace in traces:
      self.mark_trace(trace)

    #self.img.show()
    self.img.save("blood.bmp")


  # private function
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


  # private function
  # initialize image
  def init_image(self):
    self.img_width = 1024   # default
    self.img_height = ((((end_time-start_time)//timestep)+self.img_width)//self.img_width)*(2+(self.xdim*self.ydim))
    self.img = Image.new("RGB", (self.img_width, self.img_height), "black")
    self.pixel = self.img.load()
  
  
  # private function
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
    if "stall_reason" in trace:
      if trace["stall_reason"] == "IFETCH":
        self.pixel[col,row] = (0xff, 0x00, 0x00)
      elif trace["stall_reason"] == "ISTORE":
        self.pixel[col,row] = (0xff, 0xff, 0x00)
      elif trace["stall_reason"] == "LR_AQ":
        self.pixel[col,row] = (0xff, 0xbf, 0x7f)
      elif trace["stall_reason"] == "FENCE":
        self.pixel[col,row] = (0xa5, 0x2a, 0x2a)
      elif trace["stall_reason"] == "MULDIV":
        self.pixel[col,row] = (0x80, 0x00, 0x80)
      elif trace["stall_reason"] == "LOADWB":
        self.pixel[col,row] = (0xdc, 0x14, 0x3c)
      elif trace["stall_reason"] == "MEMREQ":
        self.pixel[col,row] = (0x2f, 0x4f, 0x4f)
      elif trace["stall_reason"] == "FLW":
        self.pixel[col,row] = (0x8b, 0x00, 0x00)
    elif "int_pc" in trace:
      self.pixel[col,row] = (0xff, 0xff, 0xff)
    elif "fp_pc" in trace:
      self.pixel[col,row] = (0x00, 0x64, 0x00)
    else:
      self.pixel[col,row] = (0xff, 0x14, 0x93)
   

# main()
if __name__ == "__main__":

  if len(sys.argv) != 5:
    print("wrong number of arguments.")
    print("python {start_time} {end_time} {timestep} vanilla.log")
    sys.exit()
 
  start_time = int(sys.argv[1])
  end_time = int(sys.argv[2])
  timestep = int(sys.argv[3])
  input_file = sys.argv[4]


  bg = BloodGraph(start_time,end_time,timestep)
  bg.generate(input_file)

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
#   python blood_graph.py {x_min}-{x_max} {y_min}-{y_max} {start_time} {end_time} {timestep} {vanilla.log}
#
#   ex) python blood_graph.py 0-1 1-2 6000000 15000000 20 vanilla.log
#
#   {x_min/max}   x-cord range
#   {y_min/max}   y-cord range
#   {start_time}  start_time in picosecond
#   {end_time}    end_time in picosecond
#   {timestep}    time step in picosecond
#   


import sys
from PIL import Image
from vanilla_trace_parser import *


class BloodGraph:

  # default constructor
  def __init__(self, xmin, xmax, ymin, ymax, start_time, end_time, timestep):

    if xmin > xmax:
      sys.exit("xmin cannot be greater than xmax.")
    if ymin > ymax:
      sys.exit("ymin cannot be greater than ymax.")
  
    self.xmin = xmin
    self.xmax = xmax
    self.ymin = ymin
    self.ymax = ymax
    
    self.xdim = xmax-xmin+1
    self.ydim = ymax-ymin+1

    self.start_time = start_time
    self.end_time = end_time
    self.timestep = timestep

    self.img_width = 1024   # default
    self.img_height = ((((end_time-start_time)//timestep)+self.img_width)//self.img_width)*(2+(self.xdim*self.ydim))
    self.img = Image.new("RGB", (self.img_width, self.img_height), "black")
    self.pixel = self.img.load()

    self.parser = VanillaTraceParser()

  
  # main public method
  def generate(self, input_file):
    # parse vanilla.log
    traces = self.parser.parse(input_file)

    # create image
    for trace in traces:
      self.mark_trace(trace)

    #self.img.show()
    self.img.save("blood.bmp")
      
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
    # executed  = ffffff (white)
    # bubble    = ff1493 (pink)
    # ifetch    = ff0000 (red)
    # lr_aq     = ff4500 (orange)
    # istore    = ffff00 (yellow)
    # fence     = a52a2a (brown)
    # muldiv    = 800080 (purple)
    # loadwb    = dc143c (crimson)
    # memreq    = 2f4f4f (grey)
    # flw       = 8b0000 (dark red)
    if "int_pc" not in trace:
      self.pixel[col,row] = (0xff, 0x14, 0x93)
    else:
      if "stall_reason" not in trace:
        self.pixel[col,row] = (0xff, 0xff, 0xff)
      else:
        if trace["stall_reason"] == "IFETCH":
          self.pixel[col,row] = (0xff, 0x00, 0x00)
        elif trace["stall_reason"] == "ISTORE":
          self.pixel[col,row] = (0xff, 0xff, 0x00)
        elif trace["stall_reason"] == "LR_AQ":
          self.pixel[col,row] = (0xff, 0x45, 0x00)
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


# main()
if __name__ == "__main__":

  if len(sys.argv) != 7:
    print("wrong argument.")
    sys.exit()
 
  x_range = sys.argv[1]
  y_range = sys.argv[2]
  start_time = int(sys.argv[3])
  end_time = int(sys.argv[4])
  timestep = int(sys.argv[5])
  input_file = sys.argv[6]

  xcord = x_range.split("-")
  ycord = y_range.split("-")
  
  xmin = int(xcord[0])
  xmax = int(xcord[1])
  ymin = int(ycord[0])
  ymax = int(ycord[1])

  bg = BloodGraph(xmin,xmax,ymin,ymax,start_time,end_time,timestep)
  bg.generate(input_file)

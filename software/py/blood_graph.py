#
#   blood_graph.py
#
#   vanilla_core execution visualizer.
# 
#   input: vanilla_operation_trace.log
#   output: bitmap file (blood.bmp)
#
#   @author tommy
#
#   How to use:
#   python blood_graph.py {start_time} {end_time} {timestep} {vanilla_operation_trace.log}
#
#   ex) python blood_graph.py 6000000 15000000 20 vanilla_operation_trace.log
#
#   {start_time}  start_time in picosecond
#   {end_time}    end_time in picosecond
#   {timestep}    time step in picosecond
# 


import sys
import csv
from PIL import Image



# List of types of stalls incurred by the core 
stall_list    = ["stall_depend", "stall_depend_local_load", \
                 "stall_depend_remote_load", "stall_depend_local_remote_load", \
                 "stall_fp_local_load", "stall_fp_remote_load", "stall_force_wb", \
                 "stall_ifetch_wait", "stall_icache_store", "stall_lr_aq", \
                 "stall_md", "stall_remote_req", "stall_local_flw" ]


# List of types of integer instructions executed by the core 
instr_list    = ["local_ld", "local_st", "remote_ld", "remote_st", \
                 "local_flw", "local_fsw", "remote_flw", "remote_fsw", \
                 "icache_miss", \
                 "lr", "lr_aq", "swap_aq", "swap_rl", \
                 "beq", "bne", "blt", "bge", \
                 "bltu", "bgeu", "jalr", "jal" \
                 "beq_miss", "bne_miss", "blt_miss", "bge_miss" \
                 "bltu_miss", "bgeu_miss", "jalr_miss",
                 "sll", "slli", "srl", "srli", "sra", "srai", \
                 "add", "addi", "sub", "lui", "auipc", "xor", "xori", \
                 "or", "ori", "and", "adni", "slt", "slti", "sltu", "sltiu", \
                 "mul", "mulh", "mulhsu", "mulhu", \
                 "div", "divu", "rem", "remu", \
                 "fence"]


# List of types of floating point instructions executed by the core
fp_instr_list = ["fadd", "fsub", "fmul", "fsgnj", "fsgnjn", "fsgnjx", \
                 "fmin", "fmax", "fcvt_s_w", "fcvt_s_wu", "fmv_w_x", \
                 "feq", "flt", "fle", "fcvt_w_s", "fcvt_wu_s", \
                 "fclass", "fmv_x_w" ]


operation_color = [] 



class BloodGraph:

  # default constructor
  def __init__(self, start_time, end_time, timestep):

    self.start_time = start_time
    self.end_time = end_time
    self.timestep = timestep

  
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
    if trace["operation"] == "stall_depend":
      self.pixel[col,row] = (0xdc, 0x14, 0x3c) # crimson
    elif trace["operation"] == "stall_depend_local_load":
      self.pixel[col,row] = (0xff, 0x45, 0x00) # orange
    elif trace["operation"] == "stall_depend_remote_load":
      self.pixel[col,row] = (0xff, 0x00, 0x00) # red
    elif trace["operation"] == "stall_depend_local_remote_load":
      self.pixel[col,row] = (0x80, 0x00, 0x00) # maroon
    elif trace["operation"] == "stall_fp_remote_load":
      self.pixel[col,row] = (0x00, 0x80, 0x00) # green
    elif trace["operation"] == "stall_fp_local_load":
      self.pixel[col,row] = (0x00, 0x64, 0x00) # darkgreen
    elif trace["operation"] == "stall_force_wb":
      self.pixel[col,row] = (0x20, 0xb2, 0xaa) # lightseagreen
    elif trace["operation"] == "stall_ifetch_wait":
      self.pixel[col,row] = (0x00, 0x00, 0xff) # blue
    elif trace["operation"] == "stall_icache_store":
      self.pixel[col,row] = (0x00, 0x00, 0xff) # grey
    elif trace["operation"] == "stall_lr_aq":
      self.pixel[col,row] = (0xff, 0xd7, 0x00) # gold
    elif trace["operation"] == "stall_md":
      self.pixel[col,row] = (0x80, 0x00, 0x80) # purple
    elif trace["operation"] == "stall_remote_req":
      self.pixel[col,row] = (0x00, 0xff, 0xff) # cyan
    elif trace["operation"] == "stall_local_flw":
      self.pixel[col,row] = (0x00, 0xff, 0x00) # lime
#    elif trace["operation"] == "no_stall":
    else:
      self.pixel[col,row] = (0xff, 0xff, 0xff) # white
      

# main()
if __name__ == "__main__":

  if len(sys.argv) != 5:
    print("Error: wrong number of arguments.")
    print("python3 bloodgraph.py {start_time} {end_time} {timestep} vanilla_operation_trace.log")
    sys.exit()
 
  start_time = int(sys.argv[1])
  end_time = int(sys.argv[2])
  timestep = int(sys.argv[3])
  input_file = sys.argv[4]

  if (start_time > end_time):
    print("Error: start_time cannot be larger than end_time.")
    print("python3 bloodgraph.py {start_time} {end_time} {timestep} vanilla_operation_trace.log")
    sys.exit()

  bg = BloodGraph(start_time,end_time,timestep)
  bg.generate(input_file)

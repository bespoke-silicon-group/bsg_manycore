#
#   nbf.py
#
#   Network Boot Format (.nbf)
#
#   USAGE:
#
#   python nbf_converter.py {dmem_file.mem} {dram_file.mem} 
#   tgo_x, tgo_y, tg_dim_x, tg_dim_y, enable_dram
#
#   
#   This script produces a file where the format of each line is:
#   
#   {x_coord}_{y_coord}_{epa}_{data}
#


import sys
import math


#
#   NBF
#

################################
# EPA Constants
DMEM_BASE_EPA = 0x400

ICACHE_BASE_EPA = 0x400000

CSR_BASE = 0x8000
CSR_FREEZE = 0 | CSR_BASE
CSR_TGO_X = 1 | CSR_BASE
CSR_TGO_Y = 2 | CSR_BASE
CSR_PC_INIT = 3 | CSR_BASE
CSR_ENABLE_DRAM = 4 | CSR_BASE
################################



class NBF:

  # constructor
  def __init__(self, config):
    self.config = config
    self.read_dmem()
    self.read_dram()
   
  ##### UTIL FUNCTIONS #####
 
  # take width and val and convert to binary string
  def get_binstr(self, val, width):
    return format(val, "0"+str(width)+"b")

  def get_hexstr(self, val, width):
    return format(val, "0"+str(width)+"x")


  # take x,y coord, epa, data and turn it into nbf format.
  def print_nbf(self, x, y, epa, data):
    line =  self.get_hexstr(x, 2) + "_"
    line += self.get_hexstr(y, 2) + "_"
    line += self.get_hexstr(epa, 8) + "_"
    line += self.get_hexstr(data, 8)
    print(line)

  # read objcopy dumped in 'verilog' format.
  # return in EPA (word addr) and 32-bit value dictionary
  def read_objcopy(self, filename):
    addr_val = {}

    f = open(filename, "r")
    lines = f.readlines()
  
    curr_addr = 0

    for line in lines:
      stripped = line.strip()
      if stripped:
        if stripped.startswith("@"):
          curr_addr = int(stripped.strip("@"), 16) / 4
        else:
          words = stripped.split()
          for i in range(len(words)/4):
            assembled_hex = words[4*i+3] + words[4*i+2] + words[4*i+1] + words[4*i+0]
            addr_val[curr_addr] = int(assembled_hex, 16)
            curr_addr += 1

    return addr_val

  def safe_clog2(self, x):
    if x == 1:
      return 1
    else:
      return int(math.log(x,2))        


  # read dmem
  def read_dmem(self):
    self.dmem_data = self.read_objcopy(self.config["dmem_file"])

  # read dram
  def read_dram(self):
    self.dram_data = self.read_objcopy(self.config["dram_file"])


  ##### END UTIL FUNCTIONS #####

  ##### LOADER ROUTINES #####  

  # set TGO x,y
  def config_tile_group(self):
    for x in range(self.config["tg_dim_x"]):
      for y in range(self.config["tg_dim_y"]):
        x_eff = self.config["tgo_x"] + x
        y_eff = self.config["tgo_y"] + y
        self.print_nbf(x_eff, y_eff, CSR_TGO_X, self.config["tgo_x"])
        self.print_nbf(x_eff, y_eff, CSR_TGO_Y, self.config["tgo_y"])
 
  # initialize icache
  def init_icache(self):
    for x in range(self.config["tg_dim_x"]):
      for y in range(self.config["tg_dim_y"]):
        x_eff = self.config["tgo_x"] + x
        y_eff = self.config["tgo_y"] + y
        for k in sorted(self.dram_data.keys()):
          if k < self.config["icache_entries"]:
            icache_epa = ICACHE_BASE_EPA | k
            self.print_nbf(x_eff, y_eff, icache_epa, self.dram_data[k])
        
 
  # initialize dmem
  def init_dmem(self):
    for x in range(self.config["tg_dim_x"]):
      for y in range(self.config["tg_dim_y"]):

        x_eff = self.config["tgo_x"] + x
        y_eff = self.config["tgo_y"] + y
        max_key = max(self.dmem_data.keys())
        min_key = min(self.dmem_data.keys())
        for k in range(1024):
          dmem_epa = k + 1024
          if dmem_epa in self.dmem_data.keys():
            self.print_nbf(x_eff, y_eff, dmem_epa, self.dmem_data[dmem_epa])
          else:
            self.print_nbf(x_eff, y_eff, dmem_epa, 0)
 
  # disable dram mode
  def disable_dram(self):
    for x in range(self.config["tg_dim_x"]):
      for y in range(self.config["tg_dim_y"]):
        x_eff = self.config["tgo_x"] + x
        y_eff = self.config["tgo_y"] + y
        self.print_nbf(x_eff, y_eff, CSR_ENABLE_DRAM, 0)
    
  # initialize vcache in no DRAM mode
  def init_vcache(self):

    y = config["num_tiles_y"]
    t_shift = self.safe_clog2(self.config["cache_block_size"])

    for x in range(self.config["num_tiles_x"]):
      for t in range(self.config["cache_way"] * self.config["cache_set"]):
        epa = (t << t_shift) | (1 << (self.config["addr_width"]-1))
        data = (1 << (self.config["data_width"]-1)) | (t / self.config["cache_set"])
        self.print_nbf(x, y, epa, data)
         
 
  # init DRAM
  def init_dram(self, enable_dram): 
    y = self.config["num_tiles_y"]
    dram_ch_size = self.config["dram_ch_size"]
    cache_size = self.config["cache_size"]

    if enable_dram == 1:
      for k in sorted(self.dram_data.keys()):
        x = k / dram_ch_size
        epa = k % dram_ch_size
        self.print_nbf(x, y, epa, self.dram_data[k])
    else:
      for k in sorted(self.dram_data.keys()):
        x = k / cache_size
        epa = k % cache_size
        if (x < self.config["num_tiles_x"]):
          self.print_nbf(x, y, epa, self.dram_data[k])
        else:
          print("# WARNING: NO DRAM MODE, DRAM DATA OUT OF RANGE!!!")

      

  # unfreeze tiles
  def unfreeze_tiles(self):
    tgo_x = self.config["tgo_x"]
    tgo_y = self.config["tgo_y"]

    for y in range(self.config["tg_dim_y"]):
      for x in range(self.config["tg_dim_x"]):
        x_eff = tgo_x + x
        y_eff = tgo_y + y
        self.print_nbf(x_eff, y_eff, CSR_FREEZE, 0)


  def print_finish(self):
    self.print_nbf(0xff, 0xff, 0xffffffff, 0xffffffff)


  ##### LOADER ROUTINES END  #####  

  # users only have to call this function.
  def dump(self):
    self.config_tile_group()
    self.init_icache()
    self.init_dmem()

    enable_dram = self.config["enable_dram"]
    if enable_dram != 1:
      self.disable_dram()    
      self.init_vcache()

    self.init_dram(enable_dram)
    self.unfreeze_tiles()

    self.print_finish()

#
#   main()
#
if __name__ == "__main__":

  if len(sys.argv) == 10:

    # config setting
    config = {
      "dmem_file" : sys.argv[1],
      "dram_file" : sys.argv[2],
      "num_tiles_x" : int(sys.argv[3]),
      "num_tiles_y" : int(sys.argv[4]),
      "tgo_x" : int(sys.argv[5]),
      "tgo_y" : int(sys.argv[6]),
      "tg_dim_x" : int(sys.argv[7]),
      "tg_dim_y" : int(sys.argv[8]),
      "enable_dram" : int(sys.argv[9]),
    }

    config["dram_size"] = 2**29 # in words (2GB)
    config["data_width"] = 32
    config["cache_way"] = 2
    config["cache_set"] = 256
    config["cache_block_size"] = 8
    config["icache_entries"] = 1024 # in words

    config["cache_size"] = config["cache_way"]*config["cache_set"]*config["cache_block_size"]
    config["x_cord_width"] = int(math.log(config["num_tiles_x"], 2))
    config["dram_ch_size"] = config["dram_size"] / (2**config["x_cord_width"]) # in words (512MB)
    config["addr_width"] = int(math.log(config["dram_ch_size"],2))+1
    #print(config)
    converter = NBF(config)
    converter.dump()

  else:
    print("USAGE:")
    command = "python nbf.py {dmem_file.mem} {dram_file.mem} "
    command += "{num_tiles_x} {num_tiles_y} "
    command += "{tgo_x} {tgo_y} {tg_dim_x} {tg_dim_y} {enable_dram}"
    print(command)


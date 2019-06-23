#
#   nbf_converter.py
#
#   Network Boot Format (.nbf) converter
#
#   USAGE:
#
#   python nbf_converter.py {config_file.json} {dmem_file.mem} {dram_file.mem}
#
#   
#   This script produces a file where the format of each line is:
#   
#   {x_coord}_{y_coord}_{epa}_{data}
#


import sys
import json
import math


#
#   NBFConverter
#

DMEM_BASE_EPA = 0x400
ICACHE_BASE_EPA = 0x400000
CSR_BASE = 0x8000
CSR_FREEZE = 0 | CSR_BASE
CSR_TGO_X = 1 | CSR_BASE
CSR_TGO_Y = 2 | CSR_BASE
CSR_PC_INIT = 3 | CSR_BASE
CSR_ENABLE_DRAM = 4 | CSR_BASE

class NBFConverter:

  # constructor
  def __init__(self, config_file, dmem_file, dram_file):
    self.config_file = config_file
    self.dmem_file = dmem_file
    self.dram_file = dram_file
    self.read_config()
    self.read_dmem()
    self.read_dram()
   
  ##### UTIL FUNCTIONS #####
 
  # read config json
  def read_config(self):
    with open(self.config_file) as f:
      self.config = json.load(f)


  # take width and val and convert to binary string
  def get_binstr(self, val, width):
    return format(val, "0"+str(width)+"b")

  def get_hexstr(self, val, width):
    return format(val, "0"+str(width)+"x")


  # take x,y coord, epa, data and turn it into nbf format.
  def print_nbf(self, x, y, epa, data):
    line =  self.get_hexstr(x, 2) + " "
    line += self.get_hexstr(y, 2) + " "
    line += self.get_hexstr(epa, 8) + " "
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
        


  # read dmem
  def read_dmem(self):
    self.dmem_data = self.read_objcopy(self.dmem_file)


  # read dram
  def read_dram(self):
    self.dram_data = self.read_objcopy(self.dram_file)


  ##### END UTIL FUNCTIONS #####

  ##### LOADER ROUTINES #####  

  # set TGO x,y
  def config_tile_group(self):
    print("# config tile group...")
    x_org = self.config["bsg_tiles_org_X"]
    y_org = self.config["bsg_tiles_org_Y"]

    for x in range(self.config["bsg_tiles_X"]):
      for y in range(self.config["bsg_tiles_Y"]):
        x_eff = x_org + x
        y_eff = y_org + y
        self.print_nbf(x_eff, y_eff, CSR_TGO_X, x_org)
        self.print_nbf(x_eff, y_eff, CSR_TGO_Y, y_org)
 
  # initialize icache
  def init_icache(self):
    print("# init icache...")
    x_org = self.config["bsg_tiles_org_X"]
    y_org = self.config["bsg_tiles_org_Y"]

    for x in range(self.config["bsg_tiles_X"]):
      for y in range(self.config["bsg_tiles_Y"]):
        x_eff = x_org + x
        y_eff = y_org + y
        for k in self.dram_data.keys():
          if k < self.config["icache_entries_p"]:
            icache_epa = ICACHE_BASE_EPA | k
            self.print_nbf(x_eff, y_eff, icache_epa, self.dram_data[k])
        
 
  # initialize dmem
  def init_dmem(self):
    print("# init dmem...")
    x_org = self.config["bsg_tiles_org_X"]
    y_org = self.config["bsg_tiles_org_Y"]

    for x in range(self.config["bsg_tiles_X"]):
      for y in range(self.config["bsg_tiles_Y"]):
        x_eff = x_org + x
        y_eff = y_org + y
        for k in self.dmem_data.keys():
          dmem_epa = DMEM_BASE_EPA | k
          self.print_nbf(x_eff, y_eff, dmem_epa, self.dmem_data[k])
 
  # disable dram mode
  def disable_dram(self):
    print("# disable dram...")
    x_org = self.config["bsg_tiles_org_X"]
    y_org = self.config["bsg_tiles_org_Y"]

    for x in range(self.config["bsg_tiles_X"]):
      for y in range(self.config["bsg_tiles_Y"]):
        x_eff = x_org + x
        y_eff = y_org + y
        self.print_nbf(x_eff, y_eff, CSR_ENABLE_DRAM, 0)
    
  # initialize vcache in no DRAM mode
  def init_vcache(self):
    y = self.config["bsg_global_Y"]
    ways = self.config["vcache_ways"]
    sets = self.config["vcache_sets"]
    block_size = self.config["vcache_block_size"]
    t_shift = int(math.log(block_size, 2))

    for x in range(self.config["bsg_global_X"]):
      for t in range(ways*sets):
        epa = ((t << t_shift) | (1 << (self.config["addr_width_p"]-1))
        data = (1 << (self.config["data_width_p"]-1)) | w
        self.print_nbf(x, y, epa, data)
         
 
  # init DRAM
  def init_dram(self, enable_dram): 
    y = self.config["bsg_global_Y"]
    dram_bank_size = (2 ** self.config["dram_ch_addr_width_p"])
    vcache_size = self.config["vcache_ways"] * self.config["vcache_sets"] * self.config["vcache_block_size"]

    if enable_dram == 1:
      print("# initializing DRAM with DRAM mode...")
      for k in self.dram_data.keys():
        x = k / dram_bank_size
        epa = k % dram_bank_size
        self.print_nbf(x, y, epa, self.dram_data[k])
    else:
      print("# initializing DRAM without DRAM mode...")
      for k in self.dram_data.keys():
        x = k / vcache_size
        epa = k % vcache_size
        if (x < self.config["bsg_global_X"]):
          self.print_nbf(x, y, epa, self.dram_data[k])
        else:
          print("# WARNING: NO DRAM MODE, DRAM DATA OUT OF RANGE!!!")

      

  # unfreeze tiles
  def unfreeze_tiles(self):
    print("# unfreezing tiles...")
    x_org = self.config["bsg_tiles_org_X"]
    y_org = self.config["bsg_tiles_org_Y"]

    for x in range(self.config["bsg_tiles_X"]):
      for y in range(self.config["bsg_tiles_Y"]):
        x_eff = x_org + x
        y_eff = y_org + y
        self.print_nbf(x_eff, y_eff, CSR_FREEZE, 0)




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

#
#   main()
#
if __name__ == "__main__":
  if len(sys.argv) == 4:
    config_file = sys.argv[1]
    dmem_file = sys.argv[2]
    dram_file = sys.argv[3]
    converter = NBFConverter(config_file, dmem_file, dram_file)
    converter.dump()
  else:
    print("USAGE:")
    print("python nbf_converter.py {config_file.json} {dmem_file.mem} {dram_file.mem}")


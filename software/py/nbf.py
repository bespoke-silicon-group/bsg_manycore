#
#   nbf.py
#
#   ELF (.riscv) to Network Boot Format (.nbf)
#


import sys
import math
import os
import subprocess

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

    # fixed arch params
    self.icache_size = 1024
    self.data_width = 32

    # input binary
    self.riscv_file = config["riscv_file"]

    # machine setting
    self.num_tiles_x = config["num_tiles_x"]
    self.num_tiles_y = config["num_tiles_y"]
    self.cache_way = config["cache_way"]
    self.cache_set = config["cache_set"]
    self.cache_block_size = config["cache_block_size"]
    self.dram_size = config["dram_size"]
    self.addr_width = config["addr_width"]
  
    # software setting
    self.tgo_x = config["tgo_x"]
    self.tgo_y = config["tgo_y"]
    self.tg_dim_x = config["tg_dim_x"]
    self.tg_dim_y = config["tg_dim_y"]
    self.enable_dram = config["enable_dram"]

    # derived params
    self.cache_size = self.cache_way * self.cache_set * self.cache_block_size # in words
    self.x_cord_width = self.safe_clog2(self.num_tiles_x)

    # process riscv
    self.get_data_end_addr()
    self.read_dmem()
    self.read_dram()
   
  ##### UTIL FUNCTIONS #####

  # take width and val and convert to binary string
  def get_binstr(self, val, width):
    return format(val, "0"+str(width)+"b")

  # take width and val and convert to hex string
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
  def read_objcopy(self, section, output_file):

    # make sure that you have riscv tool binaries in
    # bsg_manycore/software/riscv-tools/riscv-install/bin
    dirname = os.path.abspath(os.path.dirname(__file__))
    objcopy_path = os.path.join(dirname, "../riscv-tools/riscv-install/bin/riscv32-unknown-elf-dramfs-objcopy")

    if not os.path.isfile(objcopy_path):
      print("install riscv-tools first...")
      sys.exit()

    cmd = [objcopy_path, "-O", "verilog", "-j", section, self.riscv_file, output_file]
    result = subprocess.call(cmd)
  
    addr_val = {}
    curr_addr = 0

    f = open(output_file, "r")
    lines = f.readlines()

    for line in lines:
      stripped = line.strip()
      if stripped:
        if stripped.startswith("@"):
          curr_addr = int(stripped.strip("@"), 16) / 4
        else:
          words = stripped.split()
          #for i in range(len(words)/4):
          #  assembled_hex = words[4*i+3] + words[4*i+2] + words[4*i+1] + words[4*i+0]
          #  addr_val[curr_addr] = int(assembled_hex, 16)
          #  curr_addr += 1
          count = 0
          assembled_hex = ""
          for i in range(len(words)):
            assembled_hex = words[i] + assembled_hex
            count += 1
            if count == 4:
              addr_val[curr_addr] = int(assembled_hex, 16)
              curr_addr += 1
              assembled_hex = ""
              count = 0

          if count != 0:
            for i in range(4-count):
              assembled_hex = "00" + assembled_hex
            addr_val[curr_addr] = int(assembled_hex, 16)

    return addr_val

  def safe_clog2(self, x):
    if x == 1:
      return 1
    else:
      return int(math.ceil(math.log(x,2)))


  # read dmem
  def read_dmem(self):
    self.dmem_data = self.read_objcopy("*.dmem", "main_dmem.mem")    

  # read dram
  def read_dram(self):
    self.dram_data = self.read_objcopy("*.dram", "main_dram.mem")    

  
  def get_data_end_addr(self):
    proc = subprocess.Popen(["nm", "--radix=d", self.riscv_file], stdout=subprocess.PIPE)
    lines = proc.stdout.readlines()
    for line in lines:
      stripped = line.strip()
      words = stripped.split()
      if words[2] == "_bsg_data_end_addr":
        self.bsg_data_end_addr = (int(words[0]) >> 2) # make it word address

  def select_bits(self, num, start, end):
    retval = 0

    for i in range(start, end+1):
      b = num & (1 << i)
      retval = retval | b

    return (retval >> start)

  ##### END UTIL FUNCTIONS #####

  ##### LOADER ROUTINES #####  


  # set TGO x,y
  def config_tile_group(self):
    for x in range(self.tg_dim_x):
      for y in range(self.tg_dim_y):
        x_eff = self.tgo_x + x
        y_eff = self.tgo_y + y
        self.print_nbf(x_eff, y_eff, CSR_TGO_X, self.tgo_x)
        self.print_nbf(x_eff, y_eff, CSR_TGO_Y, self.tgo_y)

 
  # initialize icache
  def init_icache(self):
    for x in range(self.tg_dim_x):
      for y in range(self.tg_dim_y):
        x_eff = self.tgo_x + x
        y_eff = self.tgo_y + y
        for k in sorted(self.dram_data.keys()):
          addr = k - 0x20000000
          if addr < self.icache_size:
            icache_epa = ICACHE_BASE_EPA | addr
            self.print_nbf(x_eff, y_eff, icache_epa, self.dram_data[k])
        
 
  # initialize dmem
  def init_dmem(self):
    # if there is nothing in dmem, just return.
    if len(self.dmem_data.keys()) == 0:
      return

    for x in range(self.tg_dim_x):
      for y in range(self.tg_dim_y):

        x_eff = self.tgo_x + x
        y_eff = self.tgo_y + y
          
        for k in range(1024, self.bsg_data_end_addr+1):
          if k in self.dmem_data.keys():
            self.print_nbf(x_eff, y_eff, k, self.dmem_data[k])
          else:
            self.print_nbf(x_eff, y_eff, k, 0)

 
  # disable dram mode
  def disable_dram(self):
    for x in range(self.tg_dim_x):
      for y in range(self.tg_dim_y):
        x_eff = self.tgo_x + x
        y_eff = self.tgo_y + y
        self.print_nbf(x_eff, y_eff, CSR_ENABLE_DRAM, 0)
   
 
  # initialize vcache in no DRAM mode
  def init_vcache(self):

    y = self.num_tiles_y
    t_shift = self.safe_clog2(self.cache_block_size)

    for x in range(self.num_tiles_x):
      for t in range(self.cache_way * self.cache_set):
        epa = (t << t_shift) | (1 << (self.addr_width-1))
        data = (1 << (self.data_width-1)) | (t / self.cache_set)
        self.print_nbf(x, y, epa, data)
         
 
  # init DRAM
  def init_dram(self, enable_dram): 
    #y = self.num_tiles_y
    cache_size = self.cache_size
    lg_x = self.safe_clog2(self.num_tiles_x)
    lg_block_size = self.safe_clog2(self.cache_block_size)
    lg_set = self.safe_clog2(self.cache_set)
    index_width = self.addr_width-1-lg_block_size-1

    if enable_dram == 1:
      #if self.num_tiles_x == 9:      
        # hashing for 9 banks (deprecated)
      #  for k in sorted(self.dram_data.keys()):
      #    addr = k - 0x20000000
      #    bit_2_0 = (addr >> lg_block_size) & 0b111
      #    bit_5_4 = (addr >> (3+lg_block_size)) & 0b110
      #    bit_3 = (addr >> (3+lg_block_size)) & 0b001
      #    bit_12 = (addr >> (3+lg_block_size+lg_set)) & 0b1

      #    if bit_2_0 == (bit_5_4 | (bit_3 ^ bit_12)):
      #      x = 8
      #    else:
      #      x = bit_2_0
    
      #    block_offset = self.select_bits(addr, 0, lg_block_size-1)
      #    index = self.select_bits(addr, lg_block_size+3, lg_block_size+3+index_width-1) << lg_block_size
      #    epa = block_offset | index
      #    self.print_nbf(x, y, epa, self.dram_data[k])

      if self.num_tiles_x & (self.num_tiles_x-1) == 0:
        # hashing for power of 2 banks
        for k in sorted(self.dram_data.keys()):
          addr = k - 0x20000000
          x = self.select_bits(addr, lg_block_size, lg_block_size + lg_x - 1)
          y = self.select_bits(addr, lg_block_size + lg_x, lg_block_size + lg_x)
          index = self.select_bits(addr, lg_block_size+lg_x+1, lg_block_size+lg_x+1+index_width-1)
          epa = self.select_bits(addr, 0, lg_block_size-1) | (index << lg_block_size)
          if y == 0:
            self.print_nbf(x, 0, epa, self.dram_data[k])
          else:
            self.print_nbf(x, self.num_tiles_y+1, epa, self.dram_data[k])
          
      else:
        print("hash function not supported for x={0}.")
        sys.exit()

    else:
      for k in sorted(self.dram_data.keys()):
        addr = k - 0x20000000
        x = addr / cache_size
        epa = addr % cache_size
        if (x < self.num_tiles_x):
          self.print_nbf(x, 0, epa, self.dram_data[k])
        elif (x < self.num_tiles_x*2):
          self.print_nbf(x, self.num_tiles_y+1, epa, self.dram_data[k])
        else:
          print("## WARNING: NO DRAM MODE, DRAM DATA OUT OF RANGE!!!")

      

  # unfreeze tiles
  def unfreeze_tiles(self):
    tgo_x = self.tgo_x
    tgo_y = self.tgo_y

    for y in range(self.tg_dim_y):
      for x in range(self.tg_dim_x):
        x_eff = tgo_x + x
        y_eff = tgo_y + y
        self.print_nbf(x_eff, y_eff, CSR_FREEZE, 0)

  # print finish
  # when spmd loader sees, this it stops sending packets.
  def print_finish(self):
    self.print_nbf(0xff, 0xff, 0xffffffff, 0xffffffff)

  # fence
  def fence(self):
    self.print_nbf(0xff, 0xff, 0x0, 0x0)


  ##### LOADER ROUTINES END  #####  

  # users only have to call this function.
  def dump(self):
    self.config_tile_group()
    self.init_icache()
    self.init_dmem()

    if self.enable_dram != 1:
      self.disable_dram()    
      self.init_vcache()

    self.init_dram(self.enable_dram)
    self.fence()
    self.unfreeze_tiles()

    self.print_finish()


#
#   main()
#
if __name__ == "__main__":

  if len(sys.argv) == 14:
    # config setting
    config = {
      "riscv_file" : sys.argv[1],
      "num_tiles_x" : int(sys.argv[2]),
      "num_tiles_y" : int(sys.argv[3]),
      "cache_way" : int(sys.argv[4]),
      "cache_set" : int(sys.argv[5]),
      "cache_block_size" : int(sys.argv[6]),
      "dram_size": int(sys.argv[7]),
      "addr_width": int(sys.argv[8]),

      "tgo_x" : int(sys.argv[9]),
      "tgo_y" : int(sys.argv[10]),
      "tg_dim_x" : int(sys.argv[11]),
      "tg_dim_y" : int(sys.argv[12]),
      "enable_dram" : int(sys.argv[13]),
    }

    converter = NBF(config)
    converter.dump()
  else:
    print("USAGE:")
    command = "python nbf.py {program.riscv} "
    command += "{num_tiles_x} {num_tiles_y} "
    command += "{cache_way} {cache_set} {cache_block_size} {dram_size} {max_epa_width}"
    command += "{tgo_x} {tgo_y} {tg_dim_x} {tg_dim_y} {enable_dram}"
    print(command)


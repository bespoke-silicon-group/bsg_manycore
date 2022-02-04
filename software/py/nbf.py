#
#   nbf.py
#
#   ELF (.riscv) to Network Boot Format (.nbf)
#
#   When there is a EVA to NPA mapping change in bsg_manycore_eva_to_npa.v,
#   this file should also be updated accordingly.
#
#   https://github.com/bespoke-silicon-group/bsg_manycore/blob/master/v/bsg_manycore_eva_to_npa.v
#
#

import sys
import math
import os
import subprocess


################################
# EPA Constants
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
    self.origin_x_cord = config["origin_x_cord"]
    self.origin_y_cord = config["origin_y_cord"]
    # physical number of pods
    self.machine_pods_x = config["machine_pods_x"]
    self.machine_pods_y = config["machine_pods_y"]
    # number of pods to launch program.
    self.num_pods_x = config["num_pods_x"]  
    self.num_pods_y = config["num_pods_y"]
    self.num_vcache_rows = config["num_vcache_rows"]

    # software setting
    self.tgo_x = config["tgo_x"]
    self.tgo_y = config["tgo_y"]
    self.tg_dim_x = config["tg_dim_x"]
    self.tg_dim_y = config["tg_dim_y"]
    self.enable_dram = config["enable_dram"]
    # if skip_dram_instruction_load == 1, skip loading instruction data to DRAM, if the binary fits in the icache.
    self.skip_dram_instruction_load = config["skip_dram_instruction_load"]


    # derived params
    self.cache_size = self.cache_way * self.cache_set * self.cache_block_size # in words
    self.x_cord_width = self.safe_clog2(self.num_tiles_x)

    # process riscv
    self.get_data_end_addr()
    self.get_start_addr()
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

    cmd = [objcopy_path, "-O", "verilog", "-j", section, "--set-section-flags", "*bss*=alloc,load,contents", self.riscv_file, output_file]
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

  # get the size of the spmd binary (text section) in unit of words.
  def get_spmd_binary_size(self):
    proc = subprocess.Popen(["nm", "--radix=d", self.riscv_file], stdout=subprocess.PIPE)
    lines = proc.stdout.readlines()
    for line in lines:
      stripped = line.strip()
      words = stripped.split()
      if words[2] == "__.text.dram_end":
        return (int(words[0])/4) -1
    

  # grab address for _start symbol.
  # code earlier than that contains interrupt handler.
  # we want to set the tile pc_init val to this address.
  # if _start is not found, which might be possible for some spmd assembly tests, just return 0
  def get_start_addr(self):
    proc = subprocess.Popen(["nm", "--radix=d", self.riscv_file], stdout=subprocess.PIPE)
    lines = proc.stdout.readlines()
    self.start_addr = 0
    for line in lines:
      stripped = line.strip()
      words = stripped.split()
      if words[2] == "_start":
        self.start_addr = (int(words[0]) >> 2) # make it word address
    

  def select_bits(self, num, start, end):
    retval = 0

    for i in range(start, end+1):
      b = num & (1 << i)
      retval = retval | b

    return (retval >> start)

  ##### END UTIL FUNCTIONS #####

  ##### LOADER ROUTINES #####  


  # set TGO x,y
  def config_tile_group(self, pod_origin_x, pod_origin_y):
    for x in range(self.tg_dim_x):
      for y in range(self.tg_dim_y):
        x_eff = self.tgo_x + x + pod_origin_x
        y_eff = self.tgo_y + y + pod_origin_y
        self.print_nbf(x_eff, y_eff, CSR_TGO_X, self.tgo_x)
        self.print_nbf(x_eff, y_eff, CSR_TGO_Y, self.tgo_y)


  # initialize vcache wh dest cord
  def init_vcache_wh_dest(self, pod_origin_x, pod_origin_y, px):
    # top two MSBs are 1.
    epa = 0b11 << (self.addr_width-2)

    # if there is only one pod in x-direction, split the pod in half.
    if self.machine_pods_x == 1:
      for r in range(self.num_vcache_rows):
        for x in range(self.num_tiles_x):
          east_not_west = 0 if x < (self.num_tiles_x/2) else 1
          # north vcache
          x_eff = pod_origin_x + x
          y_eff = pod_origin_y - 1 - r
          self.print_nbf(x_eff, y_eff, epa, east_not_west)
          # south vcache
          x_eff = pod_origin_x + x
          y_eff = pod_origin_y + self.num_tiles_y + r
          self.print_nbf(x_eff, y_eff, epa, east_not_west)
    # if there are more than one pod, then the left half of pods goes to west, and the right half to east.
    else:
      east_not_west = 0 if (px < (self.machine_pods_x/2)) else 1
      for r in range(self.num_vcache_rows):
        for x in range(self.num_tiles_x):
          # north vcache
          x_eff = pod_origin_x + x
          y_eff = pod_origin_y - 1 - r
          self.print_nbf(x_eff, y_eff, epa, east_not_west)
          # south vcache
          x_eff = pod_origin_x + x
          y_eff = pod_origin_y + self.num_tiles_y + r
          self.print_nbf(x_eff, y_eff, epa, east_not_west)



  # initialize icache
  def init_icache(self, pod_origin_x, pod_origin_y):
    for x in range(self.tg_dim_x):
      for y in range(self.tg_dim_y):
        x_eff = self.tgo_x + x + pod_origin_x
        y_eff = self.tgo_y + y + pod_origin_y
        for k in sorted(self.dram_data.keys()):
          addr = k - 0x20000000
          if addr < self.icache_size:
            icache_epa = ICACHE_BASE_EPA | addr
            self.print_nbf(x_eff, y_eff, icache_epa, self.dram_data[k])
        
 
  # initialize dmem
  def init_dmem(self, pod_origin_x, pod_origin_y):
    # if there is nothing in dmem, just return.
    if len(self.dmem_data.keys()) == 0:
      return

    for x in range(self.tg_dim_x):
      for y in range(self.tg_dim_y):

        x_eff = self.tgo_x + x + pod_origin_x
        y_eff = self.tgo_y + y + pod_origin_y
          
        for k in range(self.bsg_data_end_addr):
          if k in self.dmem_data.keys():
            self.print_nbf(x_eff, y_eff, k, self.dmem_data[k])
          else:
            self.print_nbf(x_eff, y_eff, k, 0)

 
  # disable dram mode
  def disable_dram(self, pod_origin_x, pod_origin_y):
    for x in range(self.tg_dim_x):
      for y in range(self.tg_dim_y):
        x_eff = self.tgo_x + x + pod_origin_x
        y_eff = self.tgo_y + y + pod_origin_y
        self.print_nbf(x_eff, y_eff, CSR_ENABLE_DRAM, 0)
   
 
  # initialize vcache in no DRAM mode
  def init_vcache(self, pod_origin_x, pod_origin_y):

    t_shift = self.safe_clog2(self.cache_block_size)

    for x in range(self.num_tiles_x):
      for t in range(self.cache_way * self.cache_set):
        epa = (t << t_shift) | (1 << (self.addr_width-1))
        data = (1 << (self.data_width-1)) | (t / self.cache_set)
        # top vcache
        self.print_nbf(x+pod_origin_x, pod_origin_y-1, epa, data)
        # bot vcache
        self.print_nbf(x+pod_origin_x, pod_origin_y+self.num_tiles_y, epa, data)
         
 
  # init DRAM
  def init_dram(self, pod_origin_x, pod_origin_y): 
    cache_size = self.cache_size
    lg_x = self.safe_clog2(self.num_tiles_x)
    lg_block_size = self.safe_clog2(self.cache_block_size)
    lg_set = self.safe_clog2(self.cache_set)
    lg_y = self.safe_clog2(2*self.num_vcache_rows)
    index_width = 32-1-2-lg_block_size-lg_x-lg_y

    if self.enable_dram == 1:



      # dram enabled:
      # EVA space is striped across top and bottom vcaches.
      if self.num_tiles_x & (self.num_tiles_x-1) == 0:
        spmd_binary_size = self.get_spmd_binary_size()
        # hashing for power of 2 banks
        for k in sorted(self.dram_data.keys()):
          addr = k - 0x20000000
          # if the binary fits in icaches, skip loading instruction to DRAM, to speed up simulation
          if (self.skip_dram_instruction_load == 1) and (spmd_binary_size < self.icache_size) and (addr < spmd_binary_size):
            continue
          x = self.select_bits(addr, lg_block_size, lg_block_size + lg_x - 1) + pod_origin_x
          y = self.select_bits(addr, lg_block_size + lg_x, lg_block_size + lg_x + lg_y-1)
          index = self.select_bits(addr, lg_block_size+lg_x+lg_y, lg_block_size+lg_x+lg_y+index_width-1)
          epa = self.select_bits(addr, 0, lg_block_size-1) | (index << lg_block_size)
          if y % 2 == 0:
            self.print_nbf(x, pod_origin_y-1-(y/2), epa, self.dram_data[k]) #top
          else:
            self.print_nbf(x, pod_origin_y+self.num_tiles_y+(y/2), epa, self.dram_data[k]) #bot
      else:
        print("hash function not supported for x={0}.")
        sys.exit()
    else:
      # dram disabled:
      # using vcache as block mem
      for k in sorted(self.dram_data.keys()):
        addr = k - 0x20000000
        x = (addr / cache_size)
        epa = addr % cache_size
        if (x < self.num_tiles_x):
          x_eff = x + pod_origin_x
          y_eff = pod_origin_y -1
          self.print_nbf(x_eff, y_eff, epa, self.dram_data[k])
        elif (x < self.num_tiles_x*2):
          x_eff = (x % self.num_tiles_x) + pod_origin_x
          y_eff = pod_origin_y + self.num_tiles_y
          self.print_nbf(x_eff, y_eff, epa, self.dram_data[k])
        else:
          print("## WARNING: NO DRAM MODE, DRAM DATA OUT OF RANGE!!!")

      

  # unfreeze tiles
  def unfreeze_tiles(self, pod_origin_x, pod_origin_y):
    tgo_x = self.tgo_x + pod_origin_x
    tgo_y = self.tgo_y + pod_origin_y

    for y in range(self.tg_dim_y):
      for x in range(self.tg_dim_x):
        x_eff = tgo_x + x
        y_eff = tgo_y + y
        self.print_nbf(x_eff, y_eff, CSR_FREEZE, 0)


  # set pc_init_val.
  # if _start is not 0, then set the pc_init_val.
  def set_pc_init_val(self, pod_origin_x, pod_origin_y):
    if self.start_addr == 0:
      return
    tgo_x = self.tgo_x + pod_origin_x
    tgo_y = self.tgo_y + pod_origin_y

    for y in range(self.tg_dim_y):
      for x in range(self.tg_dim_x):
        x_eff = tgo_x + x
        y_eff = tgo_y + y
        self.print_nbf(x_eff, y_eff, CSR_PC_INIT, self.start_addr)


  # print finish
  # when spmd loader sees, this it stops sending packets.
  def print_finish(self):
    self.print_nbf(0xff, 0xff, 0xffffffff, 0xffffffff)

  # fence
  # spmd_loader will not send another packet, until all the pending packets are completed.
  def fence(self):
    self.print_nbf(0xff, 0xff, 0x0, 0x0)




  ##### LOADER ROUTINES END  #####  

  # public main function
  # users only have to call this function.
  def dump(self):
    # vcache_wh_dest should be programmed for all pods whether or not they are used,
    for px in range(self.machine_pods_x):
      for py in range(self.machine_pods_y):
        pod_origin_x = self.origin_x_cord + (px*self.num_tiles_x)
        pod_origin_y = self.origin_y_cord + (py*2*self.num_tiles_y)
        self.init_vcache_wh_dest(pod_origin_x, pod_origin_y, px)

    # initialize all pods
    for px in range(self.num_pods_x):
      for py in range(self.num_pods_y):
        pod_origin_x = self.origin_x_cord + (px*self.num_tiles_x)
        pod_origin_y = self.origin_y_cord + (py*2*self.num_tiles_y)
        self.config_tile_group(pod_origin_x, pod_origin_y)
        self.init_icache(pod_origin_x, pod_origin_y)
        self.init_dmem(pod_origin_x, pod_origin_y)
        self.set_pc_init_val(pod_origin_x, pod_origin_y)

        if self.enable_dram != 1:
          self.disable_dram(pod_origin_x, pod_origin_y)
          self.init_vcache(pod_origin_x, pod_origin_y)

        self.init_dram(pod_origin_x, pod_origin_y)


    # wait for all store credits to return.
    self.fence()

    # unfreeze all pods
    for px in range(self.num_pods_x):
      for py in range(self.num_pods_y):
        pod_origin_x = self.origin_x_cord + (px*self.num_tiles_x)
        pod_origin_y = self.origin_y_cord + (py*2*self.num_tiles_y)
        self.unfreeze_tiles(pod_origin_x, pod_origin_y)

    # print finish nbf.
    self.print_finish()


  # hash logic for 9 bank situation. saved for posterity.
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

#
#   main()
#
if __name__ == "__main__":

  if len(sys.argv) == 22:
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
      "origin_x_cord" : int(sys.argv[14]),
      "origin_y_cord" : int(sys.argv[15]),
      "machine_pods_x" : int(sys.argv[16]),
      "machine_pods_y" : int(sys.argv[17]),
      "num_pods_x" : int(sys.argv[18]),
      "num_pods_y" : int(sys.argv[19]),
      "num_vcache_rows" : int(sys.argv[20]),
      "skip_dram_instruction_load": int(sys.argv[21])
    }

    converter = NBF(config)
    converter.dump()
  else:
    print("USAGE:")
    command = "python nbf.py {program.riscv} "
    command += "{num_tiles_x} {num_tiles_y} "
    command += "{cache_way} {cache_set} {cache_block_size} {dram_size} {max_epa_width} "
    command += "{tgo_x} {tgo_y} {tg_dim_x} {tg_dim_y} {enable_dram} "
    command += "{origin_x_cord} {origin_y_cord}"
    command += "{machine_pods_x} {machine_pods_y}"
    command += "{num_pods_x} {num_pods_y}"
    command += "{num_vcache_rows}"
    command += "{skip_dram_instruction_load}"
    print(command)


#
#   nbf_blackparrot.py
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
from nbf import NBF

# BlackParrot config bus addresses
cfg_base_addr          = 0x2000000
cfg_reg_unused         = 0x0004
cfg_reg_freeze         = 0x0008
cfg_reg_hio_mask       = 0x001c
cfg_reg_icache_id      = 0x0200
cfg_reg_icache_mode    = 0x0204
cfg_reg_dcache_id      = 0x0400
cfg_reg_dcache_mode    = 0x0404

dram_offset_base_addr  = 0x2000
dram_base_addr_reg     = 0x0000
dram_pod_offset_reg    = 0x0004

class NBFBlackParrot(NBF):
  def __init__(self, config):
    NBF.__init__(self, config)
    # BlackParrot-specific settings
    # Memory image with BlackParrot's program
    self.mem_image = config["mem_image"]
    # Base address in the manycore DRAM space where BP code is relocated
    self.mc_dram_base = config["dram_base"]
    # 4-bit pod y, 3-bit pod x
    self.mc_dram_pod_offset = config["dram_pod_offset"]

  ########################## BP UTIL FUNCTIONS ##########################

  # Read the memory image and create a dictionary of addresses and values
  def get_bp_dram_data(self):
    addr_val = dict()
    curr_addr = 0
    with open(self.mem_image, 'r') as f:
      lines = f.readlines()
      for line in lines:
        stripped = line.strip()
        if stripped.startswith("@"):
          addr = int(stripped.strip("@"), 16) - 0x80000000 + self.mc_dram_base
          curr_addr = addr / 4
        else:
          words = stripped.split()
          for word in words:
            data = ""
            for i in range(0, len(word), 2):
              data = word[i:i+2] + data
            addr_val[curr_addr] = int(data, 16)
            curr_addr += 1
    
    return addr_val

  ########################## BP CONFIG FUNCTIONS ##########################

  # Initialize BlackParrot specific registers
  def init_bp_config(self):
    self.print_nbf((0 << 4) | 15, (1 << 3) | 1, cfg_base_addr + cfg_reg_hio_mask, 1)
    self.print_nbf((0 << 4) | 15, (1 << 3) | 1, cfg_base_addr + cfg_reg_icache_mode, 1)
    self.print_nbf((0 << 4) | 15, (1 << 3) | 1, cfg_base_addr + cfg_reg_dcache_mode, 1)

    # The next few requests send acknowledgments immediately
    # So get back all credits for previous requests before sending these out
    # This will prevent multiple acks and there will be no overlap of acks
    self.fence()

    # Write to the DRAM offset registers in all the bridge modules
    self.print_nbf((0 << 4) | 15, (1 << 3) | 1, dram_offset_base_addr + dram_base_addr_reg, self.mc_dram_base)
    self.print_nbf((0 << 4) | 15, (1 << 3) | 2, dram_offset_base_addr + dram_base_addr_reg, self.mc_dram_base)
    self.print_nbf((0 << 4) | 15, (1 << 3) | 3, dram_offset_base_addr + dram_base_addr_reg, self.mc_dram_base)

    self.fence()

    self.print_nbf((0 << 4) | 15, (1 << 3) | 1, dram_offset_base_addr + dram_pod_offset_reg, self.mc_dram_pod_offset)
    self.print_nbf((0 << 4) | 15, (1 << 3) | 2, dram_offset_base_addr + dram_pod_offset_reg, self.mc_dram_pod_offset)
    self.print_nbf((0 << 4) | 15, (1 << 3) | 3, dram_offset_base_addr + dram_pod_offset_reg, self.mc_dram_pod_offset)

  def init_bp_dram(self, dram_data, pod_origin_x, pod_origin_y):
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
        # hashing for power of 2 banks
        for k in sorted(dram_data.keys()):
          addr = k - 0x20000000
          x = self.select_bits(addr, lg_block_size, lg_block_size + lg_x - 1) + pod_origin_x
          y = self.select_bits(addr, lg_block_size + lg_x, lg_block_size + lg_x + lg_y-1)
          index = self.select_bits(addr, lg_block_size+lg_x+lg_y, lg_block_size+lg_x+lg_y+index_width-1)
          epa = self.select_bits(addr, 0, lg_block_size-1) | (index << lg_block_size)
          if y % 2 == 0:
            self.print_nbf(x, pod_origin_y-1-(y/2), epa, dram_data[k]) #top
          else:
            self.print_nbf(x, pod_origin_y+self.num_tiles_y+(y/2), epa, dram_data[k]) #bot
      else:
        print("hash function not supported for x={0}.")
        sys.exit()
    else:
      # dram disabled:
      # using vcache as block mem
      for k in sorted(dram_data.keys()):
        addr = k - 0x20000000
        x = (addr / cache_size)
        epa = addr % cache_size
        if (x < self.num_tiles_x):
          x_eff = x + pod_origin_x
          y_eff = pod_origin_y -1
          self.print_nbf(x_eff, y_eff, epa, dram_data[k])
        elif (x < self.num_tiles_x*2):
          x_eff = (x % self.num_tiles_x) + pod_origin_x
          y_eff = pod_origin_y + self.num_tiles_y
          self.print_nbf(x_eff, y_eff, epa, dram_data[k])
        else:
          print("## WARNING: NO DRAM MODE, DRAM DATA OUT OF RANGE!!!")

  ##### LOADER ROUTINES END  #####

  # public main function
  # users only have to call this function.
  def dump(self):
    # Fixme: Initializes only 1 BlackParrot at (x, y) = (15, 9)
    bp_x_coord = (0 << 4) | 15
    bp_y_coord = (1 << 3) | 1
    self.print_nbf(bp_x_coord, bp_y_coord, cfg_base_addr + cfg_reg_freeze, 1)

    # Initialize the BlackParrot config registers
    self.init_bp_config()
    self.fence()

    dram_data = self.get_bp_dram_data()
    # Fixme: Initializes the DRAM space for 1 BlackParrot in a single pod
    pod_origin_x = self.origin_x_cord
    pod_origin_y = self.origin_y_cord
    self.init_bp_dram(dram_data, pod_origin_x, pod_origin_y)
    self.fence()

    # initialize all pods
    for px in range(self.num_pods_x):
      for py in range(self.num_pods_y):
        pod_origin_x = self.origin_x_cord + (px*self.num_tiles_x)
        pod_origin_y = self.origin_y_cord + (py*2*self.num_tiles_y)
        self.config_tile_group(pod_origin_x, pod_origin_y)
        self.init_icache(pod_origin_x, pod_origin_y)
        self.init_dmem(pod_origin_x, pod_origin_y)
        self.set_pc_init_val(pod_origin_x, pod_origin_y)
        self.init_vcache_wh_dest(pod_origin_x, pod_origin_y, px)

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

    # Unfreeze BlackParrot
    self.print_nbf(bp_x_coord, bp_y_coord, cfg_base_addr + cfg_reg_freeze, 0)

    # print finish nbf.
    self.print_finish()

#
#   main()
#
if __name__ == "__main__":
  if len(sys.argv) == 25:
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
      "skip_dram_instruction_load": int(sys.argv[21]),
      "mem_image": sys.argv[22],
      "dram_base": int(sys.argv[23], 16),
      "dram_pod_offset": int(sys.argv[24], 16)
    }

    converter = NBFBlackParrot(config)
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
    command += "{bp_program.mem}"
    command += "{bp_dram_base} {bp_dram_pod_offset}"
    print(command)
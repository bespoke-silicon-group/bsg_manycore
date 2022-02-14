
import math
import sys

# BlackParrot EPA map
# 3-bit device ID, 12-bit device address
# device 0 - CFG
# device 1 - CLINT
# device 2 - DRAM Base Address Register
cfg_base_addr          = 0x0000
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

class NBF:
    # Initialize
    def __init__(self, filename):
        self.filename = filename
        self.addr_width = 32
        self.data_width = 32
        self.cache_block_size = 256
        self.cache_set = 64
        self.cache_ways = 8
        self.cache_size = self.cache_set * self.cache_ways * self.cache_block_size / self.data_width
        self.num_tiles_x = 16
        self.num_tiles_y = 12

        # This is the base address in the manycore DRAM space where BP code lives
        self.mc_dram_base = 0x81000000
        # 3-bit pod y, 3-bit pod x
        self.mc_dram_pod_offset = 0b001001

        self.cache_block_size_words = self.cache_block_size // 32

    # BSG_SAFE_CLOG2(x)
    def safe_clog2(self, x):
      if x == 1:
        return 1
      else:
        return int(math.ceil(math.log(x,2)))

    # take width and val and convert to binary string
    def get_binstr(self, val, width):
        return format(val, "0"+str(width)+"b")

    # take width and val and convert to hex string
    def get_hexstr(self, val, width):
        return format(val, "0"+str(width)+"x")

    # Selects bits from a number
    def select_bits(self, num, start, end):
        retval = 0

        for i in range(start, end+1):
            b = num & (1 << i)
            retval = retval | b

        return (retval >> start)

    # take x,y coord, epa, data and turn it into nbf format.
    def print_nbf(self, x, y, epa, data):
        line =  self.get_hexstr(x, 2) + "_"
        line += self.get_hexstr(y, 2) + "_"
        line += self.get_hexstr(epa, 8) + "_"
        line += self.get_hexstr(data, 8)
        print(line)

    # Initialize V$ or infinite memories (Useful for no DRAM mode)
    # Emulates the hashing function in bsg_manycore/v/vanilla_bean/hash_function.v
    # Fixme: Works only for a power of 2 hash banks
    # Fixme: doesn't work for other pod offsets
    def init_vcache(self):
        vcache_word_offset_width = self.safe_clog2(self.cache_block_size_words)
        lg_x = self.safe_clog2(self.num_tiles_x)
        lg_banks = self.safe_clog2(self.num_tiles_x*2)
        hash_input_width = self.addr_width-1-2-vcache_word_offset_width
        index_width = hash_input_width - lg_banks

        f = open(self.filename, "r")

        curr_addr = 0

        # hashing for power of 2 banks
        for line in f.readlines():
            stripped = line.strip()
            if not stripped:
                continue
            elif stripped.startswith("@"):
                curr_addr = int(stripped.strip("@"), 16)
                continue

            for word in stripped.split():
                addr = curr_addr + self.mc_dram_base
                data = ""
                for i in range(0, len(word), 2):
                    data = word[i:i+2] + data
                data = int(data, 16)
                bank = self.select_bits(addr, 2+vcache_word_offset_width, 2+vcache_word_offset_width+lg_banks-1)
                index = self.select_bits(addr, 2+vcache_word_offset_width+lg_banks, 2+vcache_word_offset_width+lg_banks+index_width-1)
                x = self.select_bits(bank, 0, lg_x-1)
                #+ self.select_bits(self.mc_dram_pod_offset, 0, 1)
                y = self.select_bits(bank, lg_x, lg_x)
                #+ self.select_bits(self.mc_dram_pod_offset, 3, 4)
                epa = (index << vcache_word_offset_width) | self.select_bits(addr, 2, 2+vcache_word_offset_width-1)
                curr_addr += 4

                # Fixme: This works only for only 1 north vcache pod and 1 south vcache pod
                self.print_nbf(1<<4 | x, y<<5 | (15 - 15*y), epa, data)

    #  // BP EPA Map
    #  // dev: 0 -- CFG
    #  //      1 -- CLINT
    #  //      2 -- DRAM Offset Register
    #  typedef struct packed
    #  {
    #    logic [3:0]  dev;
    #    logic [11:0] addr;
    #  } bp_epa_s;

    # BP core configuration
    def init_config(self):
        self.print_nbf(0x0f, 1 << 4 | 1, cfg_base_addr + cfg_reg_hio_mask, 1)
        self.print_nbf(0x0f, 1 << 4 | 1, cfg_base_addr + cfg_reg_icache_mode, 1)
        self.print_nbf(0x0f, 1 << 4 | 1, cfg_base_addr + cfg_reg_dcache_mode, 1)

        # The next few requests send acknowledgments immediately
        # So get back all credits for previous requests before sending these out
        # This will prevent multiple acks and there will be no overlap of acks
        self.fence()

        # Write to the DRAM offset registers in all the bridge modules
        self.print_nbf(0x0f, 1 << 4 | 1, dram_offset_base_addr + dram_base_addr_reg, self.mc_dram_base)
        self.print_nbf(0x0f, 1 << 4 | 1, dram_offset_base_addr + dram_pod_offset_reg, self.mc_dram_pod_offset)

        self.fence()


    # print finish
    def finish(self):
        self.print_nbf(0xff, 0xff, 0xffffffff, 0xffffffff)

    # fence
    def fence(self):
        self.print_nbf(0xff, 0xff, 0x0, 0x0)

    # Dump the nbf
    def dump(self):
        # Freeze BP
        self.print_nbf(0x0f, 1 << 4 | 1, cfg_base_addr + cfg_reg_freeze, 1)
        # Initialize BP configuration registers
        self.init_config()
        self.fence()
        # Initialize memory
        self.init_vcache()
        self.fence()
        # Unfreeze BP
        self.print_nbf(0x0f, 1 << 4 | 1, cfg_base_addr + cfg_reg_freeze, 0)
        self.fence()
        self.finish()


if __name__ == "__main__":
    if len(sys.argv) == 2:
        gen = NBF(sys.argv[1])
        gen.dump()
    else:
        print("Usage: nbf.py filename.mem")


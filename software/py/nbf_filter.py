
import sys
import math
import os


class NBFFilter:

  def __init__(self, config):
    self.nbf_file = config["nbf_file"]
    self.vcache_log = config["vcache_log"]

    self.num_tiles_x = config["num_tiles_x"]
    self.num_tiles_y = config["num_tiles_y"]

    self.vcache_way = config["vcache_way"]
    self.vcache_set = config["vcache_set"]
    self.vcache_block_size = config["vcache_block_size"]

    self.index_width = self.safe_clog2(self.vcache_set)
    self.block_offset = self.safe_clog2(self.vcache_block_size)

    self.read_vcache_log()



  def safe_clog2(self, x):
    if x == 1:
      return 1
    else:
      return int(math.ceil(math.log(x,2)))
    
  

  # create a set of tuples (x,way,index)
  def read_vcache_log(self):   
    f = open(self.vcache_log, "r")
    lines= f.readlines()

    self.accessed_block = set()

    for line in lines:
      stripped = line.strip()
      if stripped:
        words =  stripped.split(",")
        x = -1
        way = -1
        index = -1
        for word in words:
          kv = word.split("=")
          if kv[0] == "x":
            x = int(kv[1])
          elif kv[0] == "addr":
            addr = int(kv[1])
            way = (addr>>(2+self.block_offset+self.index_width)) % self.vcache_way
            index = (addr>>(2+self.block_offset)) % self.vcache_set
        self.accessed_block.add((x,way,index))

    #for s in self.accessed_addr:
    #  print(s)


  def filter(self):
    index_width = self.safe_clog2(self.vcache_set)
    block_offset = self.safe_clog2(self.vcache_block_size)

    f = open(self.nbf_file, "r")
    lines = f.readlines()
    
    for line in lines:
      stripped = line.strip()
      if stripped:
        words = stripped.split("_")   
        x = int(words[0],16)
        y = int(words[1],16)
        epa = int(words[2],16)
        way = (epa>>(self.block_offset+self.index_width)) % self.vcache_way
        index = (epa>>self.block_offset) % self.vcache_set
        if y == self.num_tiles_y:
          if (x,way,index) in self.accessed_block:
            print(stripped)
        else:
          print(stripped)




# main()
if __name__ == "__main__":

  config = {
    "nbf_file": sys.argv[1],
    "vcache_log": sys.argv[2],

    "num_tiles_x": int(sys.argv[3]),
    "num_tiles_y": int(sys.argv[4]),

    "vcache_way": int(sys.argv[5]),
    "vcache_set": int(sys.argv[6]),
    "vcache_block_size": int(sys.argv[7])
  } 

  nbf_filter = NBFFilter(config)
  nbf_filter.filter()



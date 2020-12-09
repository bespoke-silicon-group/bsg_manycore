#
#   router_stat.py
#
#   this scripts parses router_stat.csv and computes the diff between stats printed at two different timestamps
#
#   How to use:
#
#   python3 router_stat.py router_stat.csv num_tiles_x num_tiles_y timestamp1 timestamp2
#
#

import sys
import numpy as np

START_Y = 1 # skip top vcache y-cord

class RouterStat:

  # default constructor
  def __init__(self, num_tiles_x, num_tiles_y):
    self.num_tiles_x = num_tiles_x
    self.num_tiles_y = num_tiles_y


  # main public function
  def process(self, csvfile, timestamp1, timestamp2):

    # parse csv
    stats = []
    with open(csvfile, "r") as f:
      next(f)
      for line in f:
        stripped = line.strip()
        words = stripped.split(',')
        stat = {}
        stat["timestamp"] = int(words[0])
        stat["global_ctr"] = int(words[1])
        stat["x"] = int(words[2])
        stat["y"] = int(words[3])
        stat["XY_order"] = int(words[4])
        stat["output_dir"] = int(words[5])
        stat["idle"] = int(words[6])
        stat["utilized"] = int(words[7])
        stat["stalled"] = int(words[8])
        stat["arbitrated"] = int(words[9])
        stats.append(stat)
      
    
    # find max dir   
    dirs_lp = max(map(lambda x: x["output_dir"], stats))+1

    # init bucket
    # [X][Y][XY-order][dirs]
    idle = np.zeros((self.num_tiles_x, self.num_tiles_y+1, 2, dirs_lp))
    utilized = np.zeros((self.num_tiles_x, self.num_tiles_y+1, 2, dirs_lp))
    stalled = np.zeros((self.num_tiles_x, self.num_tiles_y+1, 2, dirs_lp))
    arbitrated = np.zeros((self.num_tiles_x, self.num_tiles_y+1, 2, dirs_lp))

    for stat in stats:
      x = stat["x"]
      y = stat["y"]-START_Y
      XY_order = stat["XY_order"]
      output_dir = stat["output_dir"]
      ts = stat["timestamp"]
      if timestamp1 == ts:
        idle[x][y][XY_order][output_dir] -= stat["idle"]
        utilized[x][y][XY_order][output_dir] -= stat["utilized"]
        stalled[x][y][XY_order][output_dir] -= stat["stalled"]
        arbitrated[x][y][XY_order][output_dir] -= stat["arbitrated"]
      if timestamp2 == ts:
        idle[x][y][XY_order][output_dir] += stat["idle"]
        utilized[x][y][XY_order][output_dir] += stat["utilized"]
        stalled[x][y][XY_order][output_dir] += stat["stalled"]
        arbitrated[x][y][XY_order][output_dir] += stat["arbitrated"]
    

    # print header
    print("x,y,XY_order,output_dir,idle,utilized,stalled,arbitrated")

    # print result
    for x in range(self.num_tiles_x):
      for y in range(self.num_tiles_y+1):
        for order in range(2):
          for dirs in range(dirs_lp):
            line = "{},{},{},{},".format(x,y+START_Y,order,dirs)
            line += "{},{},{},{}".format(idle[x][y][order][dirs],utilized[x][y][order][dirs],stalled[x][y][order][dirs],arbitrated[x][y][order][dirs])
            print(line)


if __name__ == "__main__":

  csvfile = sys.argv[1]
  num_tiles_x = int(sys.argv[2])
  num_tiles_y = int(sys.argv[3])
  timestamp1 = int(sys.argv[4])
  timestamp2 = int(sys.argv[5])

  rs = RouterStat(num_tiles_x, num_tiles_y)
  rs.process(csvfile, timestamp1, timestamp2)

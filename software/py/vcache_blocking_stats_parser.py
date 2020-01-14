#
#   vcache_blocking_stats.py
#
#   usage:
#   python vcache_blocking_stats.py {vcache_stats.log}
#

import sys
import csv
import sqlite3


class VcacheBlockingStatsParser:

  def __init__(self):
    self.conn = sqlite3.connect("vcache_stats.db")

    c = self.conn.cursor()
    c.execute('''DROP TABLE IF EXISTS stats''')
    c.execute('''CREATE TABLE stats
                 (instance TEXT
                  ,global_ctr INTEGER
                  ,tag INTEGER
                  ,ld INTEGER
                  ,st INTEGER
                  ,ld_miss INTEGER
                  ,st_miss INTEGER
                  ,dma_read_req INTEGER
                  ,dma_write_req INTEGER)''')
    
    self.conn.commit()

  
  def parse_csv(self, filename):
    c = self.conn.cursor()

    with open(filename) as csvfile:
      reader = csv.DictReader(csvfile)
      for row in reader:
        c.execute('''INSERT INTO stats VALUES (?,?,?,?,?,?,?,?,?)''',
          (row["instance"],
          int(row["global_ctr"]),
          int(row["tag"]),
          int(row["ld"]),
          int(row["st"]),
          int(row["ld_miss"]),
          int(row["st_miss"]),
          int(row["dma_read_req"]),
          int(row["dma_write_req"])))
        self.conn.commit()

    agg_stat = c.execute('''
      SELECT
        global_ctr
        ,SUM(ld) as ld
        ,SUM(st) as st
        ,SUM(ld_miss) as ld_miss
        ,SUM(st_miss) as st_miss
        ,SUM(dma_read_req) as dma_read_req
        ,SUM(dma_write_req) as dma_write_req
      FROM stats 
      GROUP BY global_ctr
    ''')

    agg_stat = list(agg_stat)

    # find earliest and latest.
    min_stat = min(agg_stat, key=lambda x: x[0])
    max_stat = max(agg_stat, key=lambda x: x[0])
    
    num_cycles = max_stat[0] - min_stat[0]
    load_hit = max_stat[1] - min_stat[1]
    store_hit = max_stat[2] - min_stat[2]
    load_miss = max_stat[3] - min_stat[3]
    store_miss = max_stat[4] - min_stat[4]
    dma_write_req = max_stat[5] - min_stat[5]
    dma_read_req = max_stat[6] - min_stat[6]
    
    # miss rate
    total_load = load_miss + load_hit
    total_store = store_miss + store_hit

    load_miss_rate = load_miss / float(total_load) * 100.0
    store_miss_rate = store_miss / float(total_store) * 100.0
    miss_rate = (load_miss+store_miss) / float(total_load+total_store) * 100.0

    # bandwidth (word per cycle)
    bandwidth = (total_load+total_store) / float(num_cycles)

    print("++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++")
    print("Number of Cycles             = {}".format(num_cycles))
    print("Load Hit                     = {}".format(load_hit))
    print("Store Hit                    = {}".format(store_hit))
    print("Load Miss                    = {}".format(load_miss))
    print("Store Miss                   = {}".format(store_miss))
    print("DMA write request            = {}".format(dma_write_req))
    print("DMA read request             = {}".format(dma_read_req))
    print("----------------------------------------------------------------------")
    print("Load Miss Rate (%)           = {:2.4f}".format(load_miss_rate))
    print("Store Miss Rate (%)          = {:2.4f}".format(store_miss_rate))
    print("Miss Rate (%)                = {:2.4f}".format(miss_rate))
    print("----------------------------------------------------------------------")
    print("Bandwidth (word per cycle)   = {:4.4f}".format(bandwidth))
    print("++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++")




# main()
if __name__ == "__main__":
  
  # command-line arguments
  filename = sys.argv[1]
  
  parser = VcacheBlockingStatsParser()
  parser.parse_csv(filename)

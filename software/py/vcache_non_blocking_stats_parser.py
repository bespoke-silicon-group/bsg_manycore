#
#   vcache_non_blocking_stats.py
#
#   usage:
#   python vcache_non_blocking_stats.py {vcache_non_locking_stats.log}
#

import sys
import csv
import sqlite3


class VcacheNonBlockingStatsParser:
    
  text_columns = ["instance"]
  integer_columns = ["global_ctr", "tag", "ld_hit", "st_hit",
                     "ld_hit_under_miss", "st_hit_under_miss", 
                     "ld_miss", "st_miss",
                     "ld_mhu", "st_mhu",
                     "dma_read_req", "dma_write_req"]

  # default constructor
  def __init__(self):
    self.conn = sqlite3.connect("stats.db")
    c = self.conn.cursor()
    c.execute('''DROP TABLE IF EXISTS stats''')
    c.execute('''CREATE TABLE stats
                 (instance TEXT
                  ,global_ctr INTEGER
                  ,tag INTEGER
                  ,ld_hit INTEGER
                  ,st_hit INTEGER
                  ,ld_hit_under_miss INTEGER
                  ,st_hit_under_miss INTEGER
                  ,ld_miss INTEGER
                  ,st_miss INTEGER
                  ,ld_mhu INTEGER
                  ,st_mhu INTEGER
                  ,dma_read_req INTEGER
                  ,dma_write_req INTEGER)''')
    self.conn.commit()

  
  # this parse csv and return stat object.
  # take the earliest and the latest stats and calculate the difference.
  def parse_csv(self, filename):
    c = self.conn.cursor()

    with open(filename) as csvfile:
      reader = csv.DictReader(csvfile)
      for row in reader:
        c.execute('''
          INSERT INTO stats VALUES
          (?,?,?,?,?,?,?,?,?,?,?,?,?)''',
          (row["instance"],
          int(row["global_ctr"]),
          int(row["tag"]),
          int(row["ld_hit"]),
          int(row["st_hit"]),
          int(row["ld_hit_under_miss"]),
          int(row["st_hit_under_miss"]),
          int(row["ld_miss"]),
          int(row["st_miss"]),
          int(row["ld_mhu"]),
          int(row["st_mhu"]),
          int(row["dma_read_req"]),
          int(row["dma_write_req"])))
        self.conn.commit()

    aggregate_stats = c.execute('''
      SELECT
        global_ctr
        ,SUM(ld_hit) as ld_hit
        ,SUM(st_hit) as st_hit
        ,SUM(ld_hit_under_miss) as ld_hit_under_miss
        ,SUM(st_hit_under_miss) as st_hit_under_miss
        ,SUM(ld_miss) as ld_miss
        ,SUM(st_miss) as st_miss
        ,SUM(ld_mhu) as ld_mhu
        ,SUM(st_mhu) as st_mhu
        ,SUM(dma_read_req) as dma_read_req 
        ,SUM(dma_write_req) as dma_write_req 
      FROM stats
      GROUP BY global_ctr''')

    aggregate_stats = list(aggregate_stats)
    
    # find earliest and latest.
    min_stat = min(aggregate_stats, key=lambda x: x[0])
    max_stat = max(aggregate_stats, key=lambda x: x[0])

    # calculate diff.
    num_cycles = max_stat[0] - min_stat[0]
    load_hit = max_stat[1] - min_stat[1]
    store_hit = max_stat[2] - min_stat[2]
    load_hit_under_miss = max_stat[3] - min_stat[3]
    store_hit_under_miss = max_stat[4] - min_stat[4]
    load_miss = max_stat[5] - min_stat[5]
    store_miss = max_stat[6] - min_stat[6]
    load_mhu = max_stat[7] - min_stat[7]
    store_mhu = max_stat[8] - min_stat[8]
    dma_write_req = max_stat[9] - min_stat[9]
    dma_read_req = max_stat[10] - min_stat[10]
    
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
    print("Load Hit Under Miss          = {}".format(load_hit_under_miss))
    print("Store Hit Under Miss         = {}".format(store_hit_under_miss))
    print("Load Miss                    = {}".format(load_miss))
    print("Store Miss                   = {}".format(store_miss))
    print("Load by MHU                  = {}".format(load_mhu))
    print("Store by MHU                 = {}".format(store_mhu))
    print("DMA write request            = {}".format(dma_write_req))
    print("DMA read request             = {}".format(dma_read_req))
    print("----------------------------------------------------------------------")
    print("Load Miss Rate (%)           = {:2.4f}".format(load_miss_rate))
    print("Store Miss Rate (%)          = {:2.4f}".format(store_miss_rate))
    print("Miss Rate (%)                = {:2.4f}".format(miss_rate))
    print("----------------------------------------------------------------------")
    print("Bandwidth (word per cycle)   = {}".format(bandwidth))
    print("++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++")
    



# main()
if __name__ == "__main__":
  # command-line arguments
  filename = sys.argv[1]

  # do parsing
  parser = VcacheNonBlockingStatsParser()
  parser.parse_csv(filename)

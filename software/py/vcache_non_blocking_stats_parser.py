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
    
    min_stat = min(aggregate_stats, key=lambda x: x[0])
    max_stat = max(aggregate_stats, key=lambda x: x[0])

    print("+++++++++++++++++++++++++++++++++++++++++++++++++++++")
    print("Number of Cycles             = {}".format(max_stat[0]-min_stat[0]))
    print("Load Hit                     = {}".format(max_stat[1]-min_stat[1]))
    print("Store Hit                    = {}".format(max_stat[2]-min_stat[2]))
    print("Load Hit Under Miss          = {}".format(max_stat[3]-min_stat[3]))
    print("Store Hit Under Miss         = {}".format(max_stat[4]-min_stat[4]))
    print("Load Miss                    = {}".format(max_stat[5]-min_stat[5]))
    print("Store Miss                   = {}".format(max_stat[6]-min_stat[6]))
    print("Load by MHU                  = {}".format(max_stat[7]-min_stat[7]))
    print("Store by MHU                 = {}".format(max_stat[8]-min_stat[8]))
    print("DMA write request            = {}".format(max_stat[9]-min_stat[9]))
    print("DMA read request             = {}".format(max_stat[10]-min_stat[10]))
    print("+++++++++++++++++++++++++++++++++++++++++++++++++++++")



# main()
if __name__ == "__main__":
  # command-line arguments
  filename = sys.argv[1]

  # do parsing
  parser = VcacheNonBlockingStatsParser()
  parser.parse_csv(filename)

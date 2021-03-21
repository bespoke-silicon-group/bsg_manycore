#
#   dramsim3_blood_graph.py
#
#   how to use
#   python dramsim3_blood_graph.py {input.log}  {output.png}
#
#   Author: Tommy



import sys
import csv
from PIL import Image, ImageDraw

class BloodGraph:

  palette = {
    "act"       : (0xff,0xff,0x00),   ## yellow       = activate
    "pre"       : (0xff,0xa5,0x00),   ## orange       = precharge
    "rd"        : (0x00,0xff,0x00),   ## green        = read
    "wr"        : (0x00,0x88,0x00),   ## dark green   = write
    "nop"       : (0xff,0xaa,0xff),   ## pink         = no request in this bank
    "conf"      : (0xff,0x00,0x00),   ## red          = there is a row hit, but can't access due to various timing constraints (tWTR, tCCD_S, etc)
    "closed"    : (0x80,0x00,0x80),   ## purple       = there is a request in this bank, but the row is closed.
    "ref"       : (0x60,0x60,0x60),   ## gray         = refresh
    "arb"       : (0x00,0xff,0xff),   ## cyan         = there is a row hit, but other bank is accessing (arbitrated)
    "row_miss"  : (0xff,0x00,0xff)    ## fuchsia      = there is a request but row miss.
  }

  def generate(self, input_file, output_file):
    traces = []
    with open(input_file) as f:
      csv_reader = csv.DictReader(f, delimiter=",")
      for row in csv_reader:
        trace = {}
        trace["time"] = int(row["time"])
        trace["bank"] = int(row["bank"])
        trace["state"] = row["state"]
        traces.append(trace)

      self.__get_stats(traces)
      self.__init_image()
      for trace in traces:
        self.__mark_trace(trace)
      self.img.save(output_file)
      return

  def __get_stats(self, traces):
    banks = list(map(lambda t: t["bank"], traces))
    times = list(map(lambda t: t["time"], traces))
    self.num_banks = 1+max(banks)
    self.end_time = max(times)
    return

  def __init_image(self):
    self.img_width = 3900//2
    self.img_height = ((self.end_time+self.img_width)//self.img_width)*(2+self.num_banks)
    self.img = Image.new("RGB", (self.img_width, self.img_height), "black")
    self.pixel = self.img.load()
    return

  def __mark_trace(self, trace):
    col = trace["time"] % self.img_width
    floor = trace["time"] // self.img_width
    row = floor*(2+self.num_banks) + trace["bank"]
    self.pixel[col,row] = self.palette[trace["state"]]


if __name__ == "__main__":
  input_file = sys.argv[1]
  output_file = sys.argv[2]
  blood_graph = BloodGraph()
  blood_graph.generate(input_file, output_file)

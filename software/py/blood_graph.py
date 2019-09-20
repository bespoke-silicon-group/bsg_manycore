#
#   blood_graph.py
#
#   vanilla_core execution visualizer.
# 
#   input: vanilla.log
#   output: bitmap file
#
#   @author tommy
#
#   How to use:
#   python3 blood_graph.py {x} {y} vanilla.log {output_file}
#

import vanilla_trace_parser


class BloodGraph:
  def __init__(self)
    self.parser = VanillaTraceParser()
  
  # main public method
  def generate(self, filename):
    traces = self.parser.parse(filename)


# main()
if __name__ == "__main__":
  
  bg = BloodGraph()

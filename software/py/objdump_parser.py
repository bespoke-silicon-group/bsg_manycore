#
#   objdump_parser.py
#
#   takes .riscv, call objdump to disassemble.
#   convert the output into a list of {pc, instr, disassembly} tuple.
#
#   @author tommy
#
#

import sys
import subprocess
import re

class ObjdumpParser:

  # default constructor
  def __init__(self, objdump):
    self.objdump = objdump # path objdump bin


  # main public function
  def parse(self, filename):
    cmd = [self.objdump, "-j", ".text.dram", "-M numeric", "-D"]
    cmd.append(filename)
    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE)
    proc.wait()
    lines = proc.stdout.readlines()
    stripped = list(map(lambda l: l.strip(), lines))
    

    dasm = []
    for line in stripped:
      #match = 0
      match = re.match("^([a-f0-9]+):\s+([a-f0-9]{8})\s+([\s\S]+)$", line.decode("utf-8"))
      if match:
        dump = {}
        dump["pc"] = match.group(1)
        dump["instr"] = match.group(2)
        dump["dasm"] = match.group(3)
        dasm.append(dump)

    return dasm


# this is only for testing
if __name__ == "__main__":
  objdump = sys.argv[1]
  riscv = sys.argv[2]  

  op = ObjdumpParser(objdump)
  dasm = op.parse(riscv)


  for d in dasm:
    print(d)
  

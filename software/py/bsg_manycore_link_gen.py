#!/usr/bin/python3

import argparse

"""
BSG Manycore linker command file generator.

This script provides two settings with two options each, and
as a result can generate four command files:

1. default_data_loc: Default data location
     - "private": data is placed in the local memory (DMEM) by default.
     - "shared" : data is placed in the shared memory (DRAM) by default.

     Note: Data attributed to ".dmem" section is placed in DMEM and data 
     attributed to ".dram" and ".rodata" sections is placed DRAM, 
     irrespective of the chosen option. For example,
     
     int foo __attribute__ ((section (".dram")));

     would force "foo" to be placed in DRAM no matter what default data
     behaviour is.

2. shared_mem: Shared memory type
     - "onchip" : Assumes DRAM is absent in the system and all the shared
                  memory is provided by vcaches. This reduces the size of
                  shared address space to the total size of vcaches.
     - "offchip": Assumes DRAM is presnet in the system.


Usage: ./bsg_manycore_link_gen.py -h

Bandhav Veluri
02/11/2020
"""

class bsg_manycore_link_gen:
  _opening_comment = \
    "/**********************************\n" \
    + " BSG Manycore Linker Script \n\n"

  def __init__(self, default_data_loc, shared_mem, dram_size, vcache_size):
    self._dram_size = dram_size
    self._vcache_size = vcache_size
    self._opening_comment += \
        " data: " + default_data_loc + "\n" \
      + " shared memory: " + shared_mem + "\n" \
      + "***********************************/\n"

  # Format:
  # <mem region name> : [<access>, <start address>, <size>]
  def _memory_regions(self, mem_regions):
    script = 'MEMORY {\n'

    for m, access, origin, size in mem_regions:
      script += "{0} ({1}) : ORIGIN = 0x{2:08x}, LENGTH = 0x{3:08x}\n".format(
          m, access, origin, size)

    script += '}\n'

    return script

  def _sections(self, sections):
    script = 'SECTIONS {\n'

    for i, (sec, content, load_address, mem_region) in enumerate(sections):
      if load_address == None:
        assert i > 0, "Load address of first section cannot be None."
        prev_sec = sections[i-1][0]
        load_address = "LOADADDR({0}) + ADDR({1}) - ADDR({2})".format(prev_sec,
            sec, prev_sec)
      else:
        load_address = "0x{0:08x}".format(load_address)

      script += "\n {0} : AT ({1}) {{\n".format(sec, load_address)
      script += content
      script += "}} >{0}\n".format(mem_region)

    script += '}\n'

    return script

  def script(self):
    # Address constants:
    #
    # LMA (Load Memory Address)    => NPA used by loader
    # VMA (Virtual Memory Address) => Logical address used by linker for 
    #                                 symbol resolutions
    #
    #
    # Note on program memory:
    #
    # BSG Manycore's PC width is 24-bit, addressing a total of 16MB program 
    # space. Since the 31:25 MBSs are assumed to be 0s, linking should also be
    # done assuming 0x0-0x01000000 as the valid program space. This means that
    # .text section VMAs lie in 0x0-0x01000000. On the other hand, .text section
    # is loaded to DRAM and as result, it's LMAs shouls be >0x80000000. So,
    # .text section is loaded in the region 0x80000000-0x81000000.
    _DMEM_START      = 0x1000
    _DMEM_SIZE       = 0x1000
    _TEXT_VMA_START  = 0x0
    _TEXT_VMA_SIZE   = 0x1000000
    _TEXT_LMA_START  = 0x80000000
    _DRAM_DATA_START = 0x80000000 + _TEXT_VMA_SIZE

    mem_regions = [
      # Format:
      # [<mem region name>, <access>, <start address>, <size>]
      ['DMEM_VMA', 'rw', _DMEM_START, _DMEM_SIZE],
      ['DRAM_TEXT_VMA', 'rx', _TEXT_VMA_START, _TEXT_VMA_SIZE],
      ['DRAM_DATA_VMA', 'rw', _DRAM_DATA_START, self._dram_size - _TEXT_VMA_SIZE]
    ]

    sections = [
      # Format:
      # [<section name>, <content>, <load_address>, <mem_region>]
      #
      # `load_address = None` means the section could be placed after the
      # the previous section
      ['.data.dmem',
        """
          *(.data)
          *(.data*)
        """,
        0x1000,
        'DMEM_VMA'],

      ['.sdata.dmem',
        """ 
          _gp = . + 0x800; 
          *(.srodata.cst16)  
          *(.srodata.cst8) 
          *(.srodata.cst4) 
          *(.srodata.cst2) 
          *(.srodata*) 
          *(.sdata .sdata.* .gnu.linkonce.s.*) 
        """,
        None,
        'DMEM_VMA']
    ]

    script = self._opening_comment + '\n'
    script += self._memory_regions(mem_regions) + '\n'
    script += self._sections(sections)
    return script


if __name__ == '__main__':
  # Parse arguments
  parser = argparse.ArgumentParser()
  parser.add_argument('--default_data_loc', 
    help='Default data location (private|shared)')
  parser.add_argument('--shared_mem', 
    help='Shared memory type (onchip|offchip)')
  parser.add_argument('--dram_size', 
    help='DRAM size',
    default=0x80000000,
    type=int)
  parser.add_argument('--vcache_size', 
    help='Total size of vcaches',
    type=int)
  args = parser.parse_args()


  # Check vcache size
  if args.shared_mem == 'onchip':
    assert args.vcache_size != None, \
      "--vcache_size should be set when shared memory is onchip only."
    assert args.vcache_size > 0, \
      "Invalid vcache size (%d): expected a positive integer" % args.vcache_size
    assert args.vcache_size < args.dram_size, \
      "Invalid vcache size (%d): should be less than dram size (%d)" \
        % (args.vcache_size, args.dram_size)

  vcache_size = 0 if args.vcache_size == None else int(args.vcache_size)


  # Generate linker script
  link_gen = bsg_manycore_link_gen(args.default_data_loc, args.shared_mem, \
    args.dram_size, vcache_size)
  print(link_gen.script())

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
  # Address constants:
  #
  # LMA (Load Memory Address)    => NPA used by loader
  # VMA (Virtual Memory Address) => Logical address used by linker for 
  #                                 address resolutions
  _DMEM_START     = 0x1000
  _DMEM_SIZE      = 0x1000
  _TEXT_LMA_START = 0x80000000
  _TEXT_VMA_START = 0x0
  _SHARED_START   = 0x81000000

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

if __name__ == '__main__':
  # Parse arguments
  parser = argparse.ArgumentParser()
  parser.add_argument('--default_data_loc', 
                     help='Default data location (private|shared)')
  parser.add_argument('--shared_mem', 
                     help='Shared memory type (onchip|offchip)')
  parser.add_argument('--vcache_size', 
                     help='Total size of vcache')
  args = parser.parse_args()


  # Compute memory sizes
  dram_size = 0x80000000

  if args.shared_mem == 'onchip':
    assert args.vcache_size != None, \
      "--vcache_size should be set when shared memory is onchip only."
    assert args.vcache_size > 0 and args.vcache_size < dram_size, \
      "--vcache_size: invalid value (%d)" % args.vcache_size

  vcache_size = 0 if args.vcache_size == None else int(args.vcache_size)


  # Generate linker script
  bsg_manycore_link_gen(args.default_data_loc, args.shared_mem,
      dram_size, vcache_size).gen()

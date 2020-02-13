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


Usage:
bsg_manycore_link_gen.py --default_data_loc=[private|shared] \
                         --shared_mem=[onchip|offchip]

Bandhav Veluri
02/11/2020
"""

if __name__ == '__main__':
  parser = argparse.ArgumentParser()
  parser.add_argument('--default_data_loc', 
                     help='Default data location (private|shared)')
  parser.add_argument('--shared_mem', 
                     help='Shared memory type (onchip|offchip)')
  args = parser.parse_args()

  print(args)

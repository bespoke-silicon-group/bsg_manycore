#!/usr/bin/python3

import argparse, re

"""
BSG Manycore linker command file generator.

Usage: ./bsg_manycore_link_gen.py -h

Bandhav Veluri
02/11/2020
"""

class bsg_manycore_link_gen:
  """
  A configurable linker command file generator for linking BSG Manycore
  kernels. Kernel memory has private and shared regions backed by 4KB
  on-tile sram (DMEM) and off-chip DRAM, respectively. Configuration options
  include default location of data (dmem or dram), stack pointer and
  dram memory size. These options won't affect the following:

  1. Data attributed to .dmem* and .dram* sections. Following decalaration

     int foo __attribute__((section (".dram")));

     would place foo in dram region irrespective of default data location.

  2. Data in bsg_manycore_lib would always be placed in dmem region.

  
  Note on program memory:
  
  Manycore's PC width is 24-bit, addressing a total of 16MB program space.
  Since the 31:25 MBSs are assumed to be 0s, linking should also assume
  0x0-0x01000000 as the valid program space. This means that .text section VMAs
  lie in 0x0-0x01000000. On the other hand, .text section is loaded to DRAM and
  as result, it's LMAs shouls be >0x80000000. So, .text section is loaded in the
  region 0x80000000-0x81000000. Consequently, VMA's 0x80000000-0x81000000 are
  are reserved for .text section as well.
  """

  _opening_comment = \
    "/**********************************\n" \
    + " BSG Manycore Linker Script \n\n"

  def __init__(self, default_data_loc, dram_mem_size, sp):
    self._default_data_loc = default_data_loc
    self._dram_mem_size = dram_mem_size
    self._sp = sp
    self._opening_comment += \
        " data default: {0}\n".format(default_data_loc) \
        + " dram memory size: 0x{0:08x}\n".format(dram_mem_size) \
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

  def _section(self, name, address, vma_region, lma_region,
      in_sections, in_objects):
    """
    Forms an LD section.
    
    Arguments:
    name         -- name of the section.
    address      -- if `vma_region` is null, `address` is assumed to
                    be section's logical address. If `lma_region` is null,
                    `address` is assumed to be sections load address.
    vma_region   -- name of the VMA region if the section is to be directed to
                    a VMA region, else None.
    lma_region   -- name of the LMA region if the section is to be directed to
                    a VMA region, else None.
    in_sections  -- list of input sections.
    in_objects   -- list of input objects to consider.
    """
    vaddr        = "" # virtual address
    laddr        = "" # logical address
    vma_redirect = ""
    lma_redirect = ""

    if lma_region == None:
      laddr = "AT({0})".format(address)
      vma_redirect = ">{0}".format(vma_region)
    else:
      vaddr = address
      lma_redirect = "AT>{0}".format(lma_region)

    script = "{0} {1} :\n{2} {{".format(name, vaddr, laddr)

    for sec in in_sections:
      script += "\n  {0}({1})".format(in_objects, sec)

    script += "\n  ALIGN(8);\n"
    script += "\n}} {0} {1}\n\n".format(vma_redirect, lma_redirect)

    return script

  def script(self):
    # Address constants:
    #
    # LMA (Load Memory Address)    => NPA used by loader
    # VMA (Virtual Memory Address) => Logical address used by linker for 
    #                                 symbol resolutions
    _DMEM_VMA_START = 0x1000
    _DMEM_VMA_SIZE  = 0x1000
    _DRAM_LMA_START  = 0x80000000
    _DRAM_LMA_SIZE   = self._dram_mem_size

    mem_regions = [
      # Format:
      # [<mem region name>, <access>, <start address>, <size>]
      #
      # .text section VMAs and dmem memory VMAs overlap with the
      # current memory layout (both start at address 0x0). This makes
      # manycore essentially a Harvard architecture. But linker doesn't
      # allow overlapping VMAs by not letting location couter not move 
      # backwards. To overcome this, we use combination of VMA and LMA
      # "memory regions" to be able to never move location counter
      # backward.
      ['DMEM_VMA', 'rw', _DMEM_VMA_START, _DMEM_VMA_SIZE],
      ['DRAM_LMA', 'rw', _DRAM_LMA_START, _DRAM_LMA_SIZE],
      ]

    section_map = [
      # Format:
      # <output section>: [<input sections>]
      ['.text.dram'        , ['.crtbegin','.text.startup','.text','.text.*']],
      ['.dmem'             , ['.dmem','.dmem.*']],
      ['.data'             , ['.data','.data*']],
      ['.sdata'            , ['.srodata.cst16','.srodata.cst8','.srodata.cst4',
                              '.srodata.cst2','.srodata*','.sdata','.sdata.*',
                              '.gnu.linkonce.s.*']],
      ['.sbss'             , ['.sbss','.sbss.*','.gnu.linkonce.sb.*','.scommon']],
      ['.bss'              , ['.bss','.bss*']],
      ['.tdata'            , ['.tdata','.tdata*']],
      ['.tbss'             , ['.tbss','.tbss*']],
      ['.eh_frame'         , ['.eh_frame','.eh_frame*']],
      ['.striped.data.dmem', ['.striped.data']],
      ['.rodata.dram'      , ['.rodata','.rodata*']],
      ['.dram'             , ['.dram','.dram.*']],
      ]

    sections = "SECTIONS {\n\n"

    # DMEM sections
    for i, m in enumerate(section_map):
      sec = m[0]
      laddr = '0x1000'
      in_sections = m[1]
      in_objects = '*' if self._default_data_loc == 'dmem' \
                          else '*bsg_manycore_lib.a'

      if re.search(".dram$", sec) != None:
        continue

      if sec != ".dmem":
        laddr = "LOADADDR({0}) + ADDR({1}) - ADDR({0})".format(
            section_map[i-1][0], sec)

      if re.search(".dmem$", sec):
        in_objects = '*'
      else:
        sec += '.dmem'
      
      sections += self._section(sec, laddr, 'DMEM_VMA', None,
          in_sections, in_objects)

    # DRAM sections
    for i,m in enumerate(section_map):
      sec = m[0]
      vaddr = ""
      in_sections = m[1]
      in_objects = '*'

      if re.search(".dmem$", sec) != None:
        continue

      if sec == ".text.dram":
        vaddr = "0x0"

      if re.search(".dram$", sec) == None and self._default_data_loc == 'dram':
        sec += '.dram'

      if self._default_data_loc == 'dram' or re.search(".dram$", sec) != None:
        sections += self._section(sec, vaddr, None, 'DRAM_LMA',
            in_sections, in_objects)

      if sec == '.text.dram':
        sections += ". = . + 0x80000000;\n\n"

    # Symbols
    if self._default_data_loc == 'dmem':
      sections += "_gp = {0};\n".format('ADDR(.sdata.dmem) + 0x800')
    else:
      sections += "_gp = {0};\n".format('ADDR(.sdata.dram) + 0x800')
    sections += "_sp = 0x{0:08x};\n".format(self._sp)
    sections += "_end = {0};\n".format("ADDR(.dram) + SIZEOF(.dram)")
    sections += "_bsg_data_start_addr = 0x{0:08x};\n".format(_DMEM_VMA_START)
    sections += "_bsg_data_end_addr = ADDR(striped.data.dmem) + " \
      "SIZEOF(striped.data.dmem);\n"

    sections += "\n}\n"

    script = self._opening_comment + '\n'
    script += self._memory_regions(mem_regions) + '\n'
    script += sections
    return script


if __name__ == '__main__':
  # Parse arguments
  parser = argparse.ArgumentParser(prog = 'bsg_manycore_link_gen.py',
      formatter_class = argparse.RawDescriptionHelpFormatter,
      description = bsg_manycore_link_gen.__doc__)
  parser.add_argument('--default_data_loc', 
    help = 'Default data location',
    default = 'dmem',
    choices = ['dmem', 'dram'])
  parser.add_argument('--dram_mem_size', 
    help = 'DRAM memory size',
    default = 0x80000000,
    type = int)
  parser.add_argument('--sp', 
    help = 'Stack pointer',
    default = 0x1000,
    type = int)
  args = parser.parse_args()


  # Generate linker script
  link_gen = bsg_manycore_link_gen(args.default_data_loc, args.dram_mem_size,
      args.sp)
  print(link_gen.script())

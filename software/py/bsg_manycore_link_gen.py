#!/usr/bin/python3

import argparse, re
from datetime import datetime

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

  1. Data attributed to .dmem* and .dram* sections. Following declaration

     int foo __attribute__((section (".dram")));

     would place foo in dram region irrespective of default data location.

  2. Data in bsg_manycore_lib will always be placed in dmem region.


  Note on program memory:

  Manycore's PC width is 24-bit, addressing a total of 16MB program space.
  Since the 31:25 MSBs are assumed to be 0s, linking should also assume
  0x0-0x01000000 as the valid program space. This means that .text section VMAs
  lie in 0x0-0x01000000. On the other hand, .text section is loaded to DRAM and
  as result, it's LMAs should be >0x80000000. So, .text section is loaded in the
  region 0x80000000-0x81000000. Consequently, VMA's 0x80000000-0x81000000 are
  are reserved for .text section as well.
  """

  _opening_comment = \
    "/*********************************************************\n" \
    + " BSG Manycore Linker Script \n\n"

  def __init__(self, default_data_loc, dram_size, imem_size, sp):
    self._default_data_loc = default_data_loc
    self._dram_size = dram_size
    self._imem_size = imem_size
    self._sp = sp
    self._opening_comment += \
        " data default: {0}\n".format(default_data_loc) \
        + " dram memory size: 0x{0:08x}\n".format(dram_size) \
        + " imem allocated size: 0x{0:08x}\n".format(imem_size) \
        + " stack pointer init: 0x{0:08x}\n".format(sp) \
        + "\n" \
        + " Generated at " + str(datetime.now()) + "\n" \
      + "**********************************************************/\n"

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
      in_sections, in_objects, boundary=None):
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
    boundary     -- if not None, section includes a boundary check to ensure
                    section can fit within the vma=`boundary`.
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

    if boundary is not None:
        script += "\n  PROVIDE (__{}_end = .);\n".format(name)
        script += "  ASSERT((__{0}_end <= 0x{1:08x}), " \
                  "\"Error: {0} section exceeded limit 0x{1:08x}\");".format(name, boundary)

    script += "\n  . = ALIGN(16);\n"
    script += "\n}} {0} {1}\n\n".format(vma_redirect, lma_redirect)

    return script

  def script(self):
    """
    This generates the link script by linking in two memory regions,
    DMEM_VMA and DRAM_LMA.

    We use the combination of VMA and LMA because `.text` section VMAs and
    dmem memory VMAs overlap with the current memory layout (both start at
    address 0x0). This makes manycore essentially a Harvard architecture.
    But linker doesn't allow overlapping VMAs and doesn't allow location
    couter to move backwards. To overcome this, we use a combination of VMA
    and LMA "memory regions" to be able to never move location counter
    backward.
    """
    # Address constants:
    #
    # LMA (Load Memory Address)    => NPA used by loader
    # VMA (Virtual Memory Address) => Logical address used by linker for
    #                                 symbol resolutions
    _DMEM_VMA_START   = 0x0000
    _DMEM_VMA_SIZE    = 0x1000
    _DRAM_T_LMA_START = 0x80000000
    _DRAM_T_LMA_SIZE  = self._imem_size
    _DRAM_D_LMA_START = 0x80000000 + self._imem_size
    _DRAM_D_LMA_SIZE  = self._dram_size - self._imem_size

    mem_regions = [
      # Format:
      # [<mem region name>, <access>, <start address>, <size>]
      ['DMEM_VMA', 'rw', _DMEM_VMA_START, _DMEM_VMA_SIZE],
      ['DRAM_T_LMA', 'rx', _DRAM_T_LMA_START, _DRAM_T_LMA_SIZE],
      ['DRAM_D_LMA', 'rw', _DRAM_D_LMA_START, _DRAM_D_LMA_SIZE],
      ]

    section_map = [
      # Format:
      # <output section>: [<input sections>]
      ['.text.dram'        , ['.text.interrupt', '.crtbegin','.text','.text.startup','.text.*']],
      # bsg-tommy: 8 bytes are allocated in.dmem.interrupt for interrupt handler to spill registers.
      ['.dmem'             , ['.dmem.interrupt', '.dmem','.dmem.*']],
      ['.data'             , ['.data','.data*']],
      ['.sdata'            , ['.sdata','.sdata.*','.sdata*','.sdata*.*'
                              '.gnu.linkonce.s.*']],
      ['.sbss'             , ['.sbss','.sbss.*','.gnu.linkonce.sb.*','.scommon']],
      ['.bss'              , ['.bss','.bss*']],
      ['.tdata'            , ['.tdata','.tdata*']],
      ['.tbss'             , ['.tbss','.tbss*']],
      ['.striped.data.dmem', ['.striped.data']],
      ['.eh_frame.dram'    , ['.eh_frame','.eh_frame*']],
      ['.rodata.dram'      , ['.rodata','.rodata*','.srodata.cst16','.srodata.cst8',
                              '.srodata.cst4', '.srodata.cst2','.srodata*']],
      ['.dram'             , ['.dram','.dram.*']],
      ]

    sections = "SECTIONS {\n\n"

    # DMEM sections
    for i, m in enumerate(section_map):
      sec = m[0]
      laddr = "0x" + "{:0X}".format(_DMEM_VMA_START)
      in_sections = m[1]

      # Place objects into dmem if default data loc is dmem
      # else only objects from bsg_manycore_lib.a
      if self._default_data_loc == 'dmem':
        in_objects = '*'
      else:
        in_objects = '*bsg_manycore_lib.a:'

      # Skip if the section .dram
      if re.search(".dram$", sec) != None:
        continue

      # All objects from *.dmem go to dmem irrepsective of
      # what self._default_data_loc is
      if re.search(".dmem$", sec):
        in_objects = '*'
      else:
        # Append .dmem to output section name
        sec += '.dmem'

      # This block forms a linker expression that calculates load
      # address of this section.
      #
      # laddr = "laddr of previous section" +
      #           ("virtual address" -
      #              "virtual address of previous section")
      if sec != ".dmem":
        prev_sec = section_map[i-1][0]

        if re.search(".dmem$", prev_sec) == None:
          prev_sec += '.dmem'

        laddr = "LOADADDR({0}) + ADDR({1}) - ADDR({0})".format(
            prev_sec, sec)

      sections += self._section(sec, laddr, 'DMEM_VMA', None,
          in_sections, in_objects)

    # DMEM boundary check
    # Note on a linker quirk: no ';' after the assert when it's not within a section.
    sections += "__dmem_end = .;\n"
    sections += "ASSERT((__dmem_end <= 0x{0:08x}), " \
                "\"Error: dmem size limit exceeded\")\n\n".format(
                        _DMEM_VMA_START + _DMEM_VMA_SIZE);

    # DRAM sections
    for i,m in enumerate(section_map):
      sec = m[0]
      vaddr = ""
      in_sections = m[1]
      in_objects = '*'

      if re.search(".dmem$", sec) != None:
        continue

      # .text section virtual address starts at 0x0 but
      # loaded at 0x80000000
      if sec == ".text.dram":
        vaddr = "0x80000000"

      # Append .dram to output section name
      if re.search(".dram$", sec) == None and self._default_data_loc == 'dram':
        sec += '.dram'

      # Place section in DRAM if the section is *.dram or if the default data
      # location is set to dram.
      if self._default_data_loc == 'dram' or re.search(".dram$", sec) != None:
        boundary = None
        lma_region = 'DRAM_D_LMA'

        if sec == '.text.dram':
            boundary = self._imem_size
            lma_region = 'DRAM_T_LMA'

        sections += self._section(sec, vaddr, None, lma_region,
            in_sections, in_objects, boundary)

      # Skip the size allocated for imem
      if sec == '.text.dram':
          sections += ". = 0x80000000 + 0x{0:08x};\n\n".format(self._imem_size)

    # Symbols

    # global pointer
    if self._default_data_loc == 'dmem':
      sections += "_gp = ADDR(.sdata.dmem) + 0x800;\n"
    else:
      sections += "_gp = ADDR(.sdata.dram) + 0x800;\n"

    # stack pointer
    sections += "_sp = 0x{0:08x};\n".format(self._sp)

    # dmem boundaries
    sections += "_bsg_data_start_addr = 0x{0:08x};\n".format(_DMEM_VMA_START)
    sections += "_bsg_data_end_addr = ADDR(.striped.data.dmem) + " \
                "SIZEOF(.striped.data.dmem);\n"

    # striped data start pointer
    sections += "_bsg_striped_data_start = ADDR(.striped.data.dmem);\n"

    # dram end address
    sections += "_bsg_dram_end_addr = LOADADDR(.dram) + SIZEOF(.dram);\n"

    # heap start point: newlib's malloc uses this symbol
    sections += "_end = _bsg_dram_end_addr;\n"

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
  parser.add_argument('--dram_size',
    help = 'DRAM size',
    default = 0x80000000,
    type = lambda x: int(x, 0))
  parser.add_argument('--imem_size',
    help = 'IMEM size',
    default = 0x01000000, # 16MB
    type = lambda x: int(x, 0))
  parser.add_argument('--sp',
    help = 'Stack pointer',
    default = 0x1000,
    type = lambda x: int(x, 0))
  parser.add_argument('--out',
    help = 'Output file name',
    default = None)
  args = parser.parse_args()


  # Generate linker script
  link_gen = bsg_manycore_link_gen(args.default_data_loc, args.dram_size,
      args.imem_size, args.sp)

  if args.out is None:
    print(link_gen.script())
  else:
    with open(args.out, 'w') as f:
        f.write(link_gen.script())

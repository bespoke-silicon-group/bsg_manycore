# Copyright 2018 Embedded Microprocessor Benchmark Consortium (EEMBC)
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# 
# Original Author: Shay Gal-on
############################################
#  Porting Variables.
#

RISCV_GCC_EXTRA_OPTS ?= -Os

include ../Makefile.include

#############################################
#File : core_portme.mak

# Flag : OUTFLAG
#	Use this flag to define how to to get an executable (e.g -o)
OUTFLAG= -o
# Flag : CC
#	Use this flag to define compiler to use
CC 		= $(RISCV_GCC)
# Flag : LD
#	Use this flag to define compiler to use
LD		= $(RISCV_GCC) -T $(BSG_MANYCORE_DIR)/software/spmd/common/test.ld  -Wl,-Map=link.map
# Flag : AS
#	Use this flag to define compiler to use
AS		= $(RISCV_GCC)  -D__ASSEMBLY__=1
# Flag : CFLAGS
#	Use this flag to define compiler options. Note, you can add compiler options from the command line using XCFLAGS="other flags"
PORT_CFLAGS = -O0 -g $(RISCV_GCC_OPTS) 

FLAGS_STR = "$(XCFLAGS) $(XLFLAGS) $(LFLAGS_END)"
CFLAGS = $(PORT_CFLAGS) -I$(PORT_DIR) -I. -DFLAGS_STR=\"$(FLAGS_STR)\" 
#Flag : LFLAGS_END
#	Define any libraries needed for linking or other flags that should come at the end of the link line (e.g. linker scripts). 
#	Note : On certain platforms, the default clock_gettime implementation is supported but requires linking of librt.
SEPARATE_COMPILE=1
# Flag : SEPARATE_COMPILE
# You must also define below how to create an object file, and how to link.
OBJOUT 	= -o
LFLAGS 	= $(RISCV_LINK_OPTS)
ASFLAGS = -c $(CFLAGS)
OFLAG 	= -o
COUT 	= -c

LFLAGS_END = 
# Flag : PORT_SRCS
# 	Port specific source files can be added here
#	You may also need cvt.c if the fcvt functions are not provided as intrinsics by your compiler!
PORT_SRCS = $(PORT_DIR)/core_portme.c $(PORT_DIR)/ee_printf.c 
PORT_OBJS = $(PORT_DIR)/core_portme.o $(PORT_DIR)/ee_printf.o  \
	    $(PORT_DIR)/bsg_set_tile_x_y.o  $(PORT_DIR)/crt.o

vpath %.c $(PORT_DIR)  $(BSG_MANYCORE_DIR)/software/bsg_manycore/lib
vpath %.s $(PORT_DIR)
vpath %.S $(BSG_MANYCORE_DIR)/software/spmd/common/

# Flag : LOAD
#	For a simple port, we assume self hosted compile and run, no load needed.

# Flag : RUN
#	For a simple port, we assume self hosted compile and run, simple invocation of the executable

LOAD = echo "Please set LOAD to the process of loading the executable to the flash"
RUN = echo "Please set LOAD to the process of running the executable (e.g. via jtag, or board reset)"

OEXT = .o
EXE = .riscv

$(OPATH)$(PORT_DIR)/%$(OEXT) : %.c
	$(CC) $(CFLAGS) $(XCFLAGS) $(COUT) $< $(OBJOUT) $@

$(OPATH)%$(OEXT) : %.c
	$(CC) $(CFLAGS) $(XCFLAGS) $(COUT) $< $(OBJOUT) $@

$(OPATH)$(PORT_DIR)/%$(OEXT) : %.S
	$(AS) $(ASFLAGS) $< $(OBJOUT) $@

# Target : port_pre% and port_post%
# For the purpose of this simple port, no pre or post steps needed.

.PHONY : port_prebuild port_postbuild port_prerun port_postrun port_preload port_postload
port_pre% port_post% : 

# FLAG : OPATH
# Path to the output folder. Default - current folder.
OPATH = ./
MKDIR = mkdir -p
PORT_CLEAN= -rf $(OPATH)*$(OEXT) $(PORT_DIR)/*$(OEXT) \
$(OPATH)coremark_dmem.mem $(OPATH)coremark_dram.mem   \
$(OPATH)csrc $(OPATH)simv $(OPATH)/simv.daidir $(OPATH)ucli.key $(OPATH)vcdplus.vpd $(OPATH)*.map

include ../../mk/Makefile.tail_rules

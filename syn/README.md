# Overview
This directory contains basic synthesis commands for bsg\_manycore. It is not intended to be a full
synthesis flow, but instead provide a set of useful targets for testing an validating the RTL.
Currently, only bsg\_sv2v is supported.

## BSG SV2V

BSG SV2V leverages Synopsys DC to convert a SystemVerilog project to a single "pickled" Verilog-2005 file more easily compatible with open-source tools. Full documentation on the BSG SV2V tool can be found at the [main repo](https://github.com/bespoke-silicon-group/bsg_sv2v). The main command in this directory is:

    make sv2v DESIGN_NAME=<top level>

This grabs the list of verilog sources from the bsg\_manycore repo and a default parameter
list and produces a list of commands to the tool (flist.vcs). It also swaps out memory
wrappers to create blackboxes for memories which must be hardened.

These hardened memories can be found in v/bsg\_mem\_\*. Currently, the I$ (1024x46) and DMEM (1024x32) must be hardened for compute tiles and the Data Mem (512x128), Tag Mem (64x80) and Stat Mem (64x7) must be hardened for vcache tiles.

After running sv2v, the results will be in bsg\_manycore/syn/results. The main file of interest is
<design\_name>.sv2v.v, which contains the pickled verilog file.


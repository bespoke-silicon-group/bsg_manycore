Run [BEEBS](https://github.com/bespoke-silicon-group/beebs) on the manycore:
----------------------------------------------------------------------------

Pre-installation:

- `git submodule update --init --recursive` in bsg_manycore's toplevel directory.

Batch run (run all benchmarks in Makefile.bmarklist):

-  make -j `<threads>`

Individual run (run a single benchmark):

-  make `<benchmark>`.single

Cleanup

-  make clean

Miscellaneous:

- make configure           # required for below rules if you have not already tried to run them

- make `<benchmark>`.riscv # recompile the binary of `<benchmark>`

- make `<benchmark>`.dis   # print disassembly of `<benchmark>` to console

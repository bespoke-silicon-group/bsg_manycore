Run [BEEBS](https://github.com/bespoke-silicon-group/beebs) on the manycore:
----------------------------------------------------------------------------

One time installation:
- `git submodule update --init --recursive` in bsg_manycore's toplevel directory.
- `make install` to install beebs benchmarks. 
- This build all benchmark binaries compiled for manycore in `beeps-build` directory.

Simulation:
- `make <benchmark>.run`: recompile and run VCS simulation of `<benchmark>`
- `make <benchmark>.riscv`: recompile the binary of `<benchmark>`
- `make <benchmark>.dis`: print disassembly of `<benchmark>` to console
- `make` or `make all`: run all benchmarks listed in `Makefile.bmarklist`

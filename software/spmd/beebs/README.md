Run [BEEBS](https://github.com/bespoke-silicon-group/beebs) on the manycore:
----------------------------------------------------------------------------

Installation:
- `make install` to install beebs benchmarks. 
- This build all benchmark binaries compiled for manycore in `beeps-build` directory. This can be only once.

Simulation:
- `make <benchmark>.run`: recompile and run VCS simulation of `<benchmark>`
- `make <benchmark>.riscv`: recompile the binary of `<benchmark>`
- `make <benchmark>.dis`: print disassembly of `<benchmark>` to console
- `make` or `make all`: run all benchmarks listed in `Makefile.bmarklist`

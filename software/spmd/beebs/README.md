Run [BEEBS](https://github.com/bespoke-silicon-group/beebs) on the manycore:
----------------------------------------------------------------------------

`git submodule update --init --recursive` in bsg_manycore's toplevel directory


Batch run:

- `make -j<threads>` to run all Beebs benchmarks listed in `Makefile.bmarklist`


Individual runs:

- One time configuration:
  - `make configure` to configure beebs benchmarks in `beebs-build` directory.

- Simulation:
	- `make <benchmark>.beeb_run`: recompile and run VCS simulation of `<benchmark>`
	- `make <benchmark>.riscv`: recompile the binary of `<benchmark>`
	- `make <benchmark>.dis`: print disassembly of `<benchmark>` to console


Note: Run `make configure` after any changes to Makefiles or link scripts.

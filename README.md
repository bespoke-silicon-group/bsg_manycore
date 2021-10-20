# Overview 

This repo contains the **bsg\_manycore** source code with contributions from the [Bespoke Silicon Group](http://cseweb.ucsd.edu/~mbtaylor/research_team.html) and others.

The tile based architecture is designed for computing efficiency, scalability and generality. The two main components are:

* **Computing Node:** Purpose-designed RISC-V 32IMF compatible core runs at 1.4GHz@16nm, but nodes also can be any other accelerators.
* **Mesh or Ruche Network  :** Dimension ordered, single flit network with inter-nodes synchronization primitives (mutex, barrier etc.)

Without any custom circuits, a 16nm prototype chip with 16x31 tiles on a 4.5x3.4 mm^2 die space achieves **812,350**
aggregated [CoreMark](https://www.eembc.org/coremark/) score, a world record. Many improvements have been made since this previous version.

# Documentation 

1.  Chip gallery, publications, and artworks:
    * See this website: http://bjump.org/manycore/
2.  Bleeding edge features and proceedings:
    * [BaseJump Manycore Accelerator Network](https://docs.google.com/document/d/1-i62N72pfx2Cd_xKT3hiTuSilQnuC0ZOaSQMG8UPkto/edit?usp=sharing) 
        * Version tag: **tile\_group\_org\_master**
        * The mesh network architecture, protocols, constrains and guidelines.
    * [HammerBlade Manycore Technical Reference Manual](https://docs.google.com/document/d/1b2g2nnMYidMkcn6iHJ9NGjpQYfZeWEmMdLeO_3nLtgo/edit?usp=sharing)
        * Version tag: **tile\_group\_org\_master**
        * A more comprehensive document including programming model, FPGA emulation and applications ([TVM](https://tvm.ai)) of manycore.

# Initial Setup for running programs

Above this directory:

- Checkout `basejump_stl`; cd into imports directory and type `make DRAMSim3`
- Checkout `bsg_cadenv` if you are a BSG group member

In this directory:

- `make checkout_submodules`: To update all submodules in `imports/`.
- `make tools`: To install software toolchain required running programs on BSG Manycore. (This build uses 12-16 threads by default.)
- `make machines`: Compile simulation executables in `machines/`.  If you do not have bsg_cadenv, then you will have to set some VCS-related variables.
- Edit `BSG_MACHINE_PATH` in `software/mk/Makefile.paths` to choose the machine to run somd programs on.
- go into `software/spmd/bsg_barrier` and type `make` to run a test!

## Verilator (Beta Support)

BSG Manycore has preliminary support for simulating with the open-source [Verilator](https://github.com/verilator/verilator) toolchain!

To test this feature, set BSG_PLATFORM=verilator in machines/bsg_platform.mk and then follow the
above instructions to run tests normally. This platform only currently supports the machine
pod_1x1_4X2Y due to excessive compilation times for larger machines. Most likely, future work can
enable larger machines with hierarchical Verilation. verilator must be on your path (or override
the VERILATOR variable in machines/Makefile.verilator).

On CentOS, you may need to use a modern GCC installation with `scl enable devtoolset-8 -- bash` or
by putting `source scl_source enable devtoolset-8` in your .basrhc.

## Surelog (Beta Support)

BSG Manycore has preliminary support for parsing with the open-source [Surelog](https://github.com/chipsalliance/SureLog) toolchain!

To test this feature, run `make -C machines parse`. Parse-only module is supported, which verifies
that each file in bsg_manycore can be parsed as an individual compilation unit, in order to provide
the greatest tool compatibility. Future work will enable full UHDM generation.

# Contributions

If you're developing on a branch called `mybranch`, please pull a branch called `ci_mybranch` based
on `mybranch` to run CI and `mybranch`. It's advised to keep working on `mybranch` for incremental
updates and rebase `ci_mybranch` on `mybranch` when it's ready for another CI run.

# Tutorial 

Comming Soon!

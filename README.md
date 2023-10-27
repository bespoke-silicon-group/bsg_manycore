# Overview 

This repo contains the **bsg\_manycore** source code with contributions from the [Bespoke Silicon Group](http://cseweb.ucsd.edu/~mbtaylor/research_team.html) and others.

The tile based architecture is designed for computing efficiency, scalability and generality. The two main components are:

* **Computing Node:** Purpose-designed high-performance core that runs at 1.4GHz@16nm, but nodes also can be any other accelerators.
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

# Getting started

## Prerequisites

### Ubuntu or Debian

To install most dependencies, execute the following command:

    sudo apt install build-essential gawk texinfo bison flex libgmp-dev libmpfr-dev libmpc-dev libz-dev device-tree-compiler cmake

Check the version of your gcc or g++ by the following command:

    gcc --version # or g++ --version

If your gcc/g++ version is 12 or above, you need to downgrade your gcc/g++ or install older version and set alternative version, you may follow [this](https://linuxconfig.org/how-to-switch-between-multiple-gcc-and-g-compiler-versions-on-ubuntu-22-04-lts-jammy-jellyfish) link for more information.

# Initial setup for running programs

NOTE: If you do not have bsg\_cadenv, then you will have to add IGNORE\_CADENV=1 to your make commands. To use commerical tools in this case, you may need
to set some platform-dependent VCS or Xcelium variables. If you do not have access to commerical CAD tools, then we suggest using the free and open-source
Verilator flow described in the section below.

In a scratch directory:

    git clone bsg_manycore
    git clone basejump_stl
    make -C basejump_stl/imports DRAMSim3
    # If a BSG group member
    git clone bsg_cadenv

This should result in your directory looking like the following:

    bsg_manycore/
    basejump_stl/
    bsg_cadenv/ (if BSG member)

In bsg\_manycore:

- `make checkout_submodules`: To update all submodules in `imports/`.
- `make tools`: To install software toolchain required running programs on BSG Manycore. (This build uses 12-16 threads by default.)
- `make machines`: Compile simulation executables in `machines/`.
- Edit `BSG_MACHINE_PATH` in `software/mk/Makefile.paths` to choose the machine to run spmd programs on.
- go into `software/spmd/bsg_barrier` and type `make` to run a test!

## Verilator (Beta Support)

BSG Manycore has preliminary support for simulating with the open-source [Verilator](https://github.com/verilator/verilator) toolchain!

To test this feature, set BSG\_PLATFORM=verilator in machines/platform.mk and then follow the
above instructions to run tests normally. This platform only currently supports the machine
pod\_1x1\_4X2Y due to excessive compilation times for larger machines. Most likely, future work can
enable larger machines with hierarchical Verilation. verilator must be on your path (or override
the VERILATOR variable in machines/Makefile.verilator).

On CentOS, you may need to use a modern GCC installation with `scl enable devtoolset-8 -- bash` or
by putting `source scl_source enable devtoolset-8` in your .bashrc.

## Surelog (Beta Support)

BSG Manycore has preliminary support for parsing with the open-source [Surelog](https://github.com/chipsalliance/SureLog) toolchain!

To test this feature, run `make -C machines parse`. Parse-only module is supported, which verifies
that each file in bsg\_manycore can be parsed as an individual compilation unit, in order to provide
the greatest tool compatibility. Future work will enable full UHDM generation.

# Contributions

If you're developing on a branch called `mybranch`, please pull a branch called `ci_mybranch` based
on `mybranch` to run CI and `mybranch`. It's advised to keep working on `mybranch` for incremental
updates and rebase `ci_mybranch` on `mybranch` when it's ready for another CI run.

# Tutorial 

Comming Soon!

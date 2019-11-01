# Overview 

This repo contains the **bsg\_manycore** source code with contributions from the [Bespoke Silicon Group](http://cseweb.ucsd.edu/~mbtaylor/research_team.html) and others.

The tile based architecture is designed for computing efficiency, scalability and generality. The two main components are:

* **Computing Node:** Purpose-designed RISC-V 32IM compatible core runs at 1.4GHz@16nm, but nodes also can be any other accelerators.
* **Mesh Network  :** Dimension ordered, single flit network with inter-nodes synchronization primitives (mutex, barrier etc.)

Without any customized circuit, a 16nm prototype chip that holds 16x31 tiles on a 4.5x3.4 mm^2 die space achieves **812,350**
aggregated [CoreMark](https://www.eembc.org/coremark/) score.

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

In this directory:

- `make checkout_submodules`: To update all submodules in `imports/`.
- `make tools`: To install software toolchain required running programs on BSG Manycore.
- `make machines`: Compile simulation executables in `machines/`.
- Edit `BSG_MACHINE_PATH` in `software/mk/Makefile.paths` to choose the machine to run somd programs on.

# Contributions

If you're developing on a branch called `mybranch`, please pull a branch called `ci_mybranch` based
on `mybranch` to run CI and `mybranch`. It's advised to keep working on `mybranch` for incremental
updates and rebase `ci_mybranch` on `mybranch` when it's ready for another CI run.

# Tutorial 

Comming Soon!

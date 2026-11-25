# BSG Manycore Software

This directory hosts software insfrasture useful for developing BSG Manycore kernels.
Following is the directory structure:

```
.
├── bsg_manycore_lib   Run-time library with useful macros and functions.
├── manycore-llvm-pass Directory with LLVM passes.
├── mk                 Makefile fragments useful for implementing compilation and simulation flow.
├── nbf                Stale. To be removed.
├── py                 All Python scripts used in this repo.
├── regress            Multi-mode multi-corner (MMMC) regression.
├── riscv-tools        Scripts to install software toolchains.
├── spmd               Collection of low-level SPMD Test programs.
└── tensorlib          Stale. Moved to hb-pytorch. To be removed.
```

## Compiling for BSG Manycore

Include [./mk/Makefile.buildefs](software/mk/Makefile.builddefs) make fragment to import `make` rules for compiling
Manycore programs. Some useful flags to customize compilation are:

- `RISCV_BIN_DIR`:        Path to the RISC-V GNU Toolchain installation. Required flag. Default: None.
- `OPT_LEVEL`:            Compiler optimization level. Default: `-O2`.
- `RISCV_GCC_EXTRA_OPTS`: Extra compilation falgs to be passed to the C compiler.
- `RISCV_GXX_EXTRA_OPTS`: Extra compilation falgs to be passed to the C++ compiler.
- `LINK_SCRIPT`:          Link script for linking kernels. Default is the one generated with 
                          [bsg_manycore_link_gen.py](software/py/bsg_manycore_link_gen.py).
- `RISCV_LINK_OPTS`:      Linker options to be prepended with default options.
- `CLANG`:                Flag to compile with RISC-V LLVM infrastructure instead of GCC.
- `LLVM_DIR`:             Path to LLVM+Clang installation. Requires LLVM >9.0.0. Default: `./riscv-tools/llvm/llvm-install`.
- `ENABLE_LLVM_PASSES`:   Enable Manycore LLVM passes when compiling with `CLANG=1`.

## Cache block management

The vanilla core supports the Zicbom instructions `cbo.inval`, `cbo.clean`,
and `cbo.flush`. Their address is the value of `rs1`, with no immediate offset;
it may point to any byte in a cache block. Only DRAM EVAs (bit 31 set) send a
cache operation. Local data memory, tile-group, global (including host I/O),
and invalid addresses are no-ops, with no packet or error. In simulation, the
core prints a `[WARN][VCORE]` line for each such instruction with the time, the
tile's coordinates, the PC, the operation and the address.

Include `bsg_manycore.h` to use these helpers:

| Helper | Instruction | Effect on the addressed block |
| --- | --- | --- |
| `bsg_cbo_inv_block(p)` | `cbo.inval` | Discard the cached copy, including dirty data, without writeback. |
| `bsg_cbo_clean_block(p)` | `cbo.clean` | Write dirty data back and retain the cached copy. |
| `bsg_cbo_flush_block(p)` | `cbo.flush` | Write dirty data back and invalidate the cached copy. |

`VCACHE_BLOCK_SIZE_BYTES` gives the machine's block size. The helpers accept
an unaligned pointer and act as compiler memory barriers. They use `.insn`, so
an assembler with Zicbom mnemonic support is not required.

The vcaches are shared by all tiles, so `cbo.inval` discards dirty data that
any tile wrote to the block. Only invalidate blocks your code owns entirely.

`bsg_fence()` waits until the vcache has performed each operation. Writebacks
may still be on their way to DRAM at that point, so this orders accesses between
tiles but does not guarantee the data has reached DRAM. Cache block operations
also wait for an outstanding AMO acquire.

`cbo.zero` is not supported. In simulation, the core reports it, and any other
reserved encoding in the CBO space, as an unsupported instruction.

The self-checking [CBO test](spmd/cbo_test) exercises these rules using ordinary
memory accesses and two tiles. Run it on a machine with at least two tiles in X.

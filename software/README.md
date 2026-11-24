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
and invalid addresses are no-ops, with no packet or error.

Include `bsg_manycore.h` to use these helpers:

| Helper | Instruction | Effect on the addressed block |
| --- | --- | --- |
| `bsg_cbo_inv_block(p)` | `cbo.inval` | Discard the cached copy, including dirty data, without writeback. |
| `bsg_cbo_clean_block(p)` | `cbo.clean` | Write dirty data back and retain the cached copy. |
| `bsg_cbo_flush_block(p)` | `cbo.flush` | Write dirty data back and invalidate the cached copy. |

`VCACHE_BLOCK_SIZE_BYTES` gives the machine's block size. The helpers accept
an unaligned pointer and describe the entire containing block to the compiler
as a memory operand, ordering accesses to that block around the instruction.
They use `.insn`, so an assembler with Zicbom mnemonic support is not required.
Use `bsg_fence()` to wait for the operations' returned credits before publishing
completion to another tile. Cache block operations also respect an outstanding
AMO acquire operation. They do not synchronize other tiles automatically.

`cbo.zero` remains unsupported. The decoder's debug-only `unsupported` flag
retains its existing selective coverage; it is not a complete illegal-instruction
detector and does not flag `cbo.zero`.

The self-checking [CBO test](spmd/cbo_test) exercises these rules using ordinary
memory accesses and two tiles. Run it on a machine with at least two tiles in X.

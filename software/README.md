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

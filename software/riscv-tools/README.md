Clean installation of tools:

- `make install-clean`: Install tools in `./riscv-install` directory


For installation preseving builds:

- `make install-with-builds`: Install tools in `./riscv-install` preserving build in 
                              respective source directories.

Misc:

- `make checkout-all`: Clone required repos and apply patches.
- `make build-all`: Compile and install tools in `./riscv-install` directory.
- `make rebuild-newlib`: To re-compile and install Newlib. Useful for Newlib development.
- `make clean-builds`: Remove source and build directories.
- `make clean-llvm`: Remove LLVM source and build directories.
- `make clean-install`: Remove install directories.
- `make clean-all`: Remove everthing created by the Makefile.

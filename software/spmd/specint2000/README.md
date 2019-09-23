SPECInt2000 Benchamarks on Manycore
===================================

- Initial setup:
	`make checkout`
- Benchmarks imported from RAW's greenlight repo
- `rawlib/`: Since `greenlight` was originally written for raw, it uses 
  some raw library functions to run spec benchamrks. This folder
  contains manycore versions of required raw library functions.
- `Makefile.BenChMaRK`: Makefile to run `BenChMaRK`
- `Makefile`: Makefile to run all specint benchmarks

Status:
-------
- 175.vpr: Runs successfully
- 164.gzip: Compilation successful. Runtime issue.
- 300.twolf: Compilation issue; undefined macro
- 186.crafty: Compilation issue; missing struct definition.
- 181.mcf: Runs successfully

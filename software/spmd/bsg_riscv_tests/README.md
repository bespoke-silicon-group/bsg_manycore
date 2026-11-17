`make <instr>.riscv_tests_run` to run a test on individual instructions.

The tests are built from `imports/riscv-tests` as it is, with their fflags and fcsr checks.

If the stale-import check stops, inspect the two files and save any local work before restoring them. The printed checkout command discards all staged and unstaged changes in those files, not just the old patches.

After restoring an old import, run `make clean` here to remove retained test outputs before rerunning. `clean` removes run directories and old touchfiles; it no longer changes the import.

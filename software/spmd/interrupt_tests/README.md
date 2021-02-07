# Interrupt Test Regression Suite

This suite checks interaction of the vanilla core logic with trace and remote interrupts. 

## Summary of Files
1. `*.S`: Files containing RISC-V assembly code testing a specific function.
2. `Makefile.testlist`: A makefile defining a variable `TESTS` that lists all the tests for the regression.
3. `Makefile`: Top-level makefile with targets to run specific tests, the regression suite and observe waveform dumps (in DVE) and coverage reports (in DVE). This integrates with the already existing Makefile setup to run tests/regressions.

## Commands
1. `make <test_name>_run [COVERAGE=1 | WAVE=1]`: Runs a test with name `<test_name>` and dumps the results and log files in a `<test_name>_run` folder. This target can optionally be run with `COVERAGE=1` to turn on coverage for the vanilla core program counter or `WAVE=1` to dump the simulation waveform.<br/>
    Coverage statistics can be found in `coverage/simv.vdb`.<br/>
    Waveform dump can be found in the `<test_name>_run` folder.<br/>
    Example: `make csr_test_run COVERAGE=1`.
2. `make <test_name>_run_wave`: Opens DVE to view the specified waveform.
3. `make cov`: Opens DVE to view coverage statistics. In case of a regression, this displays the merged coverage reports across all tests.
4. `make regress [COVERAGE=1 | WAVE=1]`: Runs a regression and creates per-test dumps in `<test_name>_run` folders. The test suite used for the regression is given in `Makefile.testlist`.
5. `make summary`: Use this command after a regression to view a summary of outputs. This target `greps` the generated log files for critical keywords indicating pass/fail.
6. `make clean`: Cleans the current directory and all build directories.

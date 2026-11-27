SPMD Directory
==============


Writing your own spmd program
-----------------------------
Refer to 'hello/' as an example.
In spmd, the default tile group dimension is the full array. The test should be written so that it works for any size of array.
If not, (i.e. it runs only on a single tile), then specify bsg_tiles_X and bsg_tiles_Y in makefile.

Running single spmd program
---------------------------

In any of the sub-directories:
- `make`: Run VCS simulation.
- `make SPMD_COMPILER=gcc`: Build device C/C++ with GCC (the default).
- `make SPMD_COMPILER=llvm LLVM_DIR=/path/to/llvm-build`: Build device C/C++
  with the HammerBlade LLVM toolchain. The linker and assembler remain from
  the compatible RISC-V GNU installation. Clang emits IR without running its
  internal LLVM optimization pipeline; the explicit `opt` step runs the chosen
  optimization level exactly once.
- `make WAVE=1` Run VCS simulation with waveform dump.
- `make VCS_FGP_THREADS=8`: Run VCS simulation on 9 cores. This is for one long
  simulation: VCS needs that many idle cores and a `VCS-ELITE-RUNTIME` licence.
- `make BSG_PLATFORM=verilator VERILATOR_SIM_THREADS=8`: Run a Verilator model
  built for 8 threads, `<machine>/simsc-t8` (built if it is not there).
- `make main.riscv`: Generate ELF binary of that SPMD program.
- `make COVERAGE=1` Run VCS simulation with coverage analysis.
- `make main.dis`: Print disassembly to the terminal.
- `vanilla.log`: Vanilla core trace, dumped during a `make WAVE=1` simulation.

Note: In directories containing multiple SPMD programs, `bsg_riscv_tests/` for instance,
`main` has to be replaced by the program name. For example, to generate ELF binary of
`add` riscv test, you have to run `make add.riscv`.

Parallel regression
-------------------

`make regress` runs the tests of `make recurse-all`, as many at once as the
host has cores for, with each simulation on cores of its own: one core per
simulator thread, in one socket, taken one last-level cache at a time
(`software/py/sim_cpus.py slots <threads>` prints the layout). On Linux every
simulator thread is pinned to its core; elsewhere the simulations run
unpinned. Each test prints a line when it ends, and its output is in
`recurse-results/<test>-run.log`, as with `recurse-all`. `make regress` fails
if a test does not reach `BSG_FINISH` or reports `BSG_FAIL` or `BSG_TIMEOUT`.

With Verilator, the simulations can be multithreaded. The thread placement is
for the 16x8 pod, and Verilator's default machine is pod_1x1_4X2Y, so give
the 16x8 pod (an absolute path):

    make regress BSG_PLATFORM=verilator VERILATOR_SIM_THREADS=8 \
        BSG_MACHINE_PATH=<bsg_manycore>/machines/pod_1x1

- With 18 cores and one L3 per socket (for example Intel Xeon Gold 6254), two
  simulations run on each socket, on its cores 0-7 and 8-15.
- With eight 4-core chiplets per socket, each with its own L3 (for example AMD
  EPYC 9374F), four run on each socket, each on two whole chiplets: threads
  0-3 of a simulation on one chiplet, threads 4-7 on the other.

Every socket is used: the simulations alternate between sockets, so that
fewer simulations than the host has room for still spread over all of them.

Flags:

- `REGRESS_JOBS=<n>`: Run at most n tests at once. Under VCS every simulation
  takes a licence.
- `REGRESS_TESTS="<test> ..."`: Run only these tests.

The tests that took longest in the previous `make regress` start first. Their
times are in `regress-times`, which `make recurse-clean` keeps.

Coverage Analysis
------------------

Running simulation with COVERAGE=1 will perform coverage analysis on the PC of the vanilla cores. The results of the analysis will be
placed in a directory `coverage/` one-level above the test directory.

Note: For directories with multiple SPMD programs, this behavior is dependent on the way tests are run. If every test is run in its own
sub-directory, the `coverage/` directory is formed within the overall test directory. For example, the `interrupt_tests` directory
creates a sub-directory for each test and therefore, the `coverage` directory will be generated at `interrupt_tests/coverage`.

To view the coverage reports, currently only DVE is supported. Run `make cov_dve` in the same level as the `coverage` directory to
open DVE and report the coverage results. Coverage reports using the URG tool is a work in progress.

Manycore regression
-------------------

RTL regression testing of the manycore.

`make [<flag>=<value>]...`

Some useful flags:

- `GROUP=<group>`: Run only tests in a specific group. `<group>` can be one of the following...
    - `rv32ui`
    - `rv32um`
    - `spmd`
    - `coremark`
    - `beebs`
- `LEVEL=<level>`: Run different levels of regression. `<level>`=1 => group 0, `<level>`=2 => group 0, 1 and so on. **Default is `LEVEL=3`. Level 3 regression suceess is required for changes to be accepted into master.**
- `bsg_tiles_X`:
    Can be used to specify the number of rows to be instantiated. Default
    value provided in individual testcases.
- `bsg_tiles_Y`:
    Can be used to specify the number of columns to be instantiated. Default
    value provided in individual testcases.
- `COVERAGE=VCS`:
    RTL Coverage analysis using VCS. Coverage reports generated using
    Unified Coverage Genrator (URG). Default configuration used for
    the coverage analysis is 4x4. This will be overwritten only when
    above dimension variables are explicitly set.
- `ENABLE_VCACHE={0|1}`:
    include vcache or instead include block SRAM.
- `SPMD_COMPILER={gcc|llvm}`:
    Select the device C/C++ compiler. `CLANG=1` remains a compatibility alias
    for `SPMD_COMPILER=llvm`; new automation should use the explicit selector.

Note: 
    Current design is only tested for x<=4, y<=4 and dimensions mentioned in
    individual testcases.



Uncached IO tests
-----------------

`io_space/`, `io_space_independence/`, `io_inter_tile/`, `io_flood/`, `io_dram_mix/` and `io_vcache_select/` use the
uncached load and the uncached store: the `LOAD` and `STORE` opcodes with funct3 `0b111`. The tests write them with
`.insn`:

    .insn i 0b0000011, 0b111, rd, rs1, 0x0        # rd <- 0(rs1)
    .insn r 0b0100011, 0b111, 0x0, x0, rs1, rs2   # 0(rs1) <- rs2

An uncached request does not go to the DRAM. A vcache passes it on to the IO, which is a separate address space, and
keeps no copy of the word. The IO pod register (CSR `0x361`) selects the pod of that vcache; after reset it holds the
tile's own pod. The address of the request selects the vcache in that pod:

- bit 31: the vcache row, 0 for north and 1 for south.
- the next log2(pod width) bits, from bit 30 down: the vcache column.
- the remaining bits, down to bit 2: the word address that the vcache sends to the IO.

The request leaves the machine on the side that the block requests of that vcache go to, west or east. So the pod,
the row and the column choose the memory port, and any tile can send a request through any vcache.

The IO pod register has the layout of the pod register of the DRAM requests (CSR `0x360`), `{pod y, pod x}`, and is
separate from it: a write to one does not change where the requests of the other go. A program can therefore use the
IO behind another pod while its data stays in the DRAM of its own pod, and the other way around. Both are written
with `csrw`, and a request that follows the write already goes to the new pod.

The store returns when the vcache has queued the word, not when the IO has it. An uncached load through the same
vcache is answered only after the IO has received the stores that this vcache queued before it.

`bsg_fence()` waits until the vcaches have answered all requests of the tile, so after it every uncached store is
queued in its vcache, and may not have reached the IO yet. A program that has to know that the IO has its stores does
an uncached load through the same vcache.

In simulation, `bsg_nonsynth_wormhole_test_mem` answers uncached requests (machines with
`BSG_MACHINE_MEM_CFG = e_vcache_test_mem`). It keeps one IO space for each vcache. The machines with DRAMSim3
(`e_vcache_hbm2`) have no IO: `bsg_wormhole_to_cache_dma_fanout` reports the request and the test does not finish.


`common/`
----------

Common resources used by all SPMD programs.

- `common/crt.S`:
  - C runtime code for BSG Manycore.
  - Intializes stack pointer `sp`, thread pointer `tp` and global pointer `gp`.
  - Initializes rest of the general purpose registers to `0`.
  - Calls `main` function.
  - **Doesn't call a exit routine! SPMD programs should call `bsg_finish()` to exit.**

- `common/link_dmem.ld`:
  - Link script for programs in which data & stack can fit in DMEM.
  - Places all data sections in DMEM, `.dram` section and text sections in DRAM.
  - `sp` is initialized to the end of DMEM -- `0x1ffc`.
  - Data can be placed in DRAM by explcitly attributing it to `.dram` section.
  - **Default link script for programs in this directory.**

- `common/link_dram.ld`:
  - Link script to run larger programs.
  - Places `.dmem` and sections in `bsg_manycore_lib.a` in DMEM and all other sections in DRAM.
  - `sp` is initialized to the end of DRAM -- `0xfffffffc`.

- ELF binaries generated by manycore's link scripts follows memory layout described [here](
https://docs.google.com/document/d/1b2g2nnMYidMkcn6iHJ9NGjpQYfZeWEmMdLeO_3nLtgo/edit#bookmark=id.6ta2llhb2shf).
  
- Special sybmols defined in manycore's link scripts:
  - `_bsg_data_start_addr`: Begin NPA of DMEM data segment.
  - `_bsg_data_end_addr`: End NPA of DMEM data segment.
  - `_bsg_dram_t_start_addr`: Begin NPA of DRAM text segment.
  - `_bsg_dram_t_end_addr`: End NPA of DRAM text segment.
  - `_bsg_dram_d_start_addr`: Begin NPA of DRAM data segment.
  - `_bsg_dram_d_end_addr`: End NPA of DRAM data segment.
  - `_bsg_dram_end_addr`: Heap pointer.
  - `_sp`: Initial stack pointer. `crt.S` uses this symbol to initialize `sp`.
  - `_gp`: Global pointer. `crt.S` uses this symbol to initialize `gp`.

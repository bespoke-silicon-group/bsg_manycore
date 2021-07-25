# PC Profiler

This folder contains an implementation of a PC Profiler along with an example program. The example program computes the fibonacci series and then reads the histogram to see if it matches with the expected histogram.

## Running the PC Profiler

The current implementation of the PC Profiler requires you to use profiler.S instead of the default CRT to enable/disable profiling. An example is given in the Makefile in `software/spmd/pc_profiler`

To run a program with the PC Profiler enabled, use 

`make all PROFILE=1`

Note: Currently the histogram to store the PC Profiler hits is stored in the DRAM. By default, the space reserved is 16 MB. This is a very large number in simulation and takes the SPMD loader a large amount of time to zero out this memory. In order to get quick estimates, modify the `HIST_SPACE` variable. Therefore, the command will now look like - 

`make all PROFILE=1 HIST_SPACE=4096 (4KB histogram space)`

## Items still to be taken care of - 

There are a few items however that needs to be taken care of
- A suitable location in the repository for the profiler code
- A scheme to separate the profiler code (trace interrupt handler) from the CRT itself.

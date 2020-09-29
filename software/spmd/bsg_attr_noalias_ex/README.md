# bsg_attr_noalias Examples

This kernel performs saxpy to demonstrate how the placement of
bsg_attr_noalias affects code generation.

The program here can be built with clang/LLVM (CLANG=1 before `make`)
and GCC (default).

## NOTE:

bsg_attr_noalias is NOT FULLY SUPPORTED IN LLVM. It works for 1D array
accesses, but your mileage may vary with anything more complex.

## Summary

Our goal is to optimize saxpy (Scalar * X Plus Y) by unrolling it
by a factor of 4 to increase performance. Performance gains can be
attributed to two effects: 

1. Increasing the distance between load and use instructions to
hide DRAM latency by informing the compiler about the latency of
(remote) loads

2. Reducing loop control overhead.

In this set of examples we will use bsg\_attr\_noalias.

Simply unrolling the loop will not achieve our goals. First, the
compiler is not allowed to reorder loads and stores unless it can
absolutely determine that the loads and stores are independent --
i.e. they do not alias. Second, it will not have accurate latency
estimates for load/store instructions so it will not put appropriate
distance between load and use instructions and cause dependency stalls.

To solve the aliasing issue, use bsg\_attr\_remote. In general the
compiler cannot infer alias information from pointers just by
analyzing the code. The annotation bsg\_attr\_noalias is required and
is similar to the behavior of \_\_restrict.

## Source

The saxpy source is in two more-or-less identical files:

1. [saxpy-c.c](saxpy-c.c): The C impelementation of saxpy
2. [saxpy-cpp.cpp](saxpy-cpp.cpp): The C++ impelementation of saxpy

The source contains a variety of educational examples, that are
described with comments in the source. The disassembly of each
function of interest is in [snippets](snippets).

You can regenerate the snippets by running `make docs`


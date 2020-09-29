# bsg_attr_remote + bsg_attr_noalias Examples

This program performs saxpy to demonstrate how the placement of
bsg\_attr\_remote AND bsg\_attr\_noalias affect code generation.

For a demonstration of each annotation independently see the
[remote](../remote), and [noalias](../noalias) directories.

The program here can be built with clang/LLVM (CLANG=1 before `make`)
and GCC (default).

## NOTE:

bsg\_attr\_remote currently has no effect in g++. (But it does in gcc,
and clang/clang++)

## Summary

Our goal is to optimize saxpy (Scalar * X Plus Y) by unrolling it
by a factor of 4 to increase performance. Performance gains can be
attributed to two effects: 

1. Increasing the distance between load and use instructions to
hide DRAM latency by informing the compiler about the latency of
(remote) loads

2. Reducing loop control overhead.

In this set of examples we will use bsg\_attr\_remote AND
bsg_attr\_noalias to allow the compiler to achieve 1 and 2.

Simply unrolling the loop will not achieve our goals. First, the
compiler is not allowed to reorder loads and stores unless it can
absolutely determine that the loads and stores are independent --
i.e. they do not alias. Second, it will not have accurate latency
estimates for load/store instructions so it will not put appropriate
distance between load and use instructions and cause dependency stalls.

To solve the aliasing issue, use bsg\_attr\_noalias. In general the
compiler cannot infer alias information from pointers just by
analyzing the code. The annotation bsg\_attr\_noalias is required and
is similar to the behavior of \_\_restrict.

To inform the compiler about expected load latencies use
bsg\_attr\_remote. GCC assumes a normal processor hierarchy with a 1-2
cycle L1 cache. This means that load instructions will be quickly
followed by dependent instructions. When data is located far away in
DRAM or Last-Level Cache, the processor will stall on dependent
instructions while the data (or request) is still in
transit. Therefore, is critical to give the compiler accurate latency
information so that it can schedule appropriately.

## Source

The saxpy source is in two more-or-less identical files:

1. [saxpy-c.c](saxpy-c.c): The C impelementation of saxpy
2. [saxpy-cpp.cpp](saxpy-cpp.cpp): The C++ impelementation of saxpy

The source contains a variety of educational examples, that are
described with comments in the source. The disassembly of each
function of interest is in [snippets](snippets).

You can regenerate the snippets by running `make docs`


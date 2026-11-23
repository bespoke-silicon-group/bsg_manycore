# Y-ruche software barrier test

This SPMD test configures a five-tile, one-column barrier tree directly.
Rows 0 and 4 send to the root at row 2 over RS and RN; rows 1 and 3 use
nearest-neighbor links. It alternates delayed arrivals between the two ruche
leaves for 16 iterations, checking every tile's arrival after each barrier.
A second barrier prevents the next iteration from overwriting those values.
The test times out if a barrier cannot complete.

Run with the repository's RISC-V toolchain and Xcelium:

```sh
make -C software/spmd/hw_barrier_y_ruche_test \
  IGNORE_CADENV=1 XRUN=xrun XMSIM=xmsim MAX_CYCLES=250000
```

The supplied machine uses Y barrier factor 2 and Y data factor 18. The latter
is deliberately larger than the distance between the host and either vcache
row, so boot and host traffic do not use the pod-local Y data links. This
avoids the documented off-pod routing limitation; it does not test Y data
ruche routing. The machine is specific to this test and is not a general
workload configuration. Simulator build products are created in `machine/`.

The test configures its own nine-direction CSR values; it does not add a
general-purpose software initializer for Y-ruche barriers.

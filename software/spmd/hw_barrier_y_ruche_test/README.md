# Y-ruche software barrier test

This SPMD test generates a five-tile, one-column barrier tree with
`bsg_hw_barrier_config_init` and checks its configuration.
Rows 0 and 4 send to the root at row 2 over RS and RN; rows 1 and 3 use
nearest-neighbor links. It alternates delayed arrivals between the two ruche
leaves for 16 iterations, checking every tile's arrival after each barrier.
A second barrier prevents the next iteration from overwriting those values.
The test times out if a barrier cannot complete.

It runs on the `pod_1x1_full` machine (`e_network_full_ruche_xy`, Y data and
barrier ruche factor 2) with any supported simulator, e.g.:

```sh
make -C software/spmd/hw_barrier_y_ruche_test BSG_PLATFORM=verilator
```

Boot, the result stores and the finish packet travel over the Y data ruche
links, including to the host I/O row below the array.

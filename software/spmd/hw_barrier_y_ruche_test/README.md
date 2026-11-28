# Y-ruche software barrier test

This SPMD test generates a one-column barrier tree of 2R+1 tiles with
`bsg_hw_barrier_config_init`, where R is the machine's Y barrier ruche factor
(`BSG_MACHINE_BARRIER_RUCHE_FACTOR_Y`, at least 2). The root is at row R.
Rows 0 and 2R send to it over RS and RN; the rows between use
nearest-neighbor links. The test checks that the configuration forms one tree
rooted at row R, with each tile's input mask matching its children and both
end rows on ruche links. It then alternates delayed arrivals between the two
ruche leaves for 16 iterations, checking every tile's arrival after each
barrier. A second barrier prevents the next iteration from overwriting those
values. The test times out if a barrier cannot complete.

It needs an `e_network_full_ruche_xy` machine with at least 2R+1 rows and runs
with any supported simulator. It defaults to `pod_1x1_full` (R = 2), e.g.:

```sh
make -C software/spmd/hw_barrier_y_ruche_test BSG_PLATFORM=verilator
make -C software/spmd/hw_barrier_y_ruche_test BSG_PLATFORM=verilator \
  BSG_MACHINE_PATH=$PWD/machines/pod_2x2_full_8X16Y   # R = 3
```

Boot, the result stores and the finish packet travel over the Y data ruche
links, including to the host I/O row below the array.

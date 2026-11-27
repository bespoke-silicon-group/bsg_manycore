# Full-ruche compute tiles and arrays

`bsg_manycore_tile_compute_ruche_full` retains the compute socket, registered
reset/coordinates, and X data/barrier links of `bsg_manycore_tile_compute_ruche`.
It adds `ver_ruche_link_i/o` and `ver_barrier_ruche_link_i/o`, indexed by stage
and then N/S. Stage zero connects to RN/RS; other stages cross-feed N/S.

Y forward links omit destination X, reconstructed from the registered tile X.
Y reverse links retain the full packet, including destination X for subsequent
YX routing. This is the same format as `bsg_manycore_tile_vcache_ruche`.
Vanilla P ports retain credit flow control and three-entry input FIFOs.

`bsg_manycore_tile_compute_array_ruche` uses the full tile without changing the
`y[r].x[c].tile` instance path. Its new ports are indexed N/S, column, stage.
North boundary stages connect directly; inter-row and south boundary stages
rotate through `bsg_ruche_buffer`, exactly as on the X axis.

Set `ruche_factor_Y_p >= 2` to enable Y data and barrier links.
`barrier_ruche_factor_Y_p` is an explicit parameter, independently set to a
value >= 2. Vertical barrier ports, wires, stages, and boundary tieoffs use
this factor directly, without a separate lane-count parameter.
Full-ruche barrier CSR directions are
P/W/E/N/S/RW/RE/RN/RS = 0..8, with root selector 9.
`bsg_hw_barrier_config_init` generates the matching tree when built with
`BARRIER_RUCHE_FACTOR_Y` set to the machine's Y barrier factor.

With Y factor zero, the tile retains the X-only router and seven-direction
barrier layout (root selector 7). The unused Y data ports have one placeholder
lane. Set the Y barrier factor to zero too; its direct packed range is then
`[-1:0]`, not a zero-width vector. All disabled Y inputs are ignored and
outputs are zero.
X data and barrier factors must be >= 2 in either mode.

`bsg_manycore_pod_ruche` stitches Y data lanes between compute subarrays and
the north/south vcache rows. `bsg_manycore_tile_vcache_array` uses the Y-ruche
vcache tile and applies the same one-row stage rotation and inversion.
The existing `vc_x[c].vc` instance paths and horizontal DMA network are retained.
Y factor zero selects the original mesh router configuration in these vcaches.

Data lanes terminate outside the two vcache rows using
`bsg_manycore_ruche_y_link_sif_tieoff`, with stage/polarity-aware idle values
and errors for errant forward/return packets. Barrier lanes terminate at the
compute array's north/south edges, since vcaches do not participate in barriers.
Both lane types are pod-local; no Y ruche ports are exposed between pods.
The existing nearest-neighbor vertical pod links are unchanged.
`barrier_ruche_factor_Y_p` is propagated through the pod row/array hierarchy.
Machine builds set it with `BSG_MACHINE_BARRIER_RUCHE_FACTOR_Y` (default 0);
enable it explicitly alongside Y data ruche. The focused tests default the
barrier factor to their data factor as a convenience.

### Routing

Requests are routed XY and responses YX. Once a request turns into Y it takes
local hops until the remaining distance is a multiple of the ruche factor, then
rides a ruche lane to its destination row. A response rides ruche lanes while
it is more than the factor away and finishes with local hops.

Y ruche requires a power-of-two `num_tiles_y_p`, so the south vcache rows
directly follow the compute rows in Y. Pod rows sit two `pod_y` coordinates
apart, so global Y skips `G = num_tiles_y_p - 2*num_vcache_rows_p` values
between one pod row's south vcache rows and the next pod row's north vcache
rows. The ruche lanes join the physically adjacent rows, but the router counts
the gap as `G` extra rows. With more than one pod row this routes correctly
only when `G == 0`, or when `G` is a multiple of `ruche_factor_Y_p` and
`ruche_factor_Y_p <= num_vcache_rows_p`:

- A `G` that is not a multiple of the factor shifts requests onto a ruche lane
  that misses their destination.
- A factor larger than `num_vcache_rows_p` lets a response overshoot the first
  compute row past the gap. Vcaches never receive responses, so the vcache
  rows absorb the error otherwise.

`G` is even, so a factor of 2 works whenever `num_vcache_rows_p >= 2`.
`bsg_manycore_pod_ruche_full_array` checks this at simulation start. The
comment in `bsg_manycore_mesh_node` describes how to lift the restriction
without changing the BaseJump STL router, by translating Y coordinates to
physical rows where packets enter and leave the network.

- `e_network_full_ruche_xy` stitches Y lanes between pod rows and connects the
  south lanes to a ruche-capable host I/O row
  (`bsg_manycore_io_router_ruche_y`), so inter-pod and host traffic use them.
- `e_network_half_ruche_x` with Y ruche keeps lanes pod-local, so requests to
  an off-pod destination, including the host, can reach a boundary tieoff,
  which reports an error. Keep Y factor zero there for workloads that need
  off-pod traffic.

## Regression

Run with Xcelium and the sibling BaseJump STL checkout:

```sh
make -C testbenches/compute_ruche run RUCHE_FACTOR_Y=3
make -C testbenches/compute_ruche run \
  TOP=test_bsg_manycore_tile_compute_array_ruche RUCHE_FACTOR_Y=3
```

Repeat with factors 2 and 0, and optionally an independent barrier factor:

```sh
make -C testbenches/compute_ruche run \
  TOP=test_bsg_manycore_tile_compute_array_ruche \
  RUCHE_FACTOR_Y=2 BARRIER_RUCHE_FACTOR_Y=3
```

Use `BUILD_DIR` to put simulator outputs outside the source tree. Tile tests
isolate both sides of the processor endpoint and control barrier configuration.
They check both Y directions, compression, stalls/draining, passive X/Y stages,
X routing, and three-packet P credit return on both networks. Array tests check
every Y wire/stage/polarity, actual Y ruche hops on XY requests and YX responses
across two columns, and a delayed-arrival barrier in both sense phases.

Pod routing tests isolate the processor/cache endpoints, send requests from
both ends of a 2x4 compute array to the opposite vcache row, and send responses
back to a different X coordinate. They verify real Y ruche hops, stalls/draining,
boundary termination, and a delayed-arrival barrier across subarrays:

```sh
make -C testbenches/compute_ruche run \
  TOP=test_bsg_manycore_pod_ruche RUCHE_FACTOR_Y=3
make -C testbenches/compute_ruche run \
  TOP=test_bsg_manycore_pod_ruche \
  RUCHE_FACTOR_Y=2 BARRIER_RUCHE_FACTOR_Y=3 SUBARRAY_X=1 SUBARRAY_Y=4
```

`SUBARRAY_X/Y` select the pod test's hierarchy split (defaults 2x2); 1x1,
2x2 and 1x4 cover single-subarray, multi-column, and single-row subarrays.
Factors 0, 2 and 3 cover backward compatibility and both ruche parities.

For a full-system SPMD test of both Y barrier directions, see
[`hw_barrier_y_ruche_test`](../../software/spmd/hw_barrier_y_ruche_test/README.md).

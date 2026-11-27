# Y ruche vcache tile

`bsg_manycore_tile_vcache_ruche` is a variant of
`bsg_manycore_tile_vcache`, used by `bsg_manycore_tile_vcache_array`.
It adds `ruche_factor_Y_p >= 2` and packed
`[max(1,ruche_factor_Y_p)-1:0][S:N]` `ver_ruche_link_i/o` ports. Stage 0 connects to
the router's RN/RS ports; later stages feed through to the opposite side.
The router uses four dimensions with E/W and RE/RW stubbed. Factor zero selects
the original two-dimensional mesh router; unused Y outputs are zero and the
placeholder input lane is ignored.

Y forward links omit destination X, reconstructed from the registered tile X.
Source X is preserved for responses. Reverse packets are uncompressed because
YX response routing still needs destination X. The combined Y link therefore
saves `x_cord_width_p` bits. Shared interface/conversion macros are in
[`bsg_manycore_defines.svh`](../../v/bsg_manycore_defines.svh).

The vcache array rotates/buffers the south-side stages, while the ruche pod
stitches these lanes to compute subarrays and terminates them outside each
vcache row. Boundary tieoffs account for stage-dependent inversion and diagnose
errant packets. In `e_network_half_ruche_x` pods, Y ruche lanes do not cross
pod boundaries and the router has no boundary-aware fallback for off-pod
destinations (including the host), so such traffic can reach a tieoff.
`e_network_full_ruche_xy` stitches the lanes between pod rows and adds a
ruche-capable host I/O row. See [routing](../compute_ruche/README.md#routing).

Run the focused Xcelium test with a matching BaseJump STL checkout:

```sh
make -C testbenches/vcache_ruche run RUCHE_FACTOR_Y=2
make -C testbenches/vcache_ruche run RUCHE_FACTOR_Y=3
```

`XRUN`, `BASEJUMP_STL_DIR`, and `BUILD_DIR` can be overridden. The test isolates
the cache-side router interface and checks N/S delivery, local-to-ruche and
ruche-to-ruche forwarding, response routing to a different X coordinate,
backpressure, and feedthrough for both ruche networks.

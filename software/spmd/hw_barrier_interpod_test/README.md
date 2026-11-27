# Inter-pod hardware barrier test

This SPMD test runs one hardware barrier over every compute tile of every pod.
It launches in all pods, with one tile group covering each whole pod. Barrier
links skip the vcache rows, so the compute tiles of all pods form one
`(pods_X*tiles_X) x (pods_Y*tiles_Y)` barrier grid. Tile 0 of each pod builds
that grid's tree with `bsg_hw_barrier_config_init`. The tree's root is at the
grid center, so leaves reach it over barrier links that cross pod boundaries.

Each tile finds its pod by writing every pod's `pod_id` at its own (x,y); the
value depends only on the target pod, so writes from different pods agree.

Each of 8 iterations delays one corner tile of the grid. After the barrier,
every tile checks that the late tile and the tile diagonally opposite itself
have both arrived. A second barrier keeps the next iteration from overwriting
the values before they are read. A barrier that releases early fails the test;
one that never completes times out.

On `pod_2x2_full_8X16Y` (barrier ruche X 2, Y 3) the tree crosses pod
boundaries over 32 local and 32 ruche X links and one local and one ruche Y
link; the release travels back over the same links.

```sh
make -C software/spmd/hw_barrier_interpod_test BSG_PLATFORM=verilator
```

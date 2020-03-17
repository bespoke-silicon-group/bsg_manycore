// bsg_tile_config_vars defines per-tile variables that are used when
// launching execution on a tile. Some variables are only relevant to
// CUDA-Lite programs

// __bsg_x: X coordinate (relative to the group's origin tile)
// __bsg_y: Y coordinate (relative to the group's origin tile)
// __bsg_id: Unique ID for each tile in a group
//           (__bsg_id = __bsg_y * __bsg_tile_group_dim_x + __bsg_x)
// __bsg_grp_org_x: Global X coordinate of the group origin tile
// __bsg_grp_org_y: Global Y coordinate of the group origin tile
// __bsg_grid_dim_x: Global Grid X-Dimension
// __bsg_grid_dim_y: Global Grid Y-Dimension
// __bsg_tile_group_id_x: Tile-Group X ID (X-coordinate of current grid iteration)
// __bsg_tile_group_id_y: Tile-Group Y ID (X-coordinate of current grid iteration)
// __bsg_tile_group_id: Unique ID for each tile group
//          (__bsg_tile_group_id = __bsg_tile_group_id_y * __bsg_grid_dim_x + __bsg_tile_group_id_x)

int __bsg_x = -1;
int __bsg_y = -1;
int __bsg_id = -1;
int __bsg_grp_org_x = -1;
int __bsg_grp_org_y = -1;
int __bsg_grid_dim_x = -1;
int __bsg_grid_dim_y = -1;
int __bsg_tile_group_id_x = -1;
int __bsg_tile_group_id_y = -1;
int __bsg_tile_group_id = -1;

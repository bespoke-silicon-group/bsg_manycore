// bsg_tile_config_vars.h defines per-tile variables that are used
// when launching execution on a tile. Some variables are only
// relevant to CUDA-Lite programs. The actual definitions are in
// bsg_tile_config_vars.c

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

#ifndef __BSG_TILE_CONFIG_VARS_H
#define __BSG_TILE_CONFIG_VARS_H

extern int __bsg_x;               //The X Cord inside a tile group
extern int __bsg_y;               //The Y Cord inside a tile group
extern int __bsg_id;              //The ID of a tile in tile group
extern int __bsg_grp_org_x;       //The X Cord of the tile group origin
extern int __bsg_grp_org_y;       //The Y Cord of the tile group origin
extern int __bsg_grid_dim_x;      //The X Dimensions of the grid of tile groups
extern int __bsg_grid_dim_y;      //The Y Dimensions of the grid of tile groups
extern int __bsg_tile_group_id_x; //The X Cord of the tile group within the grid
extern int __bsg_tile_group_id_y; //The Y Cord of the tile group within the grid
extern int __bsg_tile_group_id;   //The flat ID of the tile group within the grid

#endif // __BSG_TILE_CONFIG_VARS_H

#ifndef __BSG_TILE_CONFIG_VARS_H
#define __BSG_TILE_CONFIG_VARS_H

extern int __bsg_x;               //The X Cord inside a tile group
extern int __bsg_y;               //The Y Cord inside a tile group
extern int __bsg_id;              //The ID of a tile in tile group
extern int __bsg_grp_org_x;       //The X Cord of the tile group origin
extern int __bsg_grp_org_y;       //The Y Cord of the tile group origin
extern int __bsg_grid_dim_x;	  //The X Dimensions of the grid of tile groups
extern int __bsg_grid_dim_y;	  //The Y Dimensions of the grid of tile groups
extern int __bsg_tile_group_id_x; //The X Cord of the tile group within the grid
extern int __bsg_tile_group_id_y; //The Y Cord of the tile group within the grid
extern int __bsg_tile_group_id;   //The flat ID of the tile group within the grid

#endif // __BSG_TILE_CONFIG_VARS_H

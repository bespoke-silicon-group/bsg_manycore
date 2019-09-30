/* Each application launched onto the manycore is represented by a grid of tile groups.        */
/* A grid is a two diemsnional structure represeting the entire application, with each         */
/* element of grid being a tile group with X and Y coordinates bsg_tile_group_id_x/y,          */
/* and the flat coordiante of bsg_tile_group_id, which is calculate using grid dimensions      */
/* __bsg_x               --> The X coordinate of tile inside its tile group                    */
/* __bsg_y               --> The Y coordiante of tile inside its tile group                    */
/* __bsg_id              --> The flat index of tile inside tile group                          */
/*                            __bsg_id = __bsg_y * __bsg_tiles_X + __bsg_x                     */
/* __bsg_grp_org_x       --> The X coordinate of the tile group origin tile                    */
/* __bsg_grp_org_y       --> The Y coordinate of the tile group origin tile                    */
/* __bsg_grid_dim_x      --> X dimension of grid, or number of tile groups in the X dimensions */
/* __bsg_grid_dim_y      --> Y dimension of grid, or number of tile groups in the Y dimensions */
/* __bsg_tile_group_id_x --> X coordinate of tile group within the application's grid          */
/* __bsg_tile_group_id_y --> Y coordinate of tile group within the application's grid          */
/* __bsg_tile_group_id_x --> flat index of tile group within the application's grid            */
/*                            __bsg_tile_group_id = __bsg_tile_group_id_y * __bsg_grid_dim_x   */
/*                                                  + __bsg_tile_group_id_x                    */

extern int __bsg_x;               //The X Cord inside a tile group
extern int __bsg_y;               //The Y Cord inside a tile group
extern int __bsg_id;              //The ID of a tile in tile group
extern int __bsg_grp_org_x;       //The X Cord of the tile group origin
extern int __bsg_grp_org_y;       //The Y Cord of the tile group origin
extern int __bsg_grid_dim_x;	  //The X Dimensions of the grid of tile groups
extern int __bsg_grid_dim_y;	  //The Y Dimensions of the grid of tile groups
extern int __bsg_tile_group_id_x; //The X Cord of the tile group within the grid
extern int __bsg_tile_group_id_y; //The Y Cord of the tile group within the grid
extern int __bsg_tile_group_id;   //The flat tile group id within the grid

//----------------------------------------------------------
//bsg_x and bsg_y is going to be deprecated.
//We define the bsg_x/bsg_y only for compatibility purpose
#define bsg_x __bsg_x
#define bsg_y __bsg_y
#define bsg_id __bsg_id

void bsg_set_tile_x_y();

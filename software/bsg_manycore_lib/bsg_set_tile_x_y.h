extern int __bsg_x;             //The X Cord inside a tile group
extern int __bsg_y;             //The Y Cord inside a tile group
extern int __bsg_id;            //The ID of a tile in tile group
extern int __bsg_grp_org_x;     //The X Cord of the tile group origin
extern int __bsg_grp_org_y;     //The Y Cord of the tile group origin

//----------------------------------------------------------
//bsg_x and bsg_y is going to be deprecated.
//We define the bsg_x/bsg_y only for compatibility purpose
#define bsg_x __bsg_x
#define bsg_y __bsg_y
#define bsg_id __bsg_id

int bsg_set_tile_x_y();

// The intent of this file is to provide a simple, templated method
// for striding between the scratchpads of tiles in a tile group
//
// The following example strides horizontally between the foo variable
// in a tile group:
//    int foo;
//    bsg_tile_group_strider<bsg_tiles_X, 1, bsg_tiles_Y, 0, int> stride_x(foo, 0, 0);
//
// The following example strides vertically with a tile stride of 1 in
// a tile group:
//    int foo;
//    bsg_tile_group_strider<bsg_tiles_X, 0, bsg_tiles_Y, 1, int> stride_y(foo, 0, 0);
//
// The following example moves diagonally with a horizontal tile
// stride of 1, and a vertical tile stride of 1 between tiles in a
// tile group:
//    int foo;
//    bsg_tile_group_strider<bsg_tiles_X, 1, bsg_tiles_Y, 1, int> stride_y(foo, 0, 0);
//
// Use the stride() method to get an updated pointer after construction.
//
// When the strider reaches the end of a tile group it wraps back
// around to 0 -- i.e. mod.

// NOTE: THIS STRIDER ONLY WORKS WITH TILE GROUPS THAT ARE A POWER OF
// TWO IN THE DIMENSION(S) OF STRIDING.

#ifndef __BSG_GROUP_STRIDER
#define __BSG_GROUP_STRIDER

#include <bsg_manycore.h>
#include <bsg_set_tile_x_y.h>

#include <math.h>

#define BSG_TILE_GROUP_X_DIM bsg_tiles_X
#define BSG_TILE_GROUP_Y_DIM bsg_tiles_Y
#define BSG_TILE_GROUP_LOG_Y_DIM ((int)(log2(BSG_TILE_GROUP_Y_DIM)))
#define BSG_TILE_GROUP_LOG_X_DIM ((int)(log2(BSG_TILE_GROUP_X_DIM)))

#define MAKE_MASK(WIDTH) ((1UL << (WIDTH)) - 1UL)
// TG_X/Y -- Tile Group X/Y Dimension
// S_X/Y -- Number of tiles to stride X/Y dimension
// T -- Type of underlying pointer.
template<unsigned int TG_X, unsigned int S_X, unsigned int TG_Y, unsigned int S_Y, typename T>
class bsg_tile_group_strider{
        static const unsigned int GROUP_EPA_WIDTH = REMOTE_EPA_WIDTH;
        static const unsigned int GROUP_X_COORD_WIDTH = REMOTE_X_CORD_WIDTH;
        static const unsigned int GROUP_Y_COORD_WIDTH = REMOTE_Y_CORD_WIDTH;
        static const unsigned int GROUP_X_COORD_SHIFT = (GROUP_EPA_WIDTH);
        static const unsigned int GROUP_Y_COORD_SHIFT = (GROUP_X_COORD_SHIFT+GROUP_X_COORD_WIDTH);
        static const unsigned int GROUP_PREFIX_SHIFT = (GROUP_Y_COORD_SHIFT+GROUP_Y_COORD_WIDTH);

        static const unsigned int Y_STRIDE = (1 << GROUP_Y_COORD_SHIFT);
        static const unsigned int X_STRIDE = (1 << GROUP_X_COORD_SHIFT);
        static const unsigned int Y_MASK = ~(MAKE_MASK(GROUP_Y_COORD_WIDTH - (unsigned int)(log2(TG_Y))) << ((unsigned int)(log2(TG_Y)) + GROUP_Y_COORD_SHIFT));
        static const unsigned int X_MASK = ~(MAKE_MASK(GROUP_X_COORD_WIDTH - (unsigned int)(log2(TG_X))) << ((unsigned int)(log2(TG_X)) + GROUP_X_COORD_SHIFT));

protected:
public:
        T *ptr;
        // x/y_off starting stride offsets in the horizontal and
        // vertical directions.
        bsg_tile_group_strider(T *p, int x_off, int y_off){
                ptr =(T*)( ((1 << GROUP_PREFIX_SHIFT)
                            | (y_off << GROUP_Y_COORD_SHIFT)
                            | (x_off << GROUP_X_COORD_SHIFT)
                            | ((unsigned int) p)));
        }

        // Execute a stride operation and return a pointer to the new
        // location.
        T* stride(){
                if(S_X == 0){
                        return ptr = (T*)(((unsigned int) ptr + Y_STRIDE) & Y_MASK);
                } else if(S_Y == 0){
                        return ptr = (T*)(((unsigned int) ptr + X_STRIDE) & X_MASK);
                } else {
                        return ptr = (T*)(((((unsigned int) ptr + X_STRIDE) & X_MASK) + Y_STRIDE) & Y_MASK);
                }
        }

};

#endif

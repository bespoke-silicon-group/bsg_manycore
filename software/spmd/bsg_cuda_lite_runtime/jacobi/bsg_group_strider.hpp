#ifndef __BSG_GROUP_STRIDER
#define __BSG_GROUP_STRIDER
#define BSG_TILE_GROUP_LOG_Y_DIM ((int)(log2(BSG_TILE_GROUP_Y_DIM)))
#define BSG_TILE_GROUP_LOG_X_DIM ((int)(log2(BSG_TILE_GROUP_X_DIM)))
#define MAKE_MASK(WIDTH) ((1UL << (WIDTH)) - 1UL)
template<unsigned int TG_X, unsigned int S_X, unsigned int TG_Y, unsigned int S_Y, typename T>
class bsg_tile_group_strider{
        static const unsigned int GROUP_EPA_WIDTH = 18;
        static const unsigned int GROUP_X_CORD_WIDTH = 6;
        static const unsigned int GROUP_Y_CORD_WIDTH = 5;
        static const unsigned int GROUP_X_CORD_SHIFT = (GROUP_EPA_WIDTH);
        static const unsigned int GROUP_Y_CORD_SHIFT = (GROUP_X_CORD_SHIFT+GROUP_X_CORD_WIDTH);
        static const unsigned int GROUP_PREFIX_SHIFT = (GROUP_Y_CORD_SHIFT+GROUP_Y_CORD_WIDTH);

        static const unsigned int Y_STRIDE = (1 << GROUP_Y_CORD_SHIFT);
        static const unsigned int X_STRIDE = (1 << GROUP_X_CORD_SHIFT);
        static const unsigned int Y_MASK = ~(MAKE_MASK(GROUP_Y_CORD_WIDTH - (unsigned int)(log2(TG_Y))) << ((unsigned int)(log2(TG_Y)) + GROUP_Y_CORD_SHIFT));
        static const unsigned int X_MASK = ~(MAKE_MASK(GROUP_X_CORD_WIDTH - (unsigned int)(log2(TG_X))) << ((unsigned int)(log2(TG_X)) + GROUP_X_CORD_SHIFT));

protected:
public:
        T *ptr;
        bsg_tile_group_strider(T *p, int x, int y){
                ptr =(T*)( ((1 << GROUP_PREFIX_SHIFT)
                            | (y << GROUP_Y_CORD_SHIFT)
                            | (x << GROUP_X_CORD_SHIFT)
                            | ((unsigned int) p)));
        }

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

#ifndef __BSG_SHARED_MEM_HPP_
#define __BSG_SHARED_MEM_HPP_

extern "C" {
#include <bsg_manycore.h>
#include <bsg_manycore.hpp>
#include <bsg_tile_group_barrier.hpp>
}
#include <cstdlib>
#include <cmath>

namespace bsg_manycore {
    /**
     * Offset from DMEM[0] = local address - DMEM beginning address (0x1000)
     *                       =    <12-s>      -   <s-2>    -    00
     *                             ADDR         Stripe 
     * s = log2(Stripe Length)
     *
     * PREFIX    -    HASH (STRIPE SIZE)    -    UNUSED    -    ADDR    -    Y    -    X    -    Stripe    -    00
     *  <5>                  <4>            -   <11-x-y>   -  <12 - s>  -   <y>   -   <x>   -    <s-2>     -    <2>
     * Stripe is lowest bits of offset from local dmem
     *
     */

    template <typename TYPE, std::size_t SIZE, std::size_t TG_DIM_X, std::size_t TG_DIM_Y, std::size_t STRIPE_SIZE=1>
    class TileGroupSharedMem {
    public:

        // Harware tile group shared memory is only supported in tile groups 
        // with power of 2 x,y dimensions
        static_assert (is_powerof2(TG_DIM_X), "While using hardware shared memory, tile group X dimension should be power of 2");
        static_assert (is_powerof2(TG_DIM_Y), "While using hardware shared memory, tile group Y dimension should be power of 2");

        static constexpr std::size_t TILES = TG_DIM_X * TG_DIM_Y;
        static constexpr std::size_t STRIPES = SIZE/STRIPE_SIZE + SIZE%STRIPE_SIZE;
        static constexpr std::size_t STRIPES_PER_TILE = (STRIPES/TILES) + (STRIPES%TILES == 0 ? 0 : 1);
        static constexpr std::size_t ELEMENTS_PER_TILE = STRIPES_PER_TILE * STRIPE_SIZE;

        static constexpr uint32_t DMEM_START_ADDR = 0x1000;       // Beginning of DMEM
        static constexpr uint32_t SHARED_PREFIX = 0x1;            // Tile group shared memory EVA prefix
        static constexpr uint32_t HASH = cilog2(STRIPE_SIZE); // Hash code representing the stripe size

        static constexpr uint32_t LOCAL_OFFSET_BITS = 12;         // # of Bits used for 
        static constexpr uint32_t MAX_X_BITS = 6;                 // Maximum bits needed for X coordinate
        static constexpr uint32_t MAX_Y_BITS = 5;                 // Maximum bits needed for X coordinate
        static constexpr uint32_t HASH_BITS = 4;                  // Bits used for EVA to NPA hash

        static constexpr uint32_t HASH_SHIFT = LOCAL_OFFSET_BITS + MAX_X_BITS + MAX_Y_BITS;
        static constexpr uint32_t SHARED_PREFIX_SHIFT = HASH_SHIFT + HASH_BITS;

        static constexpr uint32_t X_BITS = cilog2(TG_DIM_X);
        static constexpr uint32_t Y_BITS = cilog2(TG_DIM_Y);

        // For stripe sizes of 2 and 4, GCC doesn't comply for some reason
        // So we temporarily set alignment to 8 for these stripe sizes
        static constexpr uint32_t ALIGN_STRIPE = ((STRIPE_SIZE == 2 || STRIPE_SIZE == 4) ? 8 : STRIPE_SIZE);
        static constexpr uint32_t ALIGNMENT = cilog2(sizeof(TYPE) * ALIGN_STRIPE);



        TileGroupSharedMem() {
            uint32_t local_offset = this->local_addr() - DMEM_START_ADDR; // Local address of array
            uint32_t word = local_offset &  ~3;
            uint32_t byte = local_offset &   3;
            uint32_t _address = ( byte |
                                  (word << (X_BITS + Y_BITS))  |
                                  (HASH << HASH_SHIFT)                 |
                                  (SHARED_PREFIX << SHARED_PREFIX_SHIFT) );

            _addr = reinterpret_cast<TYPE*> (_address);
        };


        std::size_t size() const { return SIZE; }
        std::size_t stripe_size() const { return STRIPE_SIZE; }

        TYPE operator[](std::size_t i) const {
            return _addr[i];
        }

        TYPE & operator[](std::size_t i) {
            return _addr[i];
        }

        uint32_t local_addr() {
            return reinterpret_cast<uint32_t> (_data);
        } 

        TYPE* addr() {
            return _addr;
        }


        // Reduce (sum) all elements in tile group shared memory
        // and store in first element. We perform reduction in this loop,
        // starting from an offset of 1 and a multiplicand of 2:
        // For every element with index multiplicand of 2: A[i] <-- A[i] + A[i+1]
        // For every element with index multiplicand of 4: A[i] <-- A[i] + 2
        // For every element with index multiplicand of 8: A[i] <-- A[i] + 4
        // .... Continue until offset is larger that array size ....
        // Example
        // |1|1|1|1|1|1|1|1|   Offset: 1  - Mult: 2
        //  |/  |/  |/  |/
        // |2|1|2|1|2|1|2|1|   Offset: 2  - Mult: 4
        //  |  /   |  /  
        //  | /    | /
        //  |/     |/
        // |4|1|2|1|4|1|2|1|   Offset: 4  - Mult: 8
        //  |       /
        //  |      /
        //  |     /
        //  |    /
        //  |   /
        //  |  /
        //  | /
        //  |/
        // |8|1|2|1|4|1|2|1|
        void reduce(bsg_barrier<TG_DIM_X, TG_DIM_Y> &barrier) {

            int offset = 1;
            int mult = 2;

            while (offset < SIZE) {
                for (int iter_x = bsg_id; iter_x < SIZE; iter_x += TILES) {
                    if (!(iter_x % mult)){
                        (*this)[iter_x] += (*this)[iter_x + offset];
                    }
                }
                
                barrier.sync();
               
                mult <<= 1;
                offset <<= 1;
            }
            return;
        }

       
    private:
        // Local address should be aligned by a factor of data type times stripe size
        TYPE _data [ELEMENTS_PER_TILE] __attribute__ ((aligned (1 << ALIGNMENT)));
        TYPE *_addr;
    };
}

#endif // __BSG_SHARED_MEM_HPP_

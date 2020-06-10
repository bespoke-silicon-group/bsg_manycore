#pragma once
extern "C" {
#include "bsg_manycore.h"
}
#include <cstdlib>
#include <cmath>

namespace bsg_manycore {
    /**
     *
     *
     *   Offset from DMEM[0] = local address - DMEM beginning address (0x1000)
     *                       =    <12-n>      -   <n-2>    -    00
     *                             ADDR         Stripe 
     *
     *   n = log2(Stripe Size)
     *
     *   
     *   PREFIX    -    HASH (STRIPE SIZE)    -    UNUSED    -    ADDR    -    Y    -    X    -    Stripe    -    00
     *    <5>                  <4>            -   <11-x-y>   -  <12 - n>  -   <y>   -   <x>   -    <n-2>     -    <2>
     *
     * Stripe is lowest bits of offset from local dmem
     *
     *
     * TODO: type of addresses should be int or uint32_t not TYPE
     * TODO: return error if address is larger than 12 bits
     * TODO: return error if index is larger than array size
     * TODO: Assert tile group dimensions are power of two
     */
    template <typename TYPE, std::size_t SIZE, std::size_t TG_DIM_X, std::size_t TG_DIM_Y, std::size_t STRIPE_SIZE=1>
    class TileGroupSharedMem {
    public:
        static constexpr std::size_t TILES = TG_DIM_X * TG_DIM_Y;
        static constexpr std::size_t STRIPES = SIZE/STRIPE_SIZE + SIZE%STRIPE_SIZE;
        static constexpr std::size_t STRIPES_PER_TILE = (STRIPES/TILES) + (STRIPES%TILES == 0 ? 0 : 1);
        static constexpr std::size_t ELEMENTS_PER_TILE = STRIPES_PER_TILE * STRIPE_SIZE;

        static constexpr uint32_t DMEM_START_ADDR = 0x1000;    // Beginning of DMEM
        static constexpr uint32_t SHARED_PREFIX = 0x1;         // Tile group shared memory EVA prefix
        static constexpr uint32_t HASH = 0x0;                  // Hash code representing the stripe size

        static constexpr uint32_t LOCAL_OFFSET_BITS = 12;      // # of Bits used for 
        static constexpr uint32_t MAX_X_BITS = 6;              // Maximum bits needed for X coordinate
        static constexpr uint32_t MAX_Y_BITS = 5;              // Maximum bits needed for X coordinate
        static constexpr uint32_t HASH_BITS = 4;               // Bits used for EVA to NPA hash

        static constexpr uint32_t HASH_SHIFT = LOCAL_OFFSET_BITS + MAX_X_BITS + MAX_Y_BITS;
        static constexpr uint32_t SHARED_PREFIX_SHIFT = HASH_SHIFT + HASH_BITS;

        static constexpr uint32_t X_BITS = ceil(log2(TG_DIM_X));
        static constexpr uint32_t Y_BITS = ceil(log2(TG_DIM_Y));

        static constexpr uint32_t ALIGNMENT = ceil(log2(sizeof(TYPE) * STRIPE_SIZE));



        TileGroupSharedMem() {
            _local_addr = reinterpret_cast<TYPE> (_data);                  // Local address of array
            TYPE _local_offset = _local_addr - DMEM_START_ADDR;            // Offset from DMEM[0]

            TYPE _address = ( (_local_offset << (X_BITS + Y_BITS)) |
                              (HASH << HASH_SHIFT)                 |
                              (SHARED_PREFIX << SHARED_PREFIX_SHIFT) );

            _addr = reinterpret_cast<TYPE*> (_address);
        };


        std::size_t size() const { return SIZE; }
        std::size_t stripe_size() const { return STRIPE_SIZE; }

        TYPE* operator[](std::size_t i) const {
            return &(_addr[i]);
        }

        TYPE* operator[](std::size_t i) {
            return &(_addr[i]);
        }


        // Correct code
        // To replace the above code when hardware is added
//        TYPE operator[](std::size_t i) const {
//            return _addr[i];
//        }
//
//        TYPE operator[](std::size_t i) {
//            return _addr[i];
//        }

       
//        constexpr bool is_powerof2(int v) {
//            return v && ((v & (v - 1)) == 0);
//        }

//    private:
        // Local address should be aligned by a factor of data type times stripe size
        TYPE _data [ELEMENTS_PER_TILE] __attribute__ ((aligned (1 << ALIGNMENT)));
        TYPE _local_addr;
        TYPE *_addr;
    };
}

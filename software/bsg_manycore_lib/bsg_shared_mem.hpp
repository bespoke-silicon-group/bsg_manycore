#pragma once
extern "C" {
#include "bsg_manycore.h"
}
#include <cstdlib>
#include <math.h>

namespace bsg_manycore {
    /**
     *
     *
     *   Offset from DMEM[0] = local address - DMEM beginning address (0x1000)
     *                       =    <LSB>      -   <MSB>    -    00
     *                             ADDR         Stripe 
     *
     *   
     *   PREFIX    -    HASH (STRIPE SIZE)    -    ADDR    -    Y    -    X    -    Stripe    -    00
     *    <5>                  <4>            -  <12 - n>  -   <5>   -   <6>   -    <n-2>     -    <2>
     *
     * Stripe is lowest bits of offset from local dmem
     *
     *
     * TODO: type of addresses should be int or uint32_t not TYPE
     * TODO: return error if address is larger than 12 bits
     * TODO: return error if index is larger than array size
     */
    template <typename TYPE, std::size_t SIZE, std::size_t TG_DIM_X, std::size_t TG_DIM_Y, std::size_t STRIPE_SIZE=1>
    class TileGroupSharedMem {
    public:
        static constexpr std::size_t TILES = TG_DIM_X * TG_DIM_Y;
        static constexpr std::size_t STRIPES = SIZE/STRIPE_SIZE + SIZE%STRIPE_SIZE;
        static constexpr std::size_t STRIPES_PER_TILE = (STRIPES/TILES) + (STRIPES%TILES == 0 ? 0 : 1);
        static constexpr std::size_t ELEMENTS_PER_TILE = STRIPES_PER_TILE * STRIPE_SIZE;
        static constexpr std::size_t HASH = STRIPE_SIZE;

        static constexpr uint32_t DMEM_START_ADDR = 0x1000;                                  // Beginning of DMEM
        static constexpr uint32_t SHARED_PREFIX = 0x1;                                       // Tile group shared memory EVA prefix

        static constexpr uint32_t WORD_ADDR_BITS = 2;                                        // Word addresable bits
        static constexpr uint32_t STRIPE_BITS = ceil(log2(STRIPE_SIZE)) + WORD_ADDR_BITS;    // Number of bits used for STRIPE 
        static constexpr uint32_t MAX_X_BITS = 6;                                            // Destination tile's X bits
        static constexpr uint32_t MAX_Y_BITS = 5;                                            // Destination tile's Y bits
        static constexpr uint32_t LOCAL_ADDR_BITS = 12 - STRIPE_BITS;                        // Local offset from Dmem[0] bits
        static constexpr uint32_t HASH_BITS = 4;                                             // Hash function bits
        static constexpr uint32_t PREFIX_BITS = 5;                                           // Tile group shared memory prefix bits

        static constexpr uint32_t X_SHIFT = STRIPE_BITS;                   
        static constexpr uint32_t Y_SHIFT = X_SHIFT + MAX_X_BITS;                         
        static constexpr uint32_t LOCAL_ADDR_SHIFT = Y_SHIFT + MAX_Y_BITS;                
        static constexpr uint32_t HASH_SHIFT = LOCAL_ADDR_SHIFT + LOCAL_ADDR_BITS;        
        static constexpr uint32_t SHARED_PREFIX_SHIFT = HASH_SHIFT + HASH_BITS;           

        static constexpr uint32_t STRIPE_MASK = (1 << STRIPE_BITS) - 1;
        static constexpr uint32_t LOCAL_ADDR_MASK = (1 << LOCAL_ADDR_BITS) - 1;



        TileGroupSharedMem() {
            _local_addr = reinterpret_cast<TYPE> (_data);                  // Local address of array
            TYPE _local_offset = _local_addr - DMEM_START_ADDR;            // Offset from DMEM[0]

            TYPE _address = ( ((_local_offset & STRIPE_MASK))                                             |
                              (((_local_offset >> STRIPE_BITS) & LOCAL_ADDR_MASK) << LOCAL_ADDR_SHIFT)    |
                              (HASH << HASH_SHIFT)                                                             |
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


//    private:

        TYPE _data [ELEMENTS_PER_TILE];
        TYPE _local_addr;
        TYPE *_addr;
    };
}

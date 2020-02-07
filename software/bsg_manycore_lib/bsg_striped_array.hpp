#pragma once
extern "C" {
#include "bsg_manycore.h"
}
#include <cstdlib>

namespace bsg_manycore {
    /**
     * An array that is distributed across tilegroup members' local memories.
     *
     * @tparam TYPE  The element type of the array.
     * @tparam TG_DIM_X The number of columns in the tile group.
     * @tparam TG_DIM_Y The number of rows in the tile group.
     * @tparam STRIPE_SIZE The number of consecutive elements that fall on the same tile.
     *
     * Used to build an array that is distributed across tilegroup members' local memories.
     * Elements are interleaved across tiles according to the STRIPE_SIZE parameter.
     * For example, if STRIPE_SIZE = 2, then array[0] and array[1] will be co-located on tile 0,
     * array[2] and array[3] will be co-located on the tile 1, etc.
     *
     * This is class does not mark the data as volatile.
     * While this frees the compiler to make the same standard optimizations it would for any data
     * that lives in memory, it can lead to some confusing bugs that occur when the compiler is unaware
     * of a program's multi-threaded environment.
     *
     * For an example see bsg_manycore/software/spmd/bsg_cuda_lite/striped_volatile/kernel_striped.cpp
     *
     * For the programmer's convenience we provide the VolatileTileGroupStripedArray class which should
     * be used when the programs correctness is sensitive to a thread observing updates to the array data
     * from other tiles.
     */
    template <typename TYPE, std::size_t SIZE, std::size_t TG_DIM_X, std::size_t TG_DIM_Y, std::size_t STRIPE_SIZE=1>
    class TileGroupStripedArray {
    public:
        static constexpr std::size_t TILES = TG_DIM_X * TG_DIM_Y;
        static constexpr std::size_t STRIPES = SIZE/STRIPE_SIZE + SIZE%STRIPE_SIZE;
        static constexpr std::size_t STRIPES_PER_TILE = (STRIPES/TILES) + (STRIPES%TILES == 0 ? 0 : 1);
        static constexpr std::size_t ELEMENTS_PER_TILE = STRIPES_PER_TILE * STRIPE_SIZE;

        TileGroupStripedArray() {}

        std::size_t size() const { return SIZE; }
        std::size_t stripe_size() const { return STRIPE_SIZE; }

        TYPE operator[](std::size_t i) const {
            return *_address(i);

        }

        TYPE & operator[](std::size_t i) {
            return *_address(i);
        }

        TYPE at_local(std::size_t i) const {
            return _data[i];
        }

        TYPE & at_local(std::size_t i) {
            return _data[i];
        }

    private:
        std::size_t _stripe(std::size_t i) const {
            return i / STRIPE_SIZE;
        }

        std::size_t _word_in_stripe(std::size_t i) const {
            return i % STRIPE_SIZE;
        }

        std::size_t _tile(std::size_t stripe) const {
            return stripe % TILES;
        }

        std::size_t _stripe_in_tile(std::size_t stripe) const {
            return stripe / TILES;
        }

        TYPE * _address(std::size_t i) const {
            std::size_t stripe = _stripe(i);
            std::size_t word_in_stripe  = _word_in_stripe(i);
            std::size_t tile = _tile(stripe);
            std::size_t stripe_in_tile = _stripe_in_tile(stripe);

            TYPE *ptr = const_cast<TYPE*>(
                reinterpret_cast<volatile TYPE*>(
                    bsg_remote_ptr(bsg_id_to_x(tile),
                                   bsg_id_to_y(tile),
                                   &_data[stripe_in_tile * STRIPE_SIZE + word_in_stripe])
                    )
                );

            return ptr;
        }


        TYPE _data [ELEMENTS_PER_TILE];
    };

    /**
     * An array that is distributed across tilegroup members' local memories.
     *
     * @tparam TYPE  The element type of the array.
     * @tparam TG_DIM_X The number of columns in the tile group.
     * @tparam TG_DIM_Y The number of rows in the tile group.
     * @tparam STRIPE_SIZE The number of consecutive elements that fall on the same tile.
     *
     * Used to build an array that is distributed across tilegroup members' local memories.
     * Elements are interleaved across tiles according to the STRIPE_SIZE parameter.
     * For example, if STRIPE_SIZE = 2, then array[0] and array[1] will be co-located on tile 0,
     * array[2] and array[3] will be co-located on the tile 1, etc.
     */
    template <typename TYPE, std::size_t SIZE, std::size_t TG_DIM_X, std::size_t TG_DIM_Y, std::size_t STRIPE_SIZE=1>
    using VolatileTileGroupStripedArray = TileGroupStripedArray<volatile TYPE, SIZE, TG_DIM_X, TG_DIM_Y, STRIPE_SIZE>;

}

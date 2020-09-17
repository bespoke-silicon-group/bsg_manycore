//====================================================================
// Utilies to distribute work in blocks of tiles
// 07/28/2020 Bandhav Veluri
//====================================================================

#ifndef _HB_BLOCKED_FOR_HPP
#define _HB_BLOCKED_FOR_HPP

// ================================================================
// HB Blocked for
//
// Distributes work in blocks of tiles along a tensor axis of size N.
// If N >= tg_size, each index can only be handled on by one tile,
// so block size would be 1. If N < tg_size, blocksize could be
// greater than one, meaning each index would be handled by 
// multiple tiles. This function passes block size to the loop 
// which can used to recusively distribute work among the sub block
// of tiles.
// =================================================================

template<typename F>
inline void hb_blocked_for(size_t tg_size, size_t N, F functor) {
  size_t block_size, start, end;
  size_t tile_id = __bsg_id % tg_size;

  if(N >= tg_size) {
    size_t split = N / tg_size + 1;
    block_size = 1;
    start = split * tile_id;
    end = start + split;
    end = (end > N) ? N : end;
  } else {
    block_size = tg_size / N;
    start = tile_id / block_size;
    end = (start >= N) ? start : start + 1;
  }

  for(size_t i = start; i < end; ++i)
    functor(i, block_size);
}

#endif

// =========================================================
// HB Spatial For
// 
// 07/19/2020 Bandhav Veluri
// =========================================================

// ---------------------------------------------------------
// HB 2D spatial for
// ---------------------------------------------------------
template <class FetchFunctor>
inline void hb_spatial_for(size_t N, size_t M, FetchFunctor functor) {
  //---------------------------------------------------
  // calculate x dimension start and end for this tile
  //---------------------------------------------------
  size_t len_per_tile = N / bsg_tiles_X + 1;
  size_t start_x = len_per_tile * __bsg_x;
  size_t end_x = start_x + len_per_tile;
  end_x = (end_x > N)  ? N : end_x;

  //---------------------------------------------------
  // calculate Y dimension start and end for this tile
  //---------------------------------------------------
  len_per_tile = M / bsg_tiles_Y + 1;
  size_t start_y = len_per_tile * __bsg_y;
  size_t end_y = start_y + len_per_tile;
  end_y = (end_y > M)  ? M : end_y;

  for (size_t i = start_x; i < end_x; i++) {
    for (size_t j = start_y; j < end_y; j++) {
      functor(i, j);
    }
  }
}

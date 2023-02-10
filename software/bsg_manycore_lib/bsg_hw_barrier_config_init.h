/**
 *    bsg_hw_barrier_config_init.h
 *
 */


#ifndef BSG_HW_BARRIER_CONFIG_INIT_H
#define BSG_HW_BARRIER_CONFIG_INIT_H


//  Initialize HW barrier configuration array for a tile group size (x,y).
//  This can be used either by the manycore tile or by the host to save icache footprint.
// arr =  location of array
// tx  =  x-dim of tile group
// ty  =  y-dim of tile group


#define OUTDIR_OFFSET 16

static void bsg_hw_barrier_config_init(int *arr, int tx, int ty) {

  // center tile coordinate
  int center_x = (tx/2);
  int center_y = (ty/2);

  for (int x = 0; x < tx; x++) {
    for (int y = 0; y < ty; y++) {
  
      // tile id
      int id = x + (y*tx);
 
      // input P is always on.
      int val = 1;

      // setting output dir
      if (x <= center_x - BARRIER_RUCHE_FACTOR_X) {
        // output = RE
        val |= (6 << OUTDIR_OFFSET);
      } else if ((x < center_x) && (x > (center_x - BARRIER_RUCHE_FACTOR_X))) {
        // output = E
        val |= (2 << OUTDIR_OFFSET);
      } else if (x == center_x) {
        if (y < center_y) {
          // output = S
          val |= (4 << OUTDIR_OFFSET);
        } else if (y == center_y) {
          // output = Root
          val |= (7 << OUTDIR_OFFSET);
        } else {
          // output = N
          val |= (3 << OUTDIR_OFFSET);
        }
      } else if ((x > center_x) && (x < (center_x + BARRIER_RUCHE_FACTOR_X))) {
        // output = W
        val |= (1 << OUTDIR_OFFSET);
      } else {
        // output = RW
        val |= (5 << OUTDIR_OFFSET);
      }   

      // setting input mask
      // input = W
      if (((center_x-x) < BARRIER_RUCHE_FACTOR_X-1) && (x <= center_x)  && (x > 0)) {
        val |= (1 << 1);
      }

      // input = RW
      if (((x - BARRIER_RUCHE_FACTOR_X) >= 0) && (x <= center_x)) {
        val |= (1 << 5);
      }

      // input = E
      if (((x-center_x) < BARRIER_RUCHE_FACTOR_X-1) && (x >= center_x) && (x < (tx-1))) {
        val |= (1 << 2);
      }

      // input = RE
      if (((x+BARRIER_RUCHE_FACTOR_X) < tx) && (x >= center_x)) {
        val |= (1 << 6);
      }

      if (x == center_x) {
        // input = N
        if ((y > 0) && (y <= center_y)) {
          val |= (1 << 3);
        }
        // input = S
        if ((y < (ty-1)) && (y >= center_y)) {
          val |= (1 << 4);
        }
      }

  
      // save
      arr[id] = val;
    }
  }
}

#endif

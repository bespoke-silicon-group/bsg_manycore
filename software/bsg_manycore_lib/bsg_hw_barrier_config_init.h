/**
 *    bsg_hw_barrier_config_init.h
 *
 */


#ifndef BSG_HW_BARRIER_CONFIG_INIT_H
#define BSG_HW_BARRIER_CONFIG_INIT_H

#ifndef BARRIER_RUCHE_FACTOR_X
#error "BARRIER_RUCHE_FACTOR_X must be defined (0 for mesh barriers)"
#endif

#ifndef BARRIER_RUCHE_FACTOR_Y
#define BARRIER_RUCHE_FACTOR_Y 0
#endif

#if BARRIER_RUCHE_FACTOR_Y < 0 || BARRIER_RUCHE_FACTOR_Y == 1
#error "BARRIER_RUCHE_FACTOR_Y must be 0 or at least 2"
#endif

#if BARRIER_RUCHE_FACTOR_Y > 0 && BARRIER_RUCHE_FACTOR_X < 2
#error "Y-ruche barriers require BARRIER_RUCHE_FACTOR_X of at least 2"
#endif
//  Initialize HW barrier configuration array for a tile group size (x,y).
//  This can be used either by the manycore tile or by the host to save icache footprint.
// arr =  location of array
// tx  =  x-dim of tile group
// ty  =  y-dim of tile group
// X = 0 selects a five-direction mesh barrier; Y > 0 selects nine directions.


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
#if BARRIER_RUCHE_FACTOR_X == 0
      if (x < center_x) {
        val |= (2 << OUTDIR_OFFSET);
      } else if (x > center_x) {
        val |= (1 << OUTDIR_OFFSET);
      } else {
        if (y < center_y) {
          val |= (4 << OUTDIR_OFFSET);
        } else if (y == center_y) {
          val |= (5 << OUTDIR_OFFSET);
        } else {
          val |= (3 << OUTDIR_OFFSET);
        }
      }

      if ((x > 0) && (x <= center_x)) {
        val |= (1 << 1);
      }
      if ((x < tx-1) && (x >= center_x)) {
        val |= (1 << 2);
      }
#else
      if (x <= center_x - BARRIER_RUCHE_FACTOR_X) {
        // output = RE
        val |= (6 << OUTDIR_OFFSET);
      } else if ((x < center_x) && (x > (center_x - BARRIER_RUCHE_FACTOR_X))) {
        // output = E
        val |= (2 << OUTDIR_OFFSET);
      } else if (x == center_x) {
#if BARRIER_RUCHE_FACTOR_Y > 0
        if (y <= center_y - BARRIER_RUCHE_FACTOR_Y) {
          val |= (8 << OUTDIR_OFFSET); // RS
        } else if (y < center_y) {
          val |= (4 << OUTDIR_OFFSET); // S
        } else if (y == center_y) {
          val |= (9 << OUTDIR_OFFSET); // Root
        } else if (y < center_y + BARRIER_RUCHE_FACTOR_Y) {
          val |= (3 << OUTDIR_OFFSET); // N
        } else {
          val |= (7 << OUTDIR_OFFSET); // RN
        }
#else
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
#endif
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
#endif

      if (x == center_x) {
#if BARRIER_RUCHE_FACTOR_Y > 0
        if (((center_y-y) < BARRIER_RUCHE_FACTOR_Y-1) && (y <= center_y) && (y > 0)) {
          val |= (1 << 3);
        }
        if ((y - BARRIER_RUCHE_FACTOR_Y >= 0) && (y <= center_y)) {
          val |= (1 << 7);
        }
        if (((y-center_y) < BARRIER_RUCHE_FACTOR_Y-1) && (y >= center_y) && (y < ty-1)) {
          val |= (1 << 4);
        }
        if ((y + BARRIER_RUCHE_FACTOR_Y < ty) && (y >= center_y)) {
          val |= (1 << 8);
        }
#else
        // input = N
        if ((y > 0) && (y <= center_y)) {
          val |= (1 << 3);
        }
        // input = S
        if ((y < (ty-1)) && (y >= center_y)) {
          val |= (1 << 4);
        }
#endif
      }

  
      // save
      arr[id] = val;
    }
  }
}

#endif

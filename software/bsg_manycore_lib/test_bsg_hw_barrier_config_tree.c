#include <assert.h>
#include <stdlib.h>
#include "bsg_hw_barrier_config_init.h"

enum { P, W, E, N, S, RW, RE, RN, RS };

static void check_tree(int tx, int ty)
{
  int config[tx * ty];
  int inputs[tx * ty];
  const int cx = tx / 2;
  const int cy = ty / 2;
#if BARRIER_RUCHE_FACTOR_Y > 0
  const int root = 9;
#elif BARRIER_RUCHE_FACTOR_X > 0
  const int root = 7;
#else
  const int root = 5;
#endif

  bsg_hw_barrier_config_init(config, tx, ty);
  for (int i = 0; i < tx * ty; i++) {
    inputs[i] = 1 << P;
  }

  for (int y = 0; y < ty; y++) {
    for (int x = 0; x < tx; x++) {
      int dir = config[x + y * tx] >> OUTDIR_OFFSET;
      int px = x, py = y, incoming = -1;
      if (x == cx && y == cy) {
        assert(dir == root);
        continue;
      }
      assert(dir != root);
      switch (dir) {
        case W:  px--; incoming = E; break;
        case E:  px++; incoming = W; break;
        case N:  py--; incoming = S; break;
        case S:  py++; incoming = N; break;
        case RW: px -= BARRIER_RUCHE_FACTOR_X; incoming = RE; break;
        case RE: px += BARRIER_RUCHE_FACTOR_X; incoming = RW; break;
        case RN: py -= BARRIER_RUCHE_FACTOR_Y; incoming = RS; break;
        case RS: py += BARRIER_RUCHE_FACTOR_Y; incoming = RN; break;
        default: assert(0);
      }
      assert(px >= 0 && px < tx && py >= 0 && py < ty);
      assert(abs(px - cx) + abs(py - cy) < abs(x - cx) + abs(y - cy));
      inputs[px + py * tx] |= 1 << incoming;
    }
  }

  for (int i = 0; i < tx * ty; i++) {
    assert((config[i] & 0xffff) == inputs[i]);
  }
}

int main(void)
{
  for (int tx = 1; tx <= 13; tx++) {
    for (int ty = 1; ty <= 13; ty++) {
      check_tree(tx, ty);
    }
  }

#if BARRIER_RUCHE_FACTOR_Y > 0
  const int factor = BARRIER_RUCHE_FACTOR_Y;
  int config[2 * factor + 1];
  bsg_hw_barrier_config_init(config, 1, 2 * factor + 1);
  assert((config[0] >> OUTDIR_OFFSET) == RS);
  assert((config[2 * factor] >> OUTDIR_OFFSET) == RN);
  assert((config[factor] & ((1 << RN) | (1 << RS))) == ((1 << RN) | (1 << RS)));
#endif
  return 0;
}

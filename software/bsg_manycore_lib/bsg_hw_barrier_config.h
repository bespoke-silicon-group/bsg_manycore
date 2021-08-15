// barcfg for half-ruche (ruche x =3) network.

#ifndef BSG_HW_BARRIER_CONFIG_H
#define BSG_HW_BARRIER_CONFIG_H

int barcfg_4x4[16] __attribute__ ((section (".dram"))) = {
  // p->e       pw->e       pwe->s        p->w
  0x20001,      0x20003,    0x40007,      0x10001,
  // p->e       pw->e       pwens->R      p->w
  0x20001,      0x20003,    0x7001f,      0x10001,
  // p->e       pw->e       pwes->n       p->w
  0x20001,      0x20003,    0x30017,      0x10001,
  // p->e       pw->e       pwe->n        p->w
  0x20001,      0x20003,    0x30007,      0x10001
};

int barcfg_16x8[128] __attribute__ ((section (".dram"))) = {
  //0       1         2         3         4         5         6         7         8           9         10        11        12        13        14        15
  //p->E    p->E      p->E      pW->E     pW->E     pW->E     pW->e     pwW->e    pWEwe->s    peE->w    pE->w     pE->W     pE->W     p->W      p->W      p->W
  0x60001,  0x60001,  0x60001,  0x60021,  0x60021,  0x60021,  0x20021,  0x20023,  0x40067,    0x10045,  0x10041,  0x50041,  0x50041,  0x50001,  0x50001,  0x50001,
  //p->E    p->E      p->E      pW->E     pW->E     pW->E     pW->e     pwW->e    pWEwen->s   peE->w    pE->w     pE->W     pE->W     p->W      p->W      p->W
  0x60001,  0x60001,  0x60001,  0x60021,  0x60021,  0x60021,  0x20021,  0x20023,  0x4006f,    0x10045,  0x10041,  0x50041,  0x50041,  0x50001,  0x50001,  0x50001,
  //p->E    p->E      p->E      pW->E     pW->E     pW->E     pW->e     pwW->e    pWEwen->s   peE->w    pE->w     pE->W     pE->W     p->W      p->W      p->W
  0x60001,  0x60001,  0x60001,  0x60021,  0x60021,  0x60021,  0x20021,  0x20023,  0x4006f,    0x10045,  0x10041,  0x50041,  0x50041,  0x50001,  0x50001,  0x50001,
  //p->E    p->E      p->E      pW->E     pW->E     pW->E     pW->e     pwW->e    pWEwen->s   peE->w    pE->w     pE->W     pE->W     p->W      p->W      p->W
  0x60001,  0x60001,  0x60001,  0x60021,  0x60021,  0x60021,  0x20021,  0x20023,  0x4006f,    0x10045,  0x10041,  0x50041,  0x50041,  0x50001,  0x50001,  0x50001,
  //p->E    p->E      p->E      pW->E     pW->E     pW->E     pW->e     pwW->e    pWEwens->R  peE->w    pE->w     pE->W     pE->W     p->W      p->W      p->W
  0x60001,  0x60001,  0x60001,  0x60021,  0x60021,  0x60021,  0x20021,  0x20023,  0x7007f,    0x10045,  0x10041,  0x50041,  0x50041,  0x50001,  0x50001,  0x50001,
  //p->E    p->E      p->E      pW->E     pW->E     pW->E     pW->e     pwW->e    pWEwes->n   peE->w    pE->w     pE->W     pE->W     p->W      p->W      p->W
  0x60001,  0x60001,  0x60001,  0x60021,  0x60021,  0x60021,  0x20021,  0x20023,  0x30077,    0x10045,  0x10041,  0x50041,  0x50041,  0x50001,  0x50001,  0x50001,
  //p->E    p->E      p->E      pW->E     pW->E     pW->E     pW->e     pwW->e    pWEwes->n   peE->w    pE->w     pE->W     pE->W     p->W      p->W      p->W
  0x60001,  0x60001,  0x60001,  0x60021,  0x60021,  0x60021,  0x20021,  0x20023,  0x30077,    0x10045,  0x10041,  0x50041,  0x50041,  0x50001,  0x50001,  0x50001,
  //p->E    p->E      p->E      pW->E     pW->E     pW->E     pW->e     pwW->e    pWEwe->n    peE->w    pE->w     pE->W     pE->W     p->W      p->W      p->W
  0x60001,  0x60001,  0x60001,  0x60021,  0x60021,  0x60021,  0x20021,  0x20023,  0x30067,    0x10045,  0x10041,  0x50041,  0x50041,  0x50001,  0x50001,  0x50001
};


#endif

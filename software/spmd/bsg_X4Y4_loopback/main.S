
#ifndef bsg_tiles_X
#error bsg_tiles_X must be defined
#endif

#ifndef bsg_tiles_Y
#error bsg_tiles_Y must be defined
#endif

#if bsg_tiles_X == 1
#define bsg_noc_xbits 1
#elif bsg_tiles_X == 2
#define bsg_noc_xbits 1
#elif bsg_tiles_X == 3
#define bsg_noc_xbits 2
#elif bsg_tiles_X == 4
#define bsg_noc_xbits 2
#elif bsg_tiles_X == 5
#define bsg_noc_xbits 3
#elif bsg_tiles_X == 6
#define bsg_noc_xbits 3
#elif bsg_tiles_X == 7
#define bsg_noc_xbits 3
#elif bsg_tiles_X == 8
#define bsg_noc_xbits 3
#elif bsg_tiles_X == 9
#define bsg_noc_xbits 4
#elif bsg_tiles_X == 16
#define bsg_noc_xbits 4
#elif
#error Unsupported bsg_tiles_X
#endif

#if bsg_tiles_Y == 1
#define bsg_noc_ybits 1
#elif bsg_tiles_Y == 2
#define bsg_noc_ybits 2
#elif bsg_tiles_Y == 3
#define bsg_noc_ybits 2
#elif bsg_tiles_Y == 4
#define bsg_noc_ybits 3
#elif bsg_tiles_Y == 5
#define bsg_noc_ybits 3
#elif bsg_tiles_Y == 6
#define bsg_noc_ybits 3
#elif bsg_tiles_Y == 7
#define bsg_noc_ybits 3
#elif bsg_tiles_Y == 8
#define bsg_noc_ybits 4
#elif bsg_tiles_Y == 9
#define bsg_noc_ybits 4
#elif bsg_tiles_Y == 16
#define bsg_noc_ybits 5
#elif
#error Unsupported bsg_tiles_Y
#endif

#define bsg_remote_ptr(x,y,local_addr)(      (1<<31)                                   \
                                           | ((y) << (31-(bsg_noc_ybits)))             \
                                           | ((x) << (31-bsg_noc_xbits-bsg_noc_ybits)) \
                                           | (local_addr)                              \
                                       )


#define FINISH_ADDR    bsg_remote_ptr( 0x3, bsg_tiles_Y, 0xDEAD0)
#define DM_START       0x1000

.text 
li          a0,  FINISH_ADDR   ;
sw          zero,0x0( a0 )     ;

li          a1,  DM_START      ;
lr.w        t0,  0x0(a1)       ;
lr.w.aq     t0,  0x0(a1)       ;

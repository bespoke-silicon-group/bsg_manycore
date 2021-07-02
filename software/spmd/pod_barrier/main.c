// does a pod barrier in 87 cycles

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

#define BSG_TILE_GROUP_X_DIM bsg_tiles_X
#define BSG_TILE_GROUP_Y_DIM bsg_tiles_Y
//#define BSG_BARRIER_DEBUG
#include "bsg_tile_group_barrier.h"


typedef struct _bsg_pod_barrier_ {
  int col[2];
  int row[4];
  int notify;
} bsg_pod_barrier_s;

bsg_pod_barrier_s pod_barrier = { {0},{0},0 };
int pod_barrier_sense = -1;

#define kPodBarrier_CenterX 8
#define kPodBarrier_CenterY 4

char *pod_barrier_parent = 0;
int  *pod_barrier_buddy = 0;

void bsg_pod_barrier_init()
{
  // send notification to my row
  char *p = (char *) bsg_remote_ptr(kPodBarrier_CenterX, bsg_y, &pod_barrier.row);
  pod_barrier_parent = &p[((bsg_x & 3)<<2) + ((bsg_x >> 2) & 3)];
  int buddy_x = bsg_x - 1;

  // set buddy to self if at the end of a group of 4
  if ((bsg_x & 3) == 0)
    buddy_x = bsg_x;

  pod_barrier_buddy = (char *) bsg_remote_ptr(buddy_x, bsg_y, &pod_barrier.notify);
}

void bsg_pod_barrier()
{
  int tmp_pod_barrier_sense = pod_barrier_sense;
  int tmp_bsg_x = bsg_x;
  *pod_barrier_parent = tmp_pod_barrier_sense;

  int *tmp_pod_barrier_buddy = pod_barrier_buddy;
  int *pod_barrier_notify_ptr = &pod_barrier.notify;
  int tmp_pod_barrier_sense_inv = ~tmp_pod_barrier_sense;
  int tmp_bsg_y = bsg_y;
  int inc4;

  tmp_bsg_x = bsg_mulu(tmp_bsg_x,1);
  tmp_bsg_x = bsg_mulu(tmp_bsg_x,1);
  //  bsg_print_int(0x00BA0000+__bsg_id);
  if (tmp_bsg_x == kPodBarrier_CenterX)
    {
      // bsg_print_int(0xBEEF);
      char *q = (char *) bsg_remote_ptr(kPodBarrier_CenterX,kPodBarrier_CenterY,&pod_barrier.col[0]);
      q = &q[tmp_bsg_y];

      bsg_remote_int_ptr foo = &pod_barrier.row;
      bsg_join4_relay(foo,tmp_pod_barrier_sense, q);

      if (tmp_bsg_y == kPodBarrier_CenterY)
	{
	  // shift by 2 is because it is an int pointer
	  int incY = bsg_li((1 << REMOTE_Y_CORD_SHIFT) >> 2);
	  int *r = (int *) bsg_remote_ptr(kPodBarrier_CenterX-1,0,pod_barrier_notify_ptr);
	  int *s = (int *) bsg_remote_ptr(kPodBarrier_CenterX,0,pod_barrier_notify_ptr);

	  bsg_remote_int_ptr addr = &pod_barrier.col;

	  bsg_join2(addr,tmp_pod_barrier_sense);
	  //	  while (addr[0] != tmp_pod_barrier_sense);
	  //      while (addr[1] != tmp_pod_barrier_sense);
	  
	  // barrier has completed!!
	  // wake up 16 tiles
	  *r = tmp_pod_barrier_sense; r += incY; // 0
	  *r = tmp_pod_barrier_sense; r += incY; // 1 
	  *r = tmp_pod_barrier_sense; r += incY; // 2
	  *r = tmp_pod_barrier_sense; r += incY; // 3 
	  *r = tmp_pod_barrier_sense; r += incY; // 4
	  *r = tmp_pod_barrier_sense; r += incY; // 5 
	  *r = tmp_pod_barrier_sense; r += incY; // 6
	  *r = tmp_pod_barrier_sense; r += incY; // 7 
	  *s = tmp_pod_barrier_sense; s += incY; // 0
	  *s = tmp_pod_barrier_sense; s += incY; // 1 
	  *s = tmp_pod_barrier_sense; s += incY; // 2
	  *s = tmp_pod_barrier_sense; s += incY; // 3 
	  *s = tmp_pod_barrier_sense; s += incY; // 4
	  *s = tmp_pod_barrier_sense; s += incY; // 5 
	  *s = tmp_pod_barrier_sense; s += incY; // 6
	  *s = tmp_pod_barrier_sense; s += incY; // 7 

	  goto done;
	}
    }
  else if (tmp_bsg_x == kPodBarrier_CenterX-1)
    {
      // shift by 2 is because it is an int pointer
      inc4 = bsg_li((1 << REMOTE_X_CORD_SHIFT) >> 2)*4;
      volatile int *s = (int *) bsg_remote_ptr(3,tmp_bsg_y,pod_barrier_notify_ptr); // 3
      volatile int *t = s + inc4+inc4; // 11
      volatile int *u = s + inc4*3;   // 15

      // wait for notification from the center tile, send out notification to other 3 quads
      bsg_wait_local_int_asm_blind(pod_barrier_notify_ptr,tmp_pod_barrier_sense);

      *s = tmp_pod_barrier_sense; 
      *t = tmp_pod_barrier_sense;
      *u = tmp_pod_barrier_sense;

      *tmp_pod_barrier_buddy = tmp_pod_barrier_sense;

      goto done;
    }

  // wait for broadcast to return!
  bsg_wait_local_int_asm_blind(pod_barrier_notify_ptr,tmp_pod_barrier_sense);
  //bsg_print_int(0xBEEB);

  *tmp_pod_barrier_buddy = tmp_pod_barrier_sense;
  // bsg_print_int(0x10BA0000+__bsg_id);
 done:
  // invert sense of pod barrier, ready to go for next barrier!
  pod_barrier_sense= tmp_pod_barrier_sense_inv;
}

INIT_TILE_GROUP_BARRIER(r_barrier, c_barrier, 0, bsg_tiles_X-1, 0, bsg_tiles_Y-1);

int main()
{
  int val;

  bsg_set_tile_x_y();
  bsg_pod_barrier_init();

  int id = __bsg_id;

  if (id == 0)
    {
      bsg_print_int(0xFACADE);
      bsg_pod_barrier();
      bsg_print_int(0xFACADE);
      bsg_pod_barrier();
      bsg_print_int(0xFACADE);
      bsg_pod_barrier();
      bsg_print_int(0xFACADE);
      bsg_pod_barrier();
      bsg_print_int(0xFACADE);
      bsg_pod_barrier();
      bsg_print_int(0xFACADE);
      bsg_pod_barrier();
      bsg_print_int(0xFACADE);
      bsg_finish();
    }
  else
    {
#define STALL 0
      bsg_pod_barrier();
      if (STALL) val += bsg_div(val,2);
      bsg_pod_barrier();
      if (STALL) val += bsg_div(val,2);
      bsg_pod_barrier();
      if (STALL) val += bsg_div(val,2);
      bsg_pod_barrier();
      if (STALL) val += bsg_div(val,2);
      bsg_pod_barrier();
      if (STALL) val += bsg_div(val,2);
      bsg_pod_barrier();
      if (STALL) val += bsg_div(val,2);
    }
  bsg_wait_while(1);
}

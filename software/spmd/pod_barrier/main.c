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
  int buddy_x = bsg_x + 1;

  // set buddy to self if at the end of a group of 4
  if ((buddy_x & 3) == 0)
    buddy_x = bsg_x;

  pod_barrier_buddy = (char *) bsg_remote_ptr(buddy_x, bsg_y, &pod_barrier.notify);
}

void bsg_pod_barrier()
{
  int tmp_pod_barrier_sense = pod_barrier_sense;
  *pod_barrier_parent = tmp_pod_barrier_sense;

  int *tmp_pod_barrier_buddy = pod_barrier_buddy;
  int *pod_barrier_notify_ptr = &pod_barrier.notify;
  int tmp_pod_barrier_sense_inv = ~tmp_pod_barrier_sense;
  int tmp_bsg_y = bsg_y, tmp_bsg_x = bsg_x;

  //  bsg_print_int(0x00BA0000+__bsg_id);
  if (tmp_bsg_x == kPodBarrier_CenterX)
    {
      // bsg_print_int(0xBEEF);
      char *q = (char *) bsg_remote_ptr(kPodBarrier_CenterX,kPodBarrier_CenterY,&pod_barrier.col[0]);
      q = &q[tmp_bsg_y];

      bsg_remote_int_ptr foo = &pod_barrier.row;
      if (tmp_pod_barrier_sense  < 0)
	{
	  int and_val;
	  do {
	    and_val = tmp_pod_barrier_sense;
	    and_val &= foo[0];
	    and_val &= foo[1];
	    and_val &= foo[2];
	  }  while (and_val != tmp_pod_barrier_sense);

	  do { } while (foo[3] != tmp_pod_barrier_sense);
	}
      else
	{
	  int or_val;
	  do {
	    or_val = tmp_pod_barrier_sense;
	    or_val |= foo[0];
	    or_val |= foo[1];
	    or_val |= foo[2];
	  } while (or_val != tmp_pod_barrier_sense);

	  do {} while (foo[3] != tmp_pod_barrier_sense);
	}
      
      //      for (int x = 0; x < 4; x++)
      //	bsg_wait_local_int(&pod_barrier.row[x],tmp_pod_barrier_sense);

      *q = tmp_pod_barrier_sense;

      // shift by 2 is because it is an int pointer
      int inc4 = bsg_li((1 << REMOTE_X_CORD_SHIFT) >> 2)*4;
      int *s = (int *) bsg_remote_ptr(0,tmp_bsg_y,pod_barrier_notify_ptr);

      if (tmp_bsg_y == kPodBarrier_CenterY)
	{
	  // shift by 2 is because it is an int pointer
	  int inc = bsg_li((1 << REMOTE_Y_CORD_SHIFT) >> 2);
	  int *r = (int *) bsg_remote_ptr(kPodBarrier_CenterX,0,pod_barrier_notify_ptr);

	  int *addr0 = &pod_barrier.col[0];
	  bsg_wait_local_int(addr0,tmp_pod_barrier_sense);
	  int *addr1 = &pod_barrier.col[1];
	  bsg_wait_local_int(addr1,tmp_pod_barrier_sense);
	  
	  // barrier has completed!!
	  //bsg_print_int(0xFACADE);

	  *r = tmp_pod_barrier_sense; r += inc; // 0
	  *r = tmp_pod_barrier_sense; r += inc; // 1 
	  *r = tmp_pod_barrier_sense; r += inc; // 2
	  *r = tmp_pod_barrier_sense; r += inc; // 3 
	  *r = tmp_pod_barrier_sense; r += inc; // 4
	  *r = tmp_pod_barrier_sense; r += inc; // 5 
	  *r = tmp_pod_barrier_sense; r += inc; // 6
	  *r = tmp_pod_barrier_sense; r += inc; // 7 
	}
      else
	bsg_wait_local_int(pod_barrier_notify_ptr,tmp_pod_barrier_sense);
      //      bsg_print_int(0xFEEB);

      *s = tmp_pod_barrier_sense; s += inc4; // 0
      *s = tmp_pod_barrier_sense; s += inc4; s+=inc4; // 4
      //      *s = tmp_pod_barrier_sense; s += inc; // 8
      *s = tmp_pod_barrier_sense; s += inc4; // 12
    }
  else
    {
      // wait for broadcast to return!
      bsg_wait_local_int(pod_barrier_notify_ptr,tmp_pod_barrier_sense);
    }
  *tmp_pod_barrier_buddy = tmp_pod_barrier_sense;
  // bsg_print_int(0x10BA0000+__bsg_id);

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
#define STALL 1
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

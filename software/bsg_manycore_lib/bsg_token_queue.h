
#ifndef _BSG_TOKEN_QUEUE_H
#define _BSG_TOKEN_QUEUE_H

// MBT 5/18/2016
//
// Remote store programming naturally supports producer-consumer communication via
// a restricted form of shared memory. This module provides a generalized form of fixed-sized circular queues,
// where each element of the queue corresponds to a unique set of addresses. When the producer
// "enques" to the queue, it is transfering ownership of that address range to the consumer.
// 
// When the consumer "confirms" a number N of elements on the queue, it is verifying that the N
// top elements of the queue have been assigned to it, and it can access all of those addresses freely.
// When the consumer "deques" a number N of elements from the queue, it returns those N address sets
// to the producer, and reassigns the "top element".
//
// Although this mechanism is general, in the case of remote store programming, senders have 
// exclusive write access to a range, and receivers have exclusive RW access to a range.
//
//

// supports a max of 65,536 items
typedef struct bsg_token_pair
{
  int send;
  int receive;
} bsg_token_pair_t;

#define bsg_declare_token_queue(x) bsg_token_pair_t x [bsg_tiles_X][bsg_tiles_Y] = {0,0}


// wait for at least depth address sets to be available to sender
inline int bsg_tq_sender_confirm(bsg_token_pair_t token_array[][bsg_tiles_Y], int x, int y, int max_els, int depth)
{
  int i = token_array[x][y].send;

  // wait while number of available elements
  bsg_wait_while((depth + i - bsg_volatile_access(token_array[x][y].receive)) > max_els);

  return i;
}

// actually do the transfer; assumes that you have confirmed first 
//

inline int bsg_tq_sender_xfer(bsg_token_pair_t token_array[][bsg_tiles_Y],int x, int y, int max_els, int depth)
{
  int   i = token_array[x][y].send + depth;

  bsg_commit_stores();
  
  // local version
  token_array[x][y].send = i;

  // remote version
  bsg_remote_store(x,y,&(token_array[bsg_x][bsg_y].send),i);
  
  return i;
}

// wait for at least depth address sets to be available to receiver
inline int bsg_tq_receiver_confirm(bsg_token_pair_t token_array[][bsg_tiles_Y], int x, int y, int depth)
{
  int i = token_array[x][y].receive;

  // wait until that number of elements is available
  bsg_wait_while((bsg_volatile_access(token_array[x][y].send)-i) < depth);

  return i;
}

// return the addresses; assumes you have confirmed first

inline void bsg_tq_receiver_release(bsg_token_pair_t token_array[][bsg_tiles_Y], int x, int y, int depth)
{
  int i = token_array[x][y].receive+depth;

  // since the receiver has the memory ranges local, we know that any stores to that range of
  // been committed, so bsg_commit_stores() should not be necessary.

  // local version
  token_array[x][y].receive = i;

  // remote version
  bsg_remote_store(x,y,&(token_array[bsg_x][bsg_y].receive),i);
}

#endif

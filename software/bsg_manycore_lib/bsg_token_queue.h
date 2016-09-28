
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

typedef struct bsg_token_pair
{
  int send;
  int receive;
} bsg_token_pair_t;

typedef struct bsg_token_connection
{
  bsg_token_pair_t *local_ptr;
  volatile int *remote_ptr;
} bsg_token_connection_t;

#define bsg_declare_token_queue(x) bsg_token_pair_t x [bsg_tiles_X][bsg_tiles_Y] = {0,0}

  inline bsg_token_connection_t bsg_tq_send_connection (bsg_token_pair_t token_array[][bsg_tiles_Y], int x, int y)
  {
    bsg_token_connection_t conn;
    
    conn.local_ptr  = &token_array[x][y];
    conn.remote_ptr = bsg_remote_ptr(x,y,&(token_array[bsg_x][bsg_y].send)); 

    return conn;
  }

inline bsg_token_connection_t bsg_tq_receive_connection (bsg_token_pair_t token_array[][bsg_tiles_Y], int x, int y)
{
  bsg_token_connection_t conn;
  
  conn.local_ptr  = &token_array[x][y];
  conn.remote_ptr = bsg_remote_ptr(x,y,&(token_array[bsg_x][bsg_y].receive));

  return conn;
}

// wait for at least depth address sets to be available to sender
inline int bsg_tq_sender_confirm(bsg_token_connection_t conn, int max_els, int depth)
{
  int i = (conn.local_ptr)->send;
  int tmp =  - max_els + depth + i;

  // wait until having the addition sent elements would not overflow the buffer
  //  bsg_wait_while((depth + i - bsg_volatile_access((conn.local_ptr)->receive)) > max_els);

  // these lines incorrect on wrap around because of modulo arithmetic
  // bsg_wait_while((bsg_lr(&((conn.local_ptr)->receive)) < tmp) && (bsg_lr_aq(&((conn.local_ptr)->receive)) < tmp));

  bsg_wait_while((tmp - bsg_lr(&((conn.local_ptr)->receive)) > 0) && (tmp - bsg_lr_aq(&((conn.local_ptr)->receive)) > 0));

  return i;
}

// actually do the transfer; assumes that you have confirmed first
//

inline int bsg_tq_sender_xfer(bsg_token_connection_t conn, int max_els, int depth)
{
  int   i = (conn.local_ptr)->send + depth;

// MBT 9/18/16 fixme performance:  I believe in a sequentially consistent memory system
// a fence should not be necessary if the data and the token queue are between
// the same pair. but this requires more followup

  bsg_commit_stores();

  // local version
  (conn.local_ptr)->send = i;

  // remote version

  *(conn.remote_ptr) = i;

  return i;
}

// wait for at least depth address sets to be available to receiver
inline int bsg_tq_receiver_confirm(bsg_token_connection_t conn, int depth)
{
  int i = (conn.local_ptr)->receive;

  // wait until that number of elements is available
  //bsg_wait_while((bsg_volatile_access((conn.local_ptr)->send)-i) < depth);
  int tmp = depth+i;

  // this line is incorrect on wrap around; standard alegbra does not work in
  // modulo arithmetic.

  //bsg_wait_while((bsg_lr(&((conn.local_ptr)->send)) < tmp) && (bsg_lr_aq(&((conn.local_ptr)->send)) < tmp));

  bsg_wait_while((bsg_lr(&((conn.local_ptr)->send))-tmp < 0) && (bsg_lr_aq(&((conn.local_ptr)->send))-tmp < 0));

  return i;
}

// return the addresses; assumes you have confirmed first
inline void bsg_tq_receiver_release(bsg_token_connection_t conn, int depth)
{
  int i = (conn.local_ptr)->receive+depth;

  // since the receiver has the memory ranges local, we know that any stores to that range of
  // been committed, so bsg_commit_stores() should not be necessary.

  // local version
  (conn.local_ptr)->receive=i;

  // remote version
  *(conn.remote_ptr) = i;
}

#endif

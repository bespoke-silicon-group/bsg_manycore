// C++ Replacement of bsg_mutex.h
// Incomplete
//
#ifndef _BSG_MUTEX_HPP_
#define _BSG_MUTEX_HPP_


/* 
 * Wait until the desired integer value is written into destination
 * This function is deliberately not templatized because
 * bsg_lr and bsg_lr_aq only work on int and unsigned int
 * The two int / unsigned int versions are specifically implemented 
 * param[in]  dst    pointer to the destication  
 * param[in]  val    desired value to be wrriten into dst
 * @return    val
 */ 
static int inline bsg_wait_local(int *dst, int val) {
    while(true) {
        int tmp = bsg_lr(dst);          // Perform a load reserved
        if (tmp == val) 
            return val;                 // val is already loaded 
        else {
            tmp = bsg_lr_aq(dst);       // stall until a tile clears the reservation
            if (tmp == val)
                return val;             //return if data is expected, otherwise retry
        }
    }
}



/* 
 * Wait until the desired unsigned integer value
 * is written into destination
 * This function is deliberately not templatized because
 * bsg_lr and bsg_lr_aq only work on int and unsigned int
 * The two int / unsigned int versions are specifically implemented 
 * param[in]  dst    pointer to the destication  
 * param[in]  val    desired value to be wrriten into dst
 * @return    val
 */ 
static int inline bsg_wait_local(unsigned int *dst, unsigned int val) {
    int *dst_int = reinterpret_cast<int *> (dst);
    int val_int = static_cast<int> (val);
    return bsg_wait_local(dst_int, val_int);
}



/*
 * Iterate over a given array until all values are non-zero
 * @param[in]  list    Pointer to arrayy of values to check
 * @param[in]  range   Number of elements to check
 * @return     Returns only when all values are non-zero
 */ 
template <typename T>
inline void poll_range(T *list, int range){
    int i;
    do {
        for(i = 0; i < range; i++) {
            if (!list[ i ])
                break;
        }
    } while (i < range);
}


#endif  // _BSG_MUTEX_HPP_

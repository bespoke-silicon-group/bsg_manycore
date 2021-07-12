//====================================================================
// An assert that works on both cosim and emul
// 03/16/2020 Lin Cheng (lc873@cornell.edu)
//====================================================================
#ifndef _HB_ASSERT_HPP
#define _HB_ASSERT_HPP

#define hb_assert(cond) if (!(cond)) {                            \
    if (bsg_id == 0)                                              \
      bsg_printf("assert failed at %s:%d\n", __FILE__, __LINE__); \
    return -1;}

#define hb_assert_msg(cond, fmt, ...) if (!(cond)) {              \
    if (bsg_id == 0){                                             \
      bsg_printf("assert failed at %s:%d\n", __FILE__, __LINE__); \
      bsg_printf(fmt,##__VA_ARGS__);}                             \
    return -1;}

#endif

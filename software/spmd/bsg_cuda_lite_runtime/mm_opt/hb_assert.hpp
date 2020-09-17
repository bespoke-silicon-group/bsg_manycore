//====================================================================
// An assert that works on both cosim and emul
// 03/16/2020 Lin Cheng (lc873@cornell.edu)
//====================================================================
#ifndef _HB_ASSERT_HPP
#define _HB_ASSERT_HPP

#define hb_assert(cond) if (!(cond)) {                       \
    bsg_printf("assert failed at %s:%d", __FILE__, __LINE__); \
    bsg_fail();}

#define hb_assert_msg(cond, fmt, ...) if (!(cond)) {          \
    bsg_printf("assert failed at %s:%d ", __FILE__, __LINE__); \
    bsg_printf(fmt,##__VA_ARGS__);                             \
    bsg_fail();}

#endif

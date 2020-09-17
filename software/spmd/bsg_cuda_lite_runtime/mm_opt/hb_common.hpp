#ifndef _HB_COMMON_HPP
#define _HB_COMMON_HPP

// Print from specific tile id
#define hb_tile_print(tile_id, fmt, ...) \
  if(__bsg_id == tile_id) { \
    bsg_printf(fmt, ##__VA_ARGS__); \
  }

// =============================================================
// Workarounds for HB HW Issues
//
// This implementes a set of workarounds for HW
// issues that might be discovered on ASIC. The plan is to
// reproduce the bug in cosimulation and use verilog asserts
// to root cause the line of kernel code triggering the bug.
// After figuring out the line of kernel code triggering the
// bug, the verilog error message can used to find the right
// software fix in this header, and use fix that to patch the
// kernel code.
//
// For example, if a bug is triggered by a WAW violation between:
//
//   sizes = (uint32_t*) ((intptr_t) t->sizes);
//     204: 00c52f03            lw  x30,12(x10)
//   .
//   .
// (and)
//   .
//   .
//   strides[1] = (input.get_strides())[0];
//     3ac: 00092f03            lw  x30,0(x18)
// 
// The error message by verilog assertion would start with:
// [ERROR][VCORE] STALL_FORCE_WB WAW HAZARD
//
// A possible workaround is to use the macro HB_FIX_WAW_HAZARD
// on `sizes`:
//
//   sizes = (uint32_t*) ((intptr_t) t->sizes);
//   HB_FIX_WAW_HAZARD(sizes);
//   .
//   .
//   strides[1] = (input.get_strides())[0];
// =============================================================
#ifndef HB_EMUL
// Fixes WAW violations in HW
//
// WAW violations are seen in cosimulation as errors starting with:
// [ERROR][VCORE] STALL_FORCE_WB WAW HAZARD
#define HB_FIX_WAW_HAZARD(var) \
  do {                         \
    asm volatile (             \
        "mv %0, %1;"           \
        : "=r" ((var))         \
        : "r" ((var))          \
        );                     \
  } while(0)
#else
#define HB_FIX_WAW_HAZARD(var)
#endif // ifndef HB_EMUL

#endif // _HB_COMMON_HPP
